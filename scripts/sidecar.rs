// Sidecar: a group of tmux panes (tagged @sidecar) that follows you between windows.
//
// Build:  rustc -O -o ~/scripts/sidecar ~/scripts/sidecar.rs
//
// Usage:  sidecar [WINDOW_ID]        follow: bring the group to that window
//         sidecar full [WINDOW_ID]   maximize / restore the group in that window
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

use std::collections::HashMap;
use std::process::Command;
use std::time::{Duration, SystemTime};
use std::{env, fs, thread};

const DEFAULT_SIZE: f64 = 0.30;
const FMT: &str = "#{pane_id}\t#{window_id}\t#{@sidecar}\t#{pane_left}\t#{pane_top}\t\
#{pane_width}\t#{pane_height}\t#{window_width}\t#{window_height}\t#{window_zoomed_flag}\t\
#{pane_active}\t#{@sidecar_zoom}\t#{window_active}\t#{window_layout}\t#{@sidecar_layout}\t#{@sidecar_nzoom}\t#{@sidecar_active}\t#{@sidecar_full}\t#{session_name}\t#{@sidecar_fresume}";
const STASH: &str = "_sidecar_stash";
const SEP: &str = "@@sep@@";

type Res<T> = Result<T, String>;

fn tmux(args: &[&str]) -> Res<String> {
    let out = Command::new("tmux")
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
}

fn parse_panes(s: &str) -> Vec<Pane> {
    let n = |v: &str| v.parse::<i32>().unwrap_or(0);
    s.lines()
        .filter_map(|l| {
            let f: Vec<&str> = l.split('\t').collect();
            if f.len() < 20 {
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
    // Stashed panes whose window no longer exists (e.g. its group was killed): rescue.
    let stashed: Vec<String> = st.panes.iter().filter(|p| p.sess == STASH).map(|p| p.id.clone()).collect();
    if depth == 0 && !stashed.is_empty() && !st.panes.iter().any(|p| p.sfull && p.sess != STASH) {
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

    // Source window = where most of the outside panes are.
    let mut counts: HashMap<&str, usize> = HashMap::new();
    for p in group.iter().filter(|p| p.win != win) {
        *counts.entry(p.win.as_str()).or_default() += 1;
    }
    let src = counts.into_iter().max_by_key(|(_, c)| *c).map(|(w, _)| w.to_string()).unwrap();

    // Leaving a maximized window: bring its regular panes back first.
    if depth == 0 && st.panes.iter().any(|p| p.win == src && p.sfull) {
        exit_full(&src, true)?;
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
    }
    if in_win.first().map(|p| p.fresume).unwrap_or(false) {
        let _ = tmux(&["set-option", "-wu", "-t", win, "@sidecar_fresume"]);
        let _ = enter_full(win); // it was maximized when you left: maximize again
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

// --- maximize the group in place -------------------------------------------

// Order the window's panes as `want` lists them (select-layout assigns cells by
// order, ignoring ids), then apply the layout. False if the pane sets differ.
fn apply_layout(win: &str, saved: &str, now: &mut Vec<String>) -> bool {
    let want = match layout_ids(saved).filter(|ids| same_set(ids, now)) {
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
    cmd.extend(["select-layout", "-t", win, saved].map(String::from));
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

// Maximize the group: the window's regular panes are parked in a hidden session,
// so the group fills the window (splits intact) right where you are.
fn enter_full(win: &str) -> Res<()> {
    sync(win)?; // make sure the group is here
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    if in_win.first().map(|p| p.sfull).unwrap_or(false) {
        return Ok(());
    }
    let group: Vec<String> = in_win.iter().filter(|p| p.tag).map(|p| p.id.clone()).collect();
    let regular: Vec<String> = in_win.iter().filter(|p| !p.tag).map(|p| p.id.clone()).collect();
    if group.is_empty() || regular.is_empty() {
        return Ok(());
    }
    let zp = in_win.iter().find(|p| p.zoomed && p.active).map(|p| p.id.clone());
    if let Some(z) = &zp {
        tmux(&["resize-pane", "-Z", "-t", z])?;
    }
    let layout = list_window(win)?.first().map(|p| p.layout.clone()).unwrap_or_default();
    let (ww, wh) = in_win.first().map(|p| (p.ww, p.wh)).unwrap_or((80, 24));

    let _ = tmux(&["kill-session", "-t", &format!("={}", STASH)]);
    let ph = tmux(&["new-session", "-d", "-s", STASH, "-x", &ww.to_string(), "-y", &wh.to_string(),
                    "-P", "-F", "#{pane_id}", "sleep", "600"])?;
    let mut moved: Vec<String> = Vec::new();
    let mut failed = false;
    for r in &regular {
        let _ = tmux(&["select-layout", "-t", &ph, "tiled"]);
        if tmux(&["join-pane", "-d", "-s", r, "-t", &ph]).is_err() {
            failed = true;
            break;
        }
        moved.push(r.clone());
    }
    if failed {
        for r in &moved {
            let _ = tmux(&["join-pane", "-d", "-s", r, "-t", &group[0]]);
        }
        let _ = tmux(&["kill-session", "-t", &format!("={}", STASH)]);
        if let Some(z) = zp {
            let _ = tmux(&["resize-pane", "-Z", "-t", &z]);
        }
        return Err("not enough room to stash the other panes".into());
    }
    let _ = tmux(&["kill-pane", "-t", &ph]);
    let rz = zp.filter(|z| regular.contains(z)).unwrap_or_default();
    tmux(&["set-option", "-w", "-t", win, "@sidecar_full", "1", ";",
           "set-option", "-w", "-t", win, "@sidecar_full_panes", &regular.join(" "), ";",
           "set-option", "-w", "-t", win, "@sidecar_full_layout", &layout, ";",
           "set-option", "-w", "-t", win, "@sidecar_full_zoom", &rz])?;
    Ok(())
}

// Undo enter_full. `leaving` = the group is about to move to another window, so
// remember to maximize again when it comes back.
fn exit_full(win: &str, leaving: bool) -> Res<()> {
    let st = read_state()?;
    let in_win: Vec<&Pane> = st.panes.iter().filter(|p| p.win == win).collect();
    let ids = opt_w(win, "@sidecar_full_panes");
    let layout = opt_w(win, "@sidecar_full_layout");
    let zoom = opt_w(win, "@sidecar_full_zoom");
    let regular: Vec<String> = ids
        .split_whitespace()
        .filter(|id| st.panes.iter().any(|p| p.id == *id))
        .map(String::from)
        .collect();
    let group: Vec<String> = in_win.iter().filter(|p| p.tag).map(|p| p.id.clone()).collect();
    if let Some(z) = in_win.iter().find(|p| p.zoomed && p.active) {
        let _ = tmux(&["resize-pane", "-Z", "-t", &z.id]); // a group pane was zoomed
    }
    for o in ["@sidecar_full", "@sidecar_full_panes", "@sidecar_full_layout", "@sidecar_full_zoom"] {
        let _ = tmux(&["set-option", "-wu", "-t", win, o]);
    }
    if regular.is_empty() || group.is_empty() {
        return Ok(());
    }
    let mut all = group.clone();
    all.extend(regular.iter().cloned());
    let exact = layout_ids(&layout).map(|l| same_set(&l, &all)).unwrap_or(false);
    let wdims = in_win.first().map(|p| (p.ww, p.wh)).unwrap_or((0, 0));
    if exact {
        // Same panes as before: put everything back exactly where it was.
        for r in &regular {
            let _ = tmux(&["join-pane", "-d", "-s", r, "-t", &group[0]]);
        }
        let mut now: Vec<String> = list_window(win)?.iter().map(|p| p.id.clone()).collect();
        if !apply_layout(win, &layout, &mut now) {
            return Err("could not restore the window layout".into());
        }
    } else {
        // The group changed meanwhile: stack the regular panes opposite the group.
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
            tree: stack(&regular, if horiz { 'v' } else { 'h' }),
        };
        restore(win, wdims, &regular, Some(&snap), Vec::new())?;
    }
    if leaving {
        let _ = tmux(&["set-option", "-w", "-t", win, "@sidecar_fresume", "1"]);
    }
    if !zoom.is_empty() && regular.contains(&zoom) {
        let _ = tmux(&["resize-pane", "-Z", "-t", &zoom]);
    }
    Ok(())
}

fn toggle_full(win: &str) -> Res<()> {
    let st = read_state()?;
    if st.panes.iter().any(|p| p.win == win && p.sfull) {
        exit_full(win, false)
    } else {
        enter_full(win)
    }
}

fn main() {
    // Usage: sidecar [WINDOW_ID] | sidecar full [WINDOW_ID]
    let args: Vec<String> = env::args().skip(1).collect();
    let full = args.first().map(|a| a == "full").unwrap_or(false);
    let win = match args.get(if full { 1 } else { 0 }) {
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
    let res = if full { toggle_full(&win) } else { sync(&win) };
    if let Err(e) = res {
        eprintln!("sidecar: {}", e);
    }
    let _ = fs::remove_dir(&lock);
}
