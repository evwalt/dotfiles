// Sidecar: a group of tmux panes (tagged @sidecar) that follows you between windows.
//
// Build:  rustc -O -o ~/scripts/sidecar ~/scripts/sidecar.rs
//
// Usage:  sidecar [WINDOW_ID]        follow: bring the group to that window
//         sidecar full [WINDOW_ID]   toggle: maximize whichever side has focus (the group,
//                                    or the regular panes with the group hidden) / restore
//         sidecar pzoom [WINDOW_ID]  toggle: expand the focused pane to fill its own side
//                                    (the group's area, or the regular area) / restore
//         sidecar reap               after a pane closes: undo an expand whose pane is gone
//         sidecar fit [WINDOW_ID]    after a window resize: rescale its splits to the ratios
//                                    last arranged (window option @sidecar_lay)
//
// Called from tmux hooks (see tmux.conf) with the window that just became
// current. Before moving the group out of the window it was last in, it
// records the group's geometry: which edge it hugs, its size and its internal
// split tree. It then rebuilds that arrangement in the new window.
//
// State lives in tmux itself:
//   pane option   @sidecar        "1" on every pane in the group
//   global option @sidecar_snap   last arrangement (see Snapshot::ser)
//   global option @sidecar_built  what we built last time (to spot user changes)
//   global option @sidecar_win    window holding the group (hook fast-path guard)
//   window option @sidecar_zoom   group pane that was zoomed when you left it
//   window option @sidecar_layout exact window layout when the group last left
//   window option @sidecar_nzoom  regular pane that was zoomed when the group left
//                                 (tmux drops zoom on a lone pane, so we reapply it)
//   window option @sidecar_active group pane that had focus when the group left
//   window option @sidecar_full   "1" while the group is maximized in this window: the
//                                 regular panes are stashed in a hidden session, and
//                                 @sidecar_full_{panes,layout,zoom} remember them
//   window option @sidecar_fresume "1" if the window was maximized when the group left
//   window option @sidecar_hide   like @sidecar_full, but the group is the part parked in
//                                 the stash, and @sidecar_hide_{panes,layout,zoom} apply
//   window option @sidecar_hresume "1" if the group was hidden when it left
//   window option @sidecar_pzoom  pane expanded to fill its side; the other panes on that
//                                 side wait in a second hidden session, and
//                                 @sidecar_pzoom_{panes,layout} remember them. Only lives
//                                 in the window holding the group: undone when it leaves,
//                                 with @sidecar_presume set to redo it when it returns

use std::collections::HashMap;
use std::process::Command;
use std::time::{Duration, SystemTime};
use std::{env, fs, thread};

const DEFAULT_SIZE: f64 = 0.30;
const FMT: &str = "#{pane_id}\t#{window_id}\t#{@sidecar}\t#{pane_left}\t#{pane_top}\t\
#{pane_width}\t#{pane_height}\t#{window_width}\t#{window_height}\t#{window_zoomed_flag}\t\
#{pane_active}\t#{@sidecar_zoom}\t#{window_active}\t#{window_layout}\t#{@sidecar_layout}\t#{@sidecar_nzoom}\t#{@sidecar_active}\t#{@sidecar_full}\t#{session_name}\t#{@sidecar_fresume}\t#{@sidecar_hide}\t#{@sidecar_hresume}\t#{@sidecar_pzoom}";
const STASH: &str = "_sidecar_stash";
const PSTASH: &str = "_sidecar_pstash";
const SEP: &str = "@@sep@@";

type Res<T> = Result<T, String>;

fn tmux(args: &[&str]) -> Res<String> {
    let mut cmd = Command::new("tmux");
    // SIDECAR_SOCK names a separate tmux server (-L), for testing without touching the real one.
    if let Some(sock) = env::var("SIDECAR_SOCK").ok().filter(|s| !s.is_empty()) {
        cmd.args(["-L", &sock]);
    }
    let out = cmd
        .args(args)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(format!(
            "tmux {}: {}",
            args.join(" "),
            String::from_utf8_lossy(&out.stderr).trim()
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).trim_end_matches('\n').to_string())
}

fn tmux_v(args: &[String]) -> Res<String> {
    let a: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    tmux(&a)
}

// --- panes ------------------------------------------------------------------

#[derive(Clone, Debug)]
struct Pane {
    id: String,
    win: String,
    tag: bool,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    ww: i32,
    wh: i32,
    zoomed: bool,
    active: bool,
    szoom: String,
    wactive: bool,
    layout: String,
    slayout: String,
    nzoom: String,
    sactive: String,
    sfull: bool,
    sess: String,
    fresume: bool,
    shide: bool,
    hresume: bool,
    spz: String,
}

fn parse_panes(s: &str) -> Vec<Pane> {
    let n = |v: &str| v.parse::<i32>().unwrap_or(0);
    s.lines()
        .filter_map(|l| {
            let f: Vec<&str> = l.split('\t').collect();
            if f.len() < 23 {
                return None;
            }
            Some(Pane {
                id: f[0].into(),
                win: f[1].into(),
                tag: f[2] == "1",
                x: n(f[3]),
                y: n(f[4]),
                w: n(f[5]),
                h: n(f[6]),
                ww: n(f[7]),
                wh: n(f[8]),
                zoomed: f[9] == "1",
                active: f[10] == "1",
                szoom: f[11].into(),
                wactive: f[12] == "1",
                layout: f[13].into(),
                slayout: f[14].into(),
                nzoom: f[15].into(),
                sactive: f[16].into(),
                sfull: f[17] == "1",
                sess: f[18].into(),
                fresume: f[19] == "1",
                shide: f[20] == "1",
                hresume: f[21] == "1",
                spz: f[22].into(),
            })
        })
        .collect()
}

struct State {
    panes: Vec<Pane>,
    snap: String,
    built: String,
}

// One tmux spawn for everything we need to decide.
fn read_state() -> Res<State> {
    let out = tmux(&[
        "list-panes", "-a", "-F", FMT, ";",
        "display-message", "-p", SEP, ";",
        "show-options", "-gqv", "@sidecar_snap", ";",
        "display-message", "-p", SEP, ";",
        "show-options", "-gqv", "@sidecar_built",
    ])?;
    let parts: Vec<&str> = out.split(SEP).collect();
    if parts.len() != 3 {
        return Err("unexpected tmux output".into());
    }
    Ok(State {
        panes: parse_panes(parts[0]),
        snap: parts[1].trim().into(),
        built: parts[2].trim().into(),
    })
}

fn list_window(win: &str) -> Res<Vec<Pane>> {
    Ok(parse_panes(&tmux(&["list-panes", "-t", win, "-F", FMT])?))
}

// --- split tree -------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
enum Node {
    Leaf { id: String, w: i32, h: i32 },
    Split { d: char, w: i32, h: i32, a: Box<Node>, b: Box<Node> },
}

impl Node {
    fn w(&self) -> i32 {
        match self { Node::Leaf { w, .. } | Node::Split { w, .. } => *w }
    }
    fn h(&self) -> i32 {
        match self { Node::Leaf { h, .. } | Node::Split { h, .. } => *h }
    }
    fn leaves(&self, out: &mut Vec<String>) {
        match self {
            Node::Leaf { id, .. } => out.push(id.clone()),
            Node::Split { a, b, .. } => {
                a.leaves(out);
                b.leaves(out);
            }
        }
    }
    fn leaf_ids(&self) -> Vec<String> {
        let mut v = Vec::new();
        self.leaves(&mut v);
        v
    }
    fn ser(&self, out: &mut String) {
        match self {
            Node::Leaf { id, w, h } => out.push_str(&format!("{},{},{}", id, w, h)),
            Node::Split { d, w, h, a, b } => {
                out.push_str(&format!("{},{},{}(", d, w, h));
                a.ser(out);
                out.push_str(")(");
                b.ser(out);
                out.push(')');
            }
        }
    }
}

fn parse_node(s: &[u8], i: &mut usize) -> Option<Node> {
    let start = *i;
    while *i < s.len() && s[*i] != b'(' && s[*i] != b')' {
        *i += 1;
    }
    let tok = std::str::from_utf8(&s[start..*i]).ok()?;
    let f: Vec<&str> = tok.split(',').collect();
    if f.len() != 3 {
        return None;
    }
    let (w, h) = (f[1].parse().ok()?, f[2].parse().ok()?);
    if f[0].starts_with('%') {
        return Some(Node::Leaf { id: f[0].into(), w, h });
    }
    let d = f[0].chars().next().filter(|c| *c == 'h' || *c == 'v')?;
    let sub = |i: &mut usize| -> Option<Node> {
        if s.get(*i) != Some(&b'(') {
            return None;
        }
        *i += 1;
        let n = parse_node(s, i)?;
        if s.get(*i) != Some(&b')') {
            return None;
        }
        *i += 1;
        Some(n)
    };
    let a = sub(i)?;
    let b = sub(i)?;
    Some(Node::Split { d, w, h, a: Box::new(a), b: Box::new(b) })
}

struct Rect {
    id: String,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
}

fn bbox<'a, I: Iterator<Item = (i32, i32, i32, i32)>>(it: I) -> (i32, i32, i32, i32) {
    it.fold((i32::MAX, i32::MAX, i32::MIN, i32::MIN), |a, (x, y, w, h)| {
        (a.0.min(x), a.1.min(y), a.2.max(x + w), a.3.max(y + h))
    })
}

// Guillotine tree from pane rectangles (tmux layouts always are one).
fn build_tree(r: &[Rect]) -> Option<Node> {
    if r.len() == 1 {
        return Some(Node::Leaf { id: r[0].id.clone(), w: r[0].w, h: r[0].h });
    }
    let (x0, y0, x1, y1) = bbox(r.iter().map(|p| (p.x, p.y, p.w, p.h)));
    for d in ['h', 'v'] {
        let (lo, size): (fn(&Rect) -> i32, fn(&Rect) -> i32) =
            if d == 'h' { (|p| p.x, |p| p.w) } else { (|p| p.y, |p| p.h) };
        let mut cuts: Vec<i32> = r.iter().map(|p| lo(p) + size(p)).collect();
        cuts.sort();
        cuts.dedup();
        for cut in cuts {
            let a: Vec<&Rect> = r.iter().filter(|p| lo(p) + size(p) <= cut).collect();
            let b: Vec<&Rect> = r.iter().filter(|p| lo(p) >= cut + 1).collect();
            if a.is_empty() || b.is_empty() || a.len() + b.len() != r.len() {
                continue;
            }
            let amax = a.iter().map(|p| lo(p) + size(p)).max()?;
            let bmin = b.iter().map(|p| lo(p)).min()?;
            if amax != cut || bmin != cut + 1 {
                continue;
            }
            let ar: Vec<Rect> = a.iter().map(|p| Rect { id: p.id.clone(), x: p.x, y: p.y, w: p.w, h: p.h }).collect();
            let br: Vec<Rect> = b.iter().map(|p| Rect { id: p.id.clone(), x: p.x, y: p.y, w: p.w, h: p.h }).collect();
            return Some(Node::Split {
                d,
                w: x1 - x0,
                h: y1 - y0,
                a: Box::new(build_tree(&ar)?),
                b: Box::new(build_tree(&br)?),
            });
        }
    }
    None
}

fn prune(n: &Node, alive: &[String]) -> Option<Node> {
    match n {
        Node::Leaf { id, .. } => alive.contains(id).then(|| n.clone()),
        Node::Split { d, w, h, a, b } => match (prune(a, alive), prune(b, alive)) {
            (Some(a), Some(b)) => Some(Node::Split { d: *d, w: *w, h: *h, a: Box::new(a), b: Box::new(b) }),
            (a, b) => a.or(b),
        },
    }
}

// Equal-weight chain of splits for panes with no recorded arrangement.
fn stack(ids: &[String], d: char) -> Node {
    let mut node = Node::Leaf { id: ids[ids.len() - 1].clone(), w: 1, h: 1 };
    for id in ids[..ids.len() - 1].iter().rev() {
        let n = node.leaf_ids().len() as i32 + 1;
        node = Node::Split {
            d,
            w: n,
            h: n,
            a: Box::new(Node::Leaf { id: id.clone(), w: 1, h: 1 }),
            b: Box::new(node),
        };
    }
    node
}

// --- snapshot ---------------------------------------------------------------

#[derive(Clone, Debug)]
struct Snapshot {
    edge: String,
    size: i32,
    dim: i32,
    tree: Node,
}

impl Snapshot {
    fn ser(&self) -> String {
        let mut t = String::new();
        self.tree.ser(&mut t);
        format!("{};{};{};{}", self.edge, self.size, self.dim, t)
    }
    fn parse(s: &str) -> Option<Snapshot> {
        let mut it = s.splitn(4, ';');
        let edge = it.next()?.to_string();
        let size = it.next()?.parse().ok()?;
        let dim = it.next()?.parse().ok()?;
        let t = it.next()?;
        let mut i = 0;
        let tree = parse_node(t.as_bytes(), &mut i)?;
        if !["left", "right", "top", "bottom"].contains(&edge.as_str()) {
            return None;
        }
        Some(Snapshot { edge, size, dim, tree })
    }
}

// Record how the group sits in a window (which must be unzoomed).
fn take_snapshot(win_panes: &[Pane], group: &[String]) -> Option<Snapshot> {
    let g: Vec<&Pane> = win_panes.iter().filter(|p| group.contains(&p.id)).collect();
    if g.is_empty() || g.len() == win_panes.len() {
        return None; // sidecar alone in its window: nothing to learn
    }
    let (ax0, ay0, ax1, ay1) = bbox(win_panes.iter().map(|p| (p.x, p.y, p.w, p.h)));
    let (gx0, gy0, gx1, gy1) = bbox(g.iter().map(|p| (p.x, p.y, p.w, p.h)));
    let (left, right, top, bottom) = (gx0 == ax0, gx1 == ax1, gy0 == ay0, gy1 == ay1);
    let edge = if left && right && !(top && bottom) {
        if bottom { "bottom" } else { "top" }
    } else if top && bottom && !(left && right) {
        if right { "right" } else { "left" }
    } else if right && !left {
        "right"
    } else if left && !right {
        "left"
    } else if bottom && !top {
        "bottom"
    } else if top && !bottom {
        "top"
    } else {
        return None;
    };
    let rects: Vec<Rect> = g
        .iter()
        .map(|p| Rect { id: p.id.clone(), x: p.x, y: p.y, w: p.w, h: p.h })
        .collect();
    let tree = build_tree(&rects)?;
    let horiz = edge == "left" || edge == "right";
    Some(Snapshot {
        edge: edge.into(),
        size: if horiz { gx1 - gx0 } else { gy1 - gy0 },
        dim: if horiz { g[0].ww } else { g[0].wh },
        tree,
    })
}

// --- rebuild ----------------------------------------------------------------

fn dims(out: &str) -> (i32, i32) {
    let l = out.lines().last().unwrap_or("");
    let mut it = l.split_whitespace().map(|v| v.parse::<i32>().unwrap_or(0));
    (it.next().unwrap_or(0), it.next().unwrap_or(0))
}

// Split the region `anchor` currently fills (w x h) into the node's arrangement.
fn place(node: &Node, anchor: &str, w: i32, h: i32) -> Res<()> {
    let (d, a, b) = match node {
        Node::Leaf { .. } => return Ok(()),
        Node::Split { d, a, b, .. } => (*d, a, b),
    };
    let first_b = b.leaf_ids()[0].clone();
    let (total, ra, rb, flag) = if d == 'h' { (w, a.w(), b.w(), "-h") } else { (h, a.h(), b.h(), "-v") };
    if total < 3 {
        return Err("region too small".into());
    }
    let size = (((rb as f64) * (total - 1) as f64 / ((ra + rb).max(1) as f64)).round() as i32)
        .max(1)
        .min(total - 2);
    let sz = size.to_string();
    let out = tmux(&[
        "join-pane", "-d", flag, "-l", &sz, "-s", &first_b, "-t", anchor, ";",
        "display-message", "-p", "-t", &first_b, "#{pane_width} #{pane_height}",
    ])?;
    let (nw, nh) = dims(&out);
    let have = if d == 'h' { nw } else { nh };
    if have != size {
        // A border-status row at the window edge is taken out of the pane itself.
        let _ = tmux(&["resize-pane", "-t", &first_b, if d == 'h' { "-x" } else { "-y" }, &sz]);
    }
    let rest = total - 1 - size;
    if d == 'h' {
        place(a, anchor, rest, h)?;
        place(b, &first_b, size, h)
    } else {
        place(a, anchor, w, rest)?;
        place(b, &first_b, w, size)
    }
}

// Move `ids` into `win`. `pre` are tmux commands (already ';'-joined) to run
// first in the same spawn.
fn restore(win: &str, wdims: (i32, i32), ids: &[String], snap: Option<&Snapshot>, pre: Vec<String>) -> Res<()> {
    let edge = snap.map(|s| s.edge.as_str()).unwrap_or("right");
    let horiz = edge == "left" || edge == "right";
    let sd = if horiz { 'v' } else { 'h' };
    let mut tree = snap.and_then(|s| prune(&s.tree, ids));
    if let Some(t) = &tree {
        let have = t.leaf_ids();
        let missing: Vec<String> = ids.iter().filter(|i| !have.contains(i)).cloned().collect();
        if !missing.is_empty() {
            let n = (have.len() + missing.len()) as i32;
            tree = Some(Node::Split {
                d: sd,
                w: n,
                h: n,
                a: Box::new(t.clone()),
                b: Box::new(stack(&missing, sd)),
            });
        }
    }
    let tree = tree.unwrap_or_else(|| stack(ids, sd));
    let wdim = if horiz { wdims.0 } else { wdims.1 };
    let mut size = match snap {
        Some(s) if s.size > 0 => ((s.size as f64) * (wdim as f64) / (s.dim.max(1) as f64)).round() as i32,
        _ => ((wdim as f64) * DEFAULT_SIZE).round() as i32,
    };
    size = size.max(1).min((wdim - 3).max(1));
    let flags: &[&str] = match edge {
        "left" => &["-h", "-b"],
        "top" => &["-v", "-b"],
        "bottom" => &["-v"],
        _ => &["-h"],
    };
    let root = tree.leaf_ids()[0].clone();
    let sz = size.to_string();
    let mut args: Vec<String> = pre;
    if !args.is_empty() {
        args.push(";".into());
    }
    args.extend(["join-pane", "-d", "-f"].map(String::from));
    args.extend(flags.iter().map(|s| s.to_string()));
    args.extend(["-l", &sz, "-s", &root, "-t", win, ";", "display-message", "-p", "-t", &root,
                 "#{pane_width} #{pane_height}"].map(String::from));
    let (rw, rh) = dims(&tmux_v(&args)?);
    let have = if horiz { rw } else { rh };
    if have != size {
        let _ = tmux(&["resize-pane", "-t", &root, if horiz { "-x" } else { "-y" }, &sz]);
    }
    let (w, h) = if horiz { (size, rh) } else { (rw, size) };
    place(&tree, &root, w, h)
}

// Last resort: every pane into one stack at the default spot.
fn fallback(win: &str, ids: &[String]) {
    let mut here: Vec<String> = Vec::new();
    for id in ids {
        let cur = tmux(&["display-message", "-p", "-t", id, "#{window_id}"]).unwrap_or_default();
        if cur == win {
            here.push(id.clone());
            continue;
        }
        if here.is_empty() {
            let _ = tmux(&["join-pane", "-d", "-f", "-h", "-l", "30%", "-s", id, "-t", win]);
            here.push(id.clone());
        } else {
            let _ = tmux(&["join-pane", "-d", "-v", "-s", id, "-t", &here[0]]);
        }
    }
}

// --- window layouts ---------------------------------------------------------

// Pane ids (as "%N") in a tmux layout string such as
// "ab12,200x50,0,0{100x50,0,0,0,99x50,101,0,1}".
fn layout_ids(s: &str) -> Option<Vec<String>> {
    fn num(b: &[u8], i: &mut usize) -> Option<()> {
        let st = *i;
        while *i < b.len() && b[*i].is_ascii_digit() {
            *i += 1;
        }
        (*i > st).then_some(())
    }
    fn cell(b: &[u8], i: &mut usize, out: &mut Vec<String>) -> Option<()> {
        num(b, i)?;
        if b.get(*i)? != &b'x' {
            return None;
        }
        *i += 1;
        num(b, i)?;
        for _ in 0..2 {
            if b.get(*i)? != &b',' {
                return None;
            }
            *i += 1;
            num(b, i)?;
        }
        match b.get(*i) {
            Some(b',') => {
                *i += 1;
                let st = *i;
                num(b, i)?;
                out.push(format!("%{}", std::str::from_utf8(&b[st..*i]).ok()?));
                Some(())
            }
            Some(&o) if o == b'{' || o == b'[' => {
                let close = if o == b'{' { b'}' } else { b']' };
                *i += 1;
                loop {
                    cell(b, i, out)?;
                    match *b.get(*i)? {
                        b',' => *i += 1,
                        c if c == close => {
                            *i += 1;
                            return Some(());
                        }
                        _ => return None,
                    }
                }
            }
            _ => None,
        }
    }
    let b = s.as_bytes();
    let mut i = s.find(',')? + 1;
    let mut out = Vec::new();
    cell(b, &mut i, &mut out)?;
    (i == b.len()).then_some(out)
}

fn same_set(a: &[String], b: &[String]) -> bool {
    let mut x = a.to_vec();
    let mut y = b.to_vec();
    x.sort();
    y.sort();
    x == y
}

// Resize the live group (cur) towards the target arrangement, top-down.
fn reshape(tgt: &Node, cur: &Node) {
    if let (Node::Split { d: d1, a: ta, b: tb, .. }, Node::Split { d: d2, a: ca, b: cb, .. }) = (tgt, cur) {
        if d1 != d2 || ta.leaf_ids() != ca.leaf_ids() || tb.leaf_ids() != cb.leaf_ids() {
            return;
        }
        let (t, c, flag) = if *d1 == 'h' { (tb.w(), cb.w(), "-x") } else { (tb.h(), cb.h(), "-y") };
        if t != c {
            let first = cb.leaf_ids()[0].clone();
            let _ = tmux(&["resize-pane", "-t", &first, flag, &t.to_string()]);
        }
        reshape(ta, ca);
        reshape(tb, cb);
    }
}

fn scale(n: &Node, sx: f64, sy: f64) -> Node {
    let f = |v: i32, k: f64| ((v as f64) * k).round() as i32;
    match n {
        Node::Leaf { id, w, h } => Node::Leaf { id: id.clone(), w: f(*w, sx), h: f(*h, sy) },
        Node::Split { d, w, h, a, b } => Node::Split {
            d: *d,
            w: f(*w, sx),
            h: f(*h, sy),
            a: Box::new(scale(a, sx, sy)),
            b: Box::new(scale(b, sx, sy)),
        },
    }
}

// After the group left, tmux gives its space to one neighbor. Spread it over
// the regular panes in proportion to how they were laid out before.
fn spread(win: &str, before: &[Pane], regular: &[String]) {
    let rects = |ps: &[Pane]| -> Vec<Rect> {
        ps.iter()
            .filter(|p| regular.contains(&p.id))
            .map(|p| Rect { id: p.id.clone(), x: p.x, y: p.y, w: p.w, h: p.h })
            .collect()
    };
    let (Some(t0), Ok(now)) = (build_tree(&rects(before)), list_window(win)) else { return };
    let Some(t1) = build_tree(&rects(&now)) else { return };
    let tgt = scale(&t0, t1.w() as f64 / t0.w().max(1) as f64, t1.h() as f64 / t0.h().max(1) as f64);
    reshape(&tgt, &t1);
}

// --- main -------------------------------------------------------------------

fn create(win: &str) -> Res<()> {
    let st = list_window(win)?;
    let tz = st.iter().find(|p| p.zoomed && p.active).map(|p| p.id.clone());
    if let Some(z) = &tz {
        tmux(&["resize-pane", "-Z", "-t", z])?;
    }
    let pid = tmux(&["split-window", "-d", "-f", "-h", "-l", "30%", "-t", win, "-P", "-F", "#{pane_id}"])?;
    tmux(&["set-option", "-p", "-t", &pid, "@sidecar", "1", ";",
           "set-option", "-g", "@sidecar_win", win])?;
    if let Some(z) = tz {
        let _ = tmux(&["resize-pane", "-Z", "-t", &z]);
    }
    Ok(())
}

fn sync(win: &str) -> Res<()> {
    sync_d(win, 0)
}

fn sync_d(win: &str, depth: u8) -> Res<()> {
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    if !in_win.first().map(|p| p.wactive).unwrap_or(false) {
        return Ok(()); // a later switch superseded this one
    }
    if in_win.iter().any(|p| p.shide) {
        return Ok(()); // the group is hidden here on purpose
    }
    // Panes parked by an expand whose window no longer exists: rescue.
    let pstashed: Vec<String> = st.panes.iter().filter(|p| p.sess == PSTASH).map(|p| p.id.clone()).collect();
    if depth == 0 && !pstashed.is_empty() && !st.panes.iter().any(|p| !p.spz.is_empty()) {
        rescue(win, &pstashed);
        return sync_d(win, 1);
    }
    if in_win.iter().any(|p| !p.spz.is_empty()) {
        return Ok(()); // a pane is expanded here (its parked siblings would look "outside")
    }
    // The group is leaving a window with an expanded pane: collapse it first, and
    // remember the pane so it is expanded again when the group comes back.
    if let Some((w, z)) = st.panes.iter().find(|p| !p.spz.is_empty()).map(|p| (p.win.clone(), p.spz.clone())) {
        exit_pz(&w)?;
        let _ = tmux(&["set-option", "-w", "-t", &w, "@sidecar_presume", &z]);
        return sync_d(win, depth);
    }
    // Stashed panes whose window no longer exists (e.g. its group was killed): rescue.
    let stashed: Vec<String> = st.panes.iter().filter(|p| p.sess == STASH).map(|p| p.id.clone()).collect();
    if depth == 0 && !stashed.is_empty() && !st.panes.iter().any(|p| (p.sfull || p.shide) && p.sess != STASH) {
        rescue(win, &stashed);
        return sync_d(win, 1);
    }
    let group: Vec<&Pane> = st.panes.iter().filter(|p| p.tag).collect();
    if group.is_empty() {
        return create(win);
    }
    let outside: Vec<String> = group.iter().filter(|p| p.win != win).map(|p| p.id.clone()).collect();
    if outside.is_empty() {
        tmux(&["set-option", "-g", "@sidecar_win", win])?;
        return Ok(());
    }
    let all_ids: Vec<String> = group.iter().map(|p| p.id.clone()).collect();
    // The window's own focused pane, to give focus back after the rebuild (swap-pane -d
    // keeps the active cell, not the active pane, so focus can drift into the group).
    let mine = in_win.iter().find(|p| p.active && !p.tag).map(|p| p.id.clone());

    // The group is hidden in another window: put it back there, then follow normally.
    if depth == 0 {
        if let Some(h) = st.panes.iter().find(|p| p.shide && p.sess != STASH) {
            exit_full(&h.win.clone(), true, true)?;
            return sync_d(win, 1);
        }
    }

    // Source window = where most of the outside panes are.
    let mut counts: HashMap<&str, usize> = HashMap::new();
    for p in group.iter().filter(|p| p.win != win) {
        *counts.entry(p.win.as_str()).or_default() += 1;
    }
    let src = counts.into_iter().max_by_key(|(_, c)| *c).map(|(w, _)| w.to_string()).unwrap();

    // Leaving a maximized window: bring its regular panes back first.
    if depth == 0 && st.panes.iter().any(|p| p.win == src && p.sfull) {
        exit_full(&src, false, true)?;
        return sync_d(win, 1);
    }

    // Departure: unzoom the source so geometry is real, then record it.
    let mut sp: Vec<Pane> = st.panes.iter().filter(|p| p.win == src).cloned().collect();
    let zp = sp.iter().find(|p| p.zoomed && p.active).map(|p| p.id.clone());
    if let Some(z) = &zp {
        tmux(&["resize-pane", "-Z", "-t", z])?;
        sp = list_window(&src)?;
    }
    let src_group: Vec<String> = sp.iter().filter(|p| p.tag).map(|p| p.id.clone()).collect();
    let mut snap = take_snapshot(&sp, &src_group);
    let mut pre: Vec<String> = Vec::new();
    match &snap {
        Some(s) if s.ser() == st.built => snap = None, // exactly what we built: keep original
        _ => {}
    }
    let chosen: Option<Snapshot> = match &snap {
        Some(s) => {
            pre.extend(["set-option", "-g", "@sidecar_snap", &s.ser(), ";"].map(String::from));
            Some(s.clone())
        }
        None => Snapshot::parse(&st.snap),
    };
    let szoom = match &zp {
        Some(z) if all_ids.contains(z) => z.clone(),
        _ => String::new(),
    };
    pre.extend(["set-option", "-w", "-t", &src, "@sidecar_zoom", &szoom].map(String::from));
    let nzoom = match &zp {
        Some(z) if !all_ids.contains(z) => z.clone(),
        _ => String::new(),
    };
    let sactive = sp
        .iter()
        .find(|p| p.active && all_ids.contains(&p.id))
        .map(|p| p.id.clone())
        .unwrap_or_default();
    pre.extend([";", "set-option", "-w", "-t", &src, "@sidecar_nzoom", &nzoom].map(String::from));
    pre.extend([";", "set-option", "-w", "-t", &src, "@sidecar_active", &sactive].map(String::from));
    if let Some(l) = sp.first().map(|p| p.layout.clone()).filter(|l| !l.is_empty()) {
        pre.extend([";", "set-option", "-w", "-t", &src, "@sidecar_layout", &l].map(String::from));
    }

    // Arrival.
    let tz = in_win.iter().find(|p| p.zoomed && p.active).map(|p| p.id.clone());
    if let Some(z) = &tz {
        pre.extend([";", "resize-pane", "-Z", "-t", z].map(String::from));
    }
    let wdims = in_win.first().map(|p| (p.ww, p.wh)).unwrap_or((0, 0));
    let partial = group.iter().any(|p| p.win == win);
    let res = if partial {
        Err("partially present".to_string())
    } else {
        restore(win, wdims, &outside, chosen.as_ref(), pre.clone())
    };
    if res.is_err() {
        fallback(win, &outside);
    }

    let wp = list_window(win)?;
    let mut built_snap = take_snapshot(&wp, &all_ids);
    // Put the window's own panes back exactly as they were when the group left,
    // then bend the group region to the current arrangement.
    let saved = in_win.first().map(|p| p.slayout.clone()).unwrap_or_default();
    if !saved.is_empty() && res.is_ok() {
        let mut now: Vec<String> = wp.iter().map(|p| p.id.clone()).collect();
        // select-layout hands cells to panes in window order and ignores the ids
        // in the string, so first put the panes in the order the layout lists them.
        let mut cmd: Vec<String> = Vec::new();
        let want = layout_ids(&saved).filter(|ids| same_set(ids, &now));
        if let Some(want) = &want {
            for i in 0..want.len() {
                if now[i] != want[i] {
                    let j = now.iter().position(|x| *x == want[i]).unwrap();
                    cmd.extend(["swap-pane", "-d", "-s", &now[i], "-t", &now[j], ";"].map(String::from));
                    now.swap(i, j);
                }
            }
            cmd.extend(["select-layout", "-t", win, &saved].map(String::from));
        }
        if want.is_some() && tmux_v(&cmd).is_ok() {
            if let Some(target) = &built_snap {
                let mut after = take_snapshot(&list_window(win)?, &all_ids);
                if let Some(a) = &after {
                    if a.edge == target.edge && a.size != target.size {
                        let horiz = a.edge == "left" || a.edge == "right";
                        let root = a.tree.leaf_ids()[0].clone();
                        let _ = tmux(&["resize-pane", "-t", &root, if horiz { "-x" } else { "-y" },
                                       &target.size.to_string()]);
                        after = take_snapshot(&list_window(win)?, &all_ids);
                    }
                }
                if let Some(a) = &after {
                    if a.edge == target.edge {
                        reshape(&target.tree, &a.tree);
                    }
                }
            }
            built_snap = take_snapshot(&list_window(win)?, &all_ids);
        }
    }
    let built = built_snap.map(|s| s.ser()).unwrap_or_default();
    let want = {
        let first = in_win.first();
        let sz = first.map(|p| p.szoom.clone()).unwrap_or_default();
        let nz = first.map(|p| p.nzoom.clone()).unwrap_or_default();
        let exists = |id: &str| wp.iter().any(|p| p.id == id) && !all_ids.contains(&id.to_string());
        if all_ids.contains(&sz) {
            Some(sz)
        } else if tz.is_some() {
            tz
        } else if !nz.is_empty() && exists(&nz) {
            Some(nz)
        } else {
            None
        }
    };
    // Focus: if the sidecar had it when you left, give it back.
    let focus = in_win
        .first()
        .map(|p| p.sactive.clone())
        .filter(|a| want.is_none() && all_ids.contains(a));
    let mut fin: Vec<String> = ["set-option", "-g", "@sidecar_win", win, ";",
                                "set-option", "-g", "@sidecar_built", &built].map(String::from).to_vec();
    if let Some(z) = &zp {
        if !all_ids.contains(z) {
            fin.extend([";", "resize-pane", "-Z", "-t", z].map(String::from)); // normal pane was zoomed
        }
    }
    let _ = tmux_v(&fin);
    if let Some(w) = want {
        let _ = tmux(&["resize-pane", "-Z", "-t", &w]);
    } else if let Some(f) = focus {
        let _ = tmux(&["select-pane", "-t", &f]);
    } else if let Some(m) = mine {
        let _ = tmux(&["select-pane", "-t", &m]);
    }
    if in_win.first().map(|p| p.fresume).unwrap_or(false) {
        let _ = tmux(&["set-option", "-wu", "-t", win, "@sidecar_fresume"]);
        let _ = enter_full(win, false); // it was maximized when you left: maximize again
    }
    if in_win.first().map(|p| p.hresume).unwrap_or(false) {
        let _ = tmux(&["set-option", "-wu", "-t", win, "@sidecar_hresume"]);
        let _ = enter_full(win, true); // it was hidden when you left: hide again
    }
    let pz = opt_w(win, "@sidecar_presume");
    if !pz.is_empty() {
        let _ = tmux(&["set-option", "-wu", "-t", win, "@sidecar_presume"]);
        let _ = enter_pz(win, Some(&pz)); // a pane was expanded when you left: expand again
    }
    Ok(())
}

fn acquire(lock: &str) -> bool {
    for _ in 0..150 {
        if fs::create_dir(lock).is_ok() {
            return true;
        }
        if let Ok(age) = fs::metadata(lock).and_then(|m| m.modified()).and_then(|t| {
            SystemTime::now().duration_since(t).map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))
        }) {
            if age > Duration::from_secs(5) {
                let _ = fs::remove_dir(lock); // stale lock from a crashed run
            }
        }
        thread::sleep(Duration::from_millis(20));
    }
    false
}

// --- proportional layouts -------------------------------------------------------

// A tmux layout as a tree, so saved layouts can be rescaled instead of handed to
// select-layout at a stale size (tmux then spreads the difference evenly, in cells,
// so a 33% pane drifts as the window changes size).
#[derive(Clone, Debug, PartialEq)]
enum Kind {
    Leaf(String), // pane number, as in the layout
    Row(Vec<Cell>), // "{...}": side by side
    Col(Vec<Cell>), // "[...]": stacked
}

#[derive(Clone, Debug, PartialEq)]
struct Cell {
    w: i32,
    h: i32,
    x: i32,
    y: i32,
    k: Kind,
}

fn parse_layout(s: &str) -> Option<Cell> {
    fn num(b: &[u8], i: &mut usize) -> Option<i32> {
        let st = *i;
        while *i < b.len() && b[*i].is_ascii_digit() {
            *i += 1;
        }
        std::str::from_utf8(&b[st..*i]).ok()?.parse().ok()
    }
    fn eat(b: &[u8], i: &mut usize, c: u8) -> Option<()> {
        (b.get(*i)? == &c).then(|| *i += 1)
    }
    fn cell(b: &[u8], i: &mut usize) -> Option<Cell> {
        let w = num(b, i)?;
        eat(b, i, b'x')?;
        let h = num(b, i)?;
        eat(b, i, b',')?;
        let x = num(b, i)?;
        eat(b, i, b',')?;
        let y = num(b, i)?;
        let k = match b.get(*i) {
            Some(b',') => {
                *i += 1;
                Kind::Leaf(num(b, i)?.to_string())
            }
            Some(&o) if o == b'{' || o == b'[' => {
                let close = if o == b'{' { b'}' } else { b']' };
                *i += 1;
                let mut kids = Vec::new();
                loop {
                    kids.push(cell(b, i)?);
                    match *b.get(*i)? {
                        b',' => *i += 1,
                        c if c == close => {
                            *i += 1;
                            break;
                        }
                        _ => return None,
                    }
                }
                if o == b'{' { Kind::Row(kids) } else { Kind::Col(kids) }
            }
            _ => return None,
        };
        Some(Cell { w, h, x, y, k })
    }
    let b = s.as_bytes();
    let mut i = s.find(',')? + 1;
    let c = cell(b, &mut i)?;
    (i == b.len()).then_some(c)
}

impl Cell {
    fn dump(&self, out: &mut String) {
        out.push_str(&format!("{}x{},{},{}", self.w, self.h, self.x, self.y));
        match &self.k {
            Kind::Leaf(id) => out.push_str(&format!(",{}", id)),
            Kind::Row(kids) | Kind::Col(kids) => {
                let (open, close) = if matches!(self.k, Kind::Row(_)) { ('{', '}') } else { ('[', ']') };
                out.push(open);
                for (n, c) in kids.iter().enumerate() {
                    if n > 0 {
                        out.push(',');
                    }
                    c.dump(out);
                }
                out.push(close);
            }
        }
    }
    // The layout string select-layout takes, checksum included (tmux's layout_checksum).
    fn layout(&self) -> String {
        let mut body = String::new();
        self.dump(&mut body);
        let mut sum: u16 = 0;
        for c in body.bytes() {
            sum = (sum >> 1) | ((sum & 1) << 15);
            sum = sum.wrapping_add(c as u16);
        }
        format!("{:04x},{}", sum, body)
    }
    // Arrangement without sizes, to tell whether two layouts are the same split tree.
    fn shape(&self) -> String {
        match &self.k {
            Kind::Leaf(id) => id.clone(),
            Kind::Row(kids) | Kind::Col(kids) => {
                let inner: Vec<String> = kids.iter().map(|c| c.shape()).collect();
                let (o, c) = if matches!(self.k, Kind::Row(_)) { ("{", "}") } else { ("[", "]") };
                format!("{}{}{}", o, inner.join(","), c)
            }
        }
    }
    fn ids(&self) -> Vec<String> {
        match &self.k {
            Kind::Leaf(id) => vec![format!("%{}", id)],
            Kind::Row(kids) | Kind::Col(kids) => kids.iter().flat_map(|c| c.ids()).collect(),
        }
    }
    // Along the split axis of a Row (true) or Col (false).
    fn len(&self, row: bool) -> i32 {
        if row { self.w } else { self.h }
    }
    // This cell scaled to w x h at (x, y), every split keeping its proportions.
    fn scaled(&self, w: i32, h: i32, x: i32, y: i32) -> Cell {
        let k = match &self.k {
            Kind::Leaf(id) => Kind::Leaf(id.clone()),
            Kind::Row(kids) | Kind::Col(kids) => {
                let row = matches!(self.k, Kind::Row(_));
                let old: Vec<i32> = kids.iter().map(|c| c.len(row)).collect();
                let sizes = shares(&old, if row { w } else { h });
                Cell::place_kids(kids, &sizes, row, w, h, x, y, |c, cw, ch, cx, cy| c.scaled(cw, ch, cx, cy))
            }
        };
        Cell { w, h, x, y, k }
    }
    fn place_kids(kids: &[Cell], sizes: &[i32], row: bool, w: i32, h: i32, x: i32, y: i32,
                  mut f: impl FnMut(&Cell, i32, i32, i32, i32) -> Cell) -> Kind {
        let mut at = if row { x } else { y };
        let mut out = Vec::new();
        for (c, &sz) in kids.iter().zip(sizes) {
            out.push(if row { f(c, sz, h, at, y) } else { f(c, w, sz, x, at) });
            at += sz + 1; // one cell of border between panes
        }
        if row { Kind::Row(out) } else { Kind::Col(out) }
    }
}

// Split `total` cells (borders included) among parts in proportion to `old`, each at
// least 1. Boundaries are rounded from running totals, so no rounding error piles up.
fn shares(old: &[i32], total: i32) -> Vec<i32> {
    let n = old.len() as i32;
    let avail = (total - (n - 1)).max(n);
    let sum: i64 = old.iter().map(|&v| v.max(1) as i64).sum();
    let mut out = Vec::new();
    let (mut run, mut prev) = (0i64, 0i32);
    for (i, &v) in old.iter().enumerate() {
        run += v.max(1) as i64;
        let left = n - 1 - i as i32; // parts still to come, 1 cell each at least
        let edge = ((run as f64) * (avail as f64) / (sum as f64)).round() as i32;
        let edge = edge.max(prev + 1).min(avail - left);
        out.push(edge - prev);
        prev = edge;
    }
    out
}

// `saved` rescaled to a w x h window, or None if it does not parse.
fn fit_layout(saved: &str, w: i32, h: i32) -> Option<String> {
    let c = parse_layout(saved)?;
    if (c.w, c.h) == (w, h) {
        return Some(saved.to_string());
    }
    Some(c.scaled(w, h, 0, 0).layout())
}

fn win_size(win: &str) -> Option<(i32, i32)> {
    let out = tmux(&["display-message", "-p", "-t", win, "#{window_width} #{window_height}"]).ok()?;
    let (w, h) = dims(&out);
    (w > 0 && h > 0).then_some((w, h))
}

// The pre-expand layout `saved`, with the expanded side refitted into the space the
// expanded pane `anchor` has now and the other side kept as it is now (`cur`). So
// resizing the sides, or the window, while a pane is expanded sticks. None if either
// layout is not split cleanly between the two sides at the top.
fn remap_pz(saved: &str, cur: &str, anchor: &str, side: &[String]) -> Option<String> {
    let s = parse_layout(saved)?;
    let c = parse_layout(cur)?;
    let (row, skids, ckids) = match (&s.k, &c.k) {
        (Kind::Row(a), Kind::Row(b)) => (true, a, b),
        (Kind::Col(a), Kind::Col(b)) => (false, a, b),
        _ => return None,
    };
    // Top-level cells of `saved` on the expanded side; they must be all of one side
    // and next to each other.
    let mut exp = Vec::new();
    for (i, k) in skids.iter().enumerate() {
        let ids = k.ids();
        let n = ids.iter().filter(|id| side.contains(id)).count();
        if n == ids.len() {
            exp.push(i);
        } else if n > 0 {
            return None;
        }
    }
    let (first, last) = (*exp.first()?, *exp.last()?);
    if last - first + 1 != exp.len() {
        return None;
    }
    let a = ckids.iter().find(|k| k.ids() == [anchor.to_string()])?;
    let exp_sizes = shares(&exp.iter().map(|&i| skids[i].len(row)).collect::<Vec<_>>(), a.len(row));
    let mut sizes = Vec::new();
    let mut from: Vec<Option<&Cell>> = Vec::new(); // current cell to keep, for the other side
    for (i, k) in skids.iter().enumerate() {
        if i >= first && i <= last {
            sizes.push(exp_sizes[i - first]);
            from.push(None);
        } else {
            let mut ids = k.ids();
            ids.sort();
            let now = ckids.iter().find(|ck| {
                let mut ci = ck.ids();
                ci.sort();
                ci == ids
            })?;
            sizes.push(now.len(row));
            from.push((now.shape() == k.shape()).then_some(now));
        }
    }
    if sizes.iter().sum::<i32>() + sizes.len() as i32 - 1 != c.len(row) {
        return None;
    }
    let mut n = 0;
    let k = Cell::place_kids(skids, &sizes, row, c.w, c.h, 0, 0, |k, w, h, x, y| {
        let keep = from[n];
        n += 1;
        keep.unwrap_or(k).scaled(w, h, x, y)
    });
    Some(Cell { w: c.w, h: c.h, x: 0, y: 0, k }.layout())
}

// Window resized: scale the layout last arranged (@sidecar_lay, kept by tmux.conf hooks)
// to the new size, so every split keeps its ratio. A changed arrangement just becomes
// the new reference. Zoom is kept.
fn fit(win: &str) -> Res<()> {
    let out = tmux(&["display-message", "-p", "-t", win,
                     "#{window_width}\t#{window_height}\t#{window_layout}\t#{window_zoomed_flag}\t#{pane_id}\t#{@sidecar_lay}"])?;
    let f: Vec<&str> = out.split('\t').collect();
    if f.len() < 6 {
        return Ok(());
    }
    let (w, h) = (f[0].parse().unwrap_or(0), f[1].parse().unwrap_or(0));
    let (cur, zoomed, active, saved) = (f[2], f[3] == "1", f[4], f[5]);
    let (Some(c), Some(s)) = (parse_layout(cur), parse_layout(saved)) else {
        tmux(&["set-option", "-w", "-t", win, "@sidecar_lay", cur])?;
        return Ok(());
    };
    if c.shape() != s.shape() {
        tmux(&["set-option", "-w", "-t", win, "@sidecar_lay", cur])?;
        return Ok(());
    }
    let want = s.scaled(w, h, 0, 0);
    if want == c {
        return Ok(());
    }
    let lay = want.layout();
    let mut cmd = vec!["set-option", "-w", "-t", win, "@sidecar_fitting", "1", ";", "select-layout", "-t", win, &lay];
    if zoomed {
        cmd.extend([";", "resize-pane", "-Z", "-t", active]);
    }
    cmd.extend([";", "set-option", "-wu", "-t", win, "@sidecar_fitting"]);
    tmux(&cmd).map(|_| ())
}

// After sidecar rearranged panes: tmux has no hook for join-pane, so record each
// window's arrangement as the new reference for fit. A window that only differs in
// size is left alone: fit keeps its reference ratios.
fn refresh_lays() {
    let Ok(out) = tmux(&["list-windows", "-a", "-F", "#{window_id}\t#{window_layout}\t#{@sidecar_lay}"]) else { return };
    for l in out.lines() {
        let f: Vec<&str> = l.split('\t').collect();
        if f.len() < 3 || f[1] == f[2] {
            continue;
        }
        let keep = match (parse_layout(f[1]), parse_layout(f[2])) {
            (Some(c), Some(s)) => c.shape() == s.shape() && (c.w, c.h) != (s.w, s.h),
            _ => false,
        };
        if !keep {
            let _ = tmux(&["set-option", "-w", "-t", f[0], "@sidecar_lay", f[1]]);
        }
    }
}

// --- maximize the group in place -------------------------------------------

// Order the window's panes as `want` lists them (select-layout assigns cells by
// order, ignoring ids), then apply the layout. False if the pane sets differ.
fn apply_layout(win: &str, saved: &str, now: &mut Vec<String>) -> bool {
    apply_layout_as(win, saved, now, None)
}

// Like apply_layout, but `sub` = (old, new) puts pane `new` in the cell `saved`
// recorded for pane `old` (a stand-in for a pane that no longer exists).
fn apply_layout_as(win: &str, saved: &str, now: &mut Vec<String>, sub: Option<(&str, &str)>) -> bool {
    let ids = layout_ids(saved).map(|ids| {
        ids.into_iter()
            .map(|id| match sub { Some((o, n)) if id == o => n.to_string(), _ => id })
            .collect::<Vec<String>>()
    });
    let want = match ids.filter(|ids| same_set(ids, now)) {
        Some(w) => w,
        None => return false,
    };
    let mut cmd: Vec<String> = Vec::new();
    for i in 0..want.len() {
        if now[i] != want[i] {
            let j = now.iter().position(|x| *x == want[i]).unwrap();
            cmd.extend(["swap-pane", "-d", "-s", &now[i], "-t", &now[j], ";"].map(String::from));
            now.swap(i, j);
        }
    }
    // Saved at another window size (the window was resized since): scale it rather
    // than let tmux spread the difference evenly.
    let fitted = win_size(win).and_then(|(w, h)| fit_layout(saved, w, h)).unwrap_or_else(|| saved.to_string());
    cmd.extend(["select-layout", "-t", win, &fitted].map(String::from));
    tmux_v(&cmd).is_ok()
}

fn rescue(win: &str, ids: &[String]) {
    let mut first: Option<String> = None;
    for id in ids {
        match &first {
            None => {
                let _ = tmux(&["join-pane", "-d", "-f", "-h", "-b", "-l", "50%", "-s", id, "-t", win]);
                first = Some(id.clone());
            }
            Some(f) => {
                let _ = tmux(&["join-pane", "-d", "-v", "-s", id, "-t", f]);
            }
        }
    }
}

fn opt_w(win: &str, name: &str) -> String {
    tmux(&["show-options", "-wqv", "-t", win, name]).unwrap_or_default()
}

// Maximize one side in place. `hide` = false: maximize the group (the regular
// panes are parked in a hidden session). `hide` = true: maximize the regular
// panes (the group is parked instead). Splits stay intact either way.
fn full_opt(hide: bool) -> &'static str {
    if hide { "@sidecar_hide" } else { "@sidecar_full" }
}

fn full_keys(hide: bool) -> [String; 4] {
    let o = full_opt(hide);
    [o.to_string(), format!("{}_panes", o), format!("{}_layout", o), format!("{}_zoom", o)]
}

fn enter_full(win: &str, hide: bool) -> Res<()> {
    sync(win)?; // make sure the group is here
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    if in_win.first().map(|p| p.sfull || p.shide).unwrap_or(false) {
        return Ok(());
    }
    let group: Vec<String> = in_win.iter().filter(|p| p.tag).map(|p| p.id.clone()).collect();
    let regular: Vec<String> = in_win.iter().filter(|p| !p.tag).map(|p| p.id.clone()).collect();
    if group.is_empty() || regular.is_empty() {
        return Ok(());
    }
    // `parked` leaves the window; `kept` fills it.
    let (parked, kept) = if hide { (&group, &regular) } else { (&regular, &group) };
    let zp = in_win.iter().find(|p| p.zoomed && p.active).map(|p| p.id.clone());
    if let Some(z) = &zp {
        tmux(&["resize-pane", "-Z", "-t", z])?;
    }
    let before = list_window(win)?;
    let layout = before.first().map(|p| p.layout.clone()).unwrap_or_default();
    let (ww, wh) = in_win.first().map(|p| (p.ww, p.wh)).unwrap_or((80, 24));

    let _ = tmux(&["kill-session", "-t", &format!("={}", STASH)]);
    let ph = tmux(&["new-session", "-d", "-s", STASH, "-x", &ww.to_string(), "-y", &wh.to_string(),
                    "-P", "-F", "#{pane_id}", "sleep", "600"])?;
    let mut moved: Vec<String> = Vec::new();
    let mut failed = false;
    for r in parked {
        let _ = tmux(&["select-layout", "-t", &ph, "tiled"]);
        if tmux(&["join-pane", "-d", "-s", r, "-t", &ph]).is_err() {
            failed = true;
            break;
        }
        moved.push(r.clone());
    }
    if failed {
        for r in &moved {
            let _ = tmux(&["join-pane", "-d", "-s", r, "-t", &kept[0]]);
        }
        let _ = tmux(&["kill-session", "-t", &format!("={}", STASH)]);
        if let Some(z) = zp {
            let _ = tmux(&["resize-pane", "-Z", "-t", &z]);
        }
        return Err("not enough room to stash the other panes".into());
    }
    let _ = tmux(&["kill-pane", "-t", &ph]);
    if hide {
        spread(win, &before, &regular);
    }
    // A zoomed regular pane is zoomed again on exit.
    let rz = zp.filter(|z| regular.contains(z)).unwrap_or_default();
    let [k, kp, kl, kz] = full_keys(hide);
    tmux(&["set-option", "-w", "-t", win, &k, "1", ";",
           "set-option", "-w", "-t", win, &kp, &parked.join(" "), ";",
           "set-option", "-w", "-t", win, &kl, &layout, ";",
           "set-option", "-w", "-t", win, &kz, &rz])?;
    Ok(())
}

// Undo enter_full. `leaving` = the group is about to move to another window, so
// remember to maximize/hide again when it comes back.
fn exit_full(win: &str, hide: bool, leaving: bool) -> Res<()> {
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    let [k, kp, kl, kz] = full_keys(hide);
    let ids = opt_w(win, &kp);
    let layout = opt_w(win, &kl);
    let zoom = opt_w(win, &kz);
    let parked: Vec<String> = ids
        .split_whitespace()
        .filter(|id| st.panes.iter().any(|p| p.id == *id))
        .map(String::from)
        .collect();
    // `kept` is what stayed in the window (the group, or the regular panes if hiding).
    let kept: Vec<String> = in_win.iter().filter(|p| p.tag != hide).map(|p| p.id.clone()).collect();
    if let Some(z) = in_win.iter().find(|p| p.zoomed && p.active) {
        let _ = tmux(&["resize-pane", "-Z", "-t", &z.id]); // a pane that stayed was zoomed
    }
    for o in &[k, kp, kl, kz] {
        let _ = tmux(&["set-option", "-wu", "-t", win, o]);
    }
    if parked.is_empty() || kept.is_empty() {
        return Ok(());
    }
    let mut all = kept.clone();
    all.extend(parked.iter().cloned());
    let exact = layout_ids(&layout).map(|l| same_set(&l, &all)).unwrap_or(false);
    let wdims = in_win.first().map(|p| (p.ww, p.wh)).unwrap_or((0, 0));
    if exact {
        // Same panes as before: put everything back exactly where it was.
        for r in &parked {
            let _ = tmux(&["join-pane", "-d", "-s", r, "-t", &kept[0]]);
        }
        let mut now: Vec<String> = list_window(win)?.iter().map(|p| p.id.clone()).collect();
        if !apply_layout(win, &layout, &mut now) {
            return Err("could not restore the window layout".into());
        }
    } else if hide {
        // Panes changed meanwhile: rebuild the group from its last recorded arrangement.
        restore(win, wdims, &parked, Snapshot::parse(&st.snap).as_ref(), Vec::new())?;
    } else {
        // The group changed meanwhile: stack the regular panes opposite the group.
        let regular = &parked;
        let prev = Snapshot::parse(&st.snap);
        let (edge, size, dim) = match &prev {
            Some(p) => (p.edge.clone(), p.size, p.dim),
            None => ("right".to_string(), (wdims.0 as f64 * DEFAULT_SIZE) as i32, wdims.0),
        };
        let horiz = edge == "left" || edge == "right";
        let opp = match edge.as_str() { "right" => "left", "left" => "right", "top" => "bottom", _ => "top" };
        let wd = if horiz { wdims.0 } else { wdims.1 };
        let gsize = ((size as f64) * (wd as f64) / (dim.max(1) as f64)).round() as i32;
        let region = (wd - gsize - 1).max(1);
        let snap = Snapshot {
            edge: opp.into(),
            size: region,
            dim: wd,
            tree: stack(regular, if horiz { 'v' } else { 'h' }),
        };
        restore(win, wdims, regular, Some(&snap), Vec::new())?;
    }
    if leaving {
        let _ = tmux(&["set-option", "-w", "-t", win, if hide { "@sidecar_hresume" } else { "@sidecar_fresume" }, "1"]);
    }
    // Zoom is only recorded for a pane that stayed in the window (hide mode).
    if hide && !zoom.is_empty() && kept.contains(&zoom) {
        let _ = tmux(&["resize-pane", "-Z", "-t", &zoom]);
    } else if !hide && !zoom.is_empty() && parked.contains(&zoom) {
        let _ = tmux(&["resize-pane", "-Z", "-t", &zoom]);
    }
    Ok(())
}

// Z toggles: restore if either side is maximized; otherwise maximize the side
// that has focus.
fn toggle_full(win: &str) -> Res<()> {
    if !opt_w(win, "@sidecar_pzoom").is_empty() {
        exit_pz(win)?; // collapse an expanded pane first
    }
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    if in_win.iter().any(|p| p.sfull) {
        exit_full(win, false, false)
    } else if in_win.iter().any(|p| p.shide) {
        exit_full(win, true, false)
    } else {
        let on_group = in_win.iter().find(|p| p.active).map(|p| p.tag).unwrap_or(true);
        enter_full(win, !on_group)
    }
}

// --- expand one pane within its side -----------------------------------------

// Park the siblings of the focused pane (or `resume`, when re-expanding after a
// window switch) on its side (group or regular) in a hidden session, so it fills
// that side. The other side is untouched.
fn enter_pz(win: &str, resume: Option<&str>) -> Res<()> {
    let st = read_state()?;
    if st.panes.iter().any(|p| p.sess == PSTASH) {
        return Err("expand stash already holds panes".into());
    }
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    let pick = |p: &&&Pane| match resume { Some(id) => p.id == id, None => p.active };
    let Some(cur) = in_win.iter().find(pick).map(|p| (*p).clone()) else { return Ok(()) };
    if resume.is_some() && cur.zoomed {
        return Ok(()); // a z-zoom was restored on arrival: leave it be
    }
    let side: Vec<&Pane> = in_win.iter().copied().filter(|p| p.tag == cur.tag).collect();
    let parked: Vec<String> = side.iter().filter(|p| p.id != cur.id).map(|p| p.id.clone()).collect();
    if parked.is_empty() {
        if resume.is_none() {
            let _ = tmux(&["display-message", "sidecar: no other pane on this side"]);
        }
        return Ok(());
    }
    if cur.zoomed {
        tmux(&["resize-pane", "-Z", "-t", &cur.id])?;
    }
    let before = list_window(win)?;
    let layout = before.first().map(|p| p.layout.clone()).unwrap_or_default();
    let (x0, y0, x1, y1) = bbox(before.iter().filter(|p| p.tag == cur.tag).map(|p| (p.x, p.y, p.w, p.h)));

    let ph = tmux(&["new-session", "-d", "-s", PSTASH, "-x", &cur.ww.to_string(), "-y", &cur.wh.to_string(),
                    "-P", "-F", "#{pane_id}", "sleep", "600"])?;
    for (i, r) in parked.iter().enumerate() {
        let _ = tmux(&["select-layout", "-t", &ph, "tiled"]);
        if let Err(e) = tmux(&["join-pane", "-d", "-s", r, "-t", &ph]) {
            for m in &parked[..i] {
                let _ = tmux(&["join-pane", "-d", "-s", m, "-t", &cur.id]);
            }
            let _ = tmux(&["kill-pane", "-t", &ph]);
            let mut now: Vec<String> = list_window(win)?.iter().map(|p| p.id.clone()).collect();
            apply_layout(win, &layout, &mut now);
            return Err(e);
        }
    }
    let _ = tmux(&["kill-pane", "-t", &ph]);
    // tmux hands a removed pane's space to its previous neighbour, which can be on
    // the other side; size the pane back to the side's full extent.
    let _ = tmux(&["resize-pane", "-t", &cur.id, "-x", &(x1 - x0).to_string(), "-y", &(y1 - y0).to_string()]);
    tmux(&["set-option", "-w", "-t", win, "@sidecar_pzoom", &cur.id, ";",
           "set-option", "-w", "-t", win, "@sidecar_pzoom_panes", &parked.join(" "), ";",
           "set-option", "-w", "-t", win, "@sidecar_pzoom_layout", &layout])?;
    Ok(())
}

// Undo enter_pz: bring the parked panes back and reapply the saved layout.
// If panes came or went meanwhile, they rejoin next to the expanded pane instead.
fn exit_pz(win: &str) -> Res<()> {
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    let anchor = opt_w(win, "@sidecar_pzoom");
    let layout = opt_w(win, "@sidecar_pzoom_layout");
    // Still parked = exists and not already back (a failed earlier exit may have moved some).
    let parked: Vec<&Pane> = opt_w(win, "@sidecar_pzoom_panes")
        .split_whitespace()
        .filter_map(|id| st.panes.iter().find(|p| p.id == id && p.win != win))
        .collect();
    if let Some(z) = in_win.iter().find(|p| p.zoomed && p.active) {
        let _ = tmux(&["resize-pane", "-Z", "-t", &z.id]);
    }
    let mut all: Vec<String> = in_win.iter().map(|p| p.id.clone()).collect();
    all.extend(parked.iter().map(|p| p.id.clone()));
    // The expanded pane itself was closed: restore the saved layout with a stand-in
    // in its cell, then close the stand-in, so the side ends up as if the pane had
    // been closed without being expanded.
    let gone = !anchor.is_empty() && !st.panes.iter().any(|p| p.id == anchor);
    if gone {
        all.push(anchor.clone());
    }
    let exact = layout_ids(&layout).map(|l| same_set(&l, &all)).unwrap_or(false);
    let side_tag = parked.first().map(|p| p.tag).unwrap_or(false);
    // Keep sizes changed while expanded (the sides' split, or the window).
    let layout = match (gone, in_win.first()) {
        (false, Some(p)) if exact => {
            let mut side: Vec<String> = parked.iter().map(|p| p.id.clone()).collect();
            side.push(anchor.clone());
            remap_pz(&layout, &p.layout, &anchor, &side).unwrap_or(layout)
        }
        _ => layout,
    };
    let near = in_win
        .iter()
        .find(|p| p.id == anchor)
        .or_else(|| in_win.iter().find(|p| p.tag == side_tag))
        .or_else(|| in_win.first())
        .map(|p| p.id.clone());
    // Nothing left on that side (the expanded pane was closed): rebuild it as a
    // full-height column on its edge (group right, regular left), stacked inside.
    let mut near = near;
    let mut parked = &parked[..];
    if !exact && !in_win.iter().any(|p| p.tag == side_tag) {
        if let Some(first) = parked.first() {
            let mut a = vec!["join-pane", "-d", "-f", "-h"];
            if !side_tag {
                a.push("-b");
            }
            a.extend(["-l", if side_tag { "30%" } else { "50%" }, "-s", &first.id, "-t", win]);
            tmux(&a)?;
            near = Some(first.id.clone());
            parked = &parked[1..];
        }
    }
    for r in parked {
        if !exact {
            let Some(t) = &near else { break };
            tmux(&["join-pane", "-d", "-v", "-s", &r.id, "-t", t])?;
            continue;
        }
        // Exact restore rearranges everything anyway. Split the roomiest pane on the
        // same side, so panes on the other side (e.g. nvim) are never resized and
        // don't flash; fall back to the roomiest pane anywhere if that one is too small.
        let now = list_window(win)?;
        let roomiest = |same: bool| {
            now.iter().filter(|p| !same || p.tag == side_tag).max_by_key(|p| p.w * p.h).map(|p| p.id.clone())
        };
        let joined = match roomiest(true) {
            Some(t) => tmux(&["join-pane", "-d", "-v", "-s", &r.id, "-t", &t]).is_ok(),
            None => false,
        };
        if !joined {
            let Some(t) = roomiest(false) else { break };
            tmux(&["join-pane", "-d", "-v", "-s", &r.id, "-t", &t])?;
        }
    }
    for o in ["@sidecar_pzoom", "@sidecar_pzoom_panes", "@sidecar_pzoom_layout"] {
        let _ = tmux(&["set-option", "-wu", "-t", win, o]);
    }
    if exact && gone {
        let now = list_window(win)?;
        let host = now.iter().filter(|p| p.tag == side_tag).max_by_key(|p| p.w * p.h)
            .or_else(|| now.iter().max_by_key(|p| p.w * p.h))
            .map(|p| p.id.clone())
            .ok_or("no pane to split")?;
        let ghost = tmux(&["split-window", "-d", "-v", "-t", &host, "-P", "-F", "#{pane_id}", "sleep", "600"])?;
        let mut ids: Vec<String> = list_window(win)?.iter().map(|p| p.id.clone()).collect();
        let ok = apply_layout_as(win, &layout, &mut ids, Some((&anchor, &ghost)));
        let before = list_window(win)?;
        let _ = tmux(&["kill-pane", "-t", &ghost]);
        if !ok {
            return Err("could not restore the window layout".into());
        }
        // Focus the pane on that side that took over the closed pane's space.
        let after = list_window(win)?;
        let grown = after.iter().filter(|p| p.tag == side_tag).find(|p| {
            before.iter().any(|b| b.id == p.id && b.w * b.h < p.w * p.h)
        });
        if let Some(t) = grown.map(|p| p.id.clone()).or_else(|| parked.first().map(|p| p.id.clone())) {
            let _ = tmux(&["select-pane", "-t", &t]);
        }
    } else if exact {
        let mut now: Vec<String> = list_window(win)?.iter().map(|p| p.id.clone()).collect();
        if !apply_layout(win, &layout, &mut now) {
            return Err("could not restore the window layout".into());
        }
    }
    if in_win.iter().any(|p| p.id == anchor) {
        let _ = tmux(&["select-pane", "-t", &anchor]); // swap-pane moves focus
    }
    Ok(())
}

fn toggle_pz(win: &str) -> Res<()> {
    if opt_w(win, "@sidecar_pzoom").is_empty() {
        enter_pz(win, None)
    } else {
        exit_pz(win)
    }
}

// Focus the window's leftmost regular pane: skip restoring the group's focus, zoom or
// maximize on arrival, and leave those if already applied. A zoomed regular pane, a
// hidden group and an expanded pane stay as they are.
fn left(win: &str) -> Res<()> {
    for o in ["@sidecar_active", "@sidecar_zoom", "@sidecar_fresume"] {
        tmux(&["set-option", "-wu", "-t", win, o])?;
    }
    sync(win)?; // arrive now if the hook hasn't yet; a later hook run is then a no-op
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    if in_win.iter().any(|p| p.sfull) {
        exit_full(win, false, false)?;
    } else if in_win.iter().any(|p| p.zoomed && p.active && p.tag) {
        tmux(&["resize-pane", "-Z", "-t", win])?;
    }
    let panes = list_window(win)?;
    if let Some(p) = panes.iter().filter(|p| !p.tag).min_by_key(|p| (p.x, p.y)) {
        tmux(&["select-pane", "-t", &p.id])?;
    }
    Ok(())
}

// After a pane closes: collapse any expand whose expanded pane is gone.
fn reap() -> Res<()> {
    let wins = tmux(&["list-windows", "-a", "-F", "#{window_id}\t#{@sidecar_pzoom}"])?;
    let panes = tmux(&["list-panes", "-a", "-F", "#{pane_id}"])?;
    for l in wins.lines() {
        if let Some((w, z)) = l.split_once('\t') {
            if !z.is_empty() && !panes.lines().any(|p| p == z) {
                exit_pz(w)?;
            }
        }
    }
    Ok(())
}

fn main() {
    // Usage: sidecar [WINDOW_ID] | sidecar full|pzoom|left [WINDOW_ID]
    let args: Vec<String> = env::args().skip(1).collect();
    let mode = args.first().map(|a| a.as_str()).filter(|a| ["full", "pzoom", "reap", "left", "fit"].contains(a)).map(String::from);
    let win = match args.get(if mode.is_some() { 1 } else { 0 }) {
        Some(w) => w.clone(),
        None => match tmux(&["display-message", "-p", "#{window_id}"]) {
            Ok(w) => w,
            Err(_) => return,
        },
    };
    let lock = format!("{}/tmux-sidecar.lock", env::var("TMPDIR").unwrap_or_else(|_| "/tmp".into()).trim_end_matches('/'));
    if !acquire(&lock) {
        return;
    }
    let res = match mode.as_deref() {
        Some("full") => toggle_full(&win),
        Some("pzoom") => toggle_pz(&win),
        Some("reap") => reap(),
        Some("left") => left(&win),
        Some("fit") => fit(&win),
        _ => sync(&win),
    };
    if mode.as_deref() != Some("fit") {
        refresh_lays();
    }
    if let Err(e) = res {
        eprintln!("sidecar: {}", e);
    }
    let _ = fs::remove_dir(&lock);
}
