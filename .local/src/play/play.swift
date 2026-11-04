// play: music player for the terminal (internet radio, stream URLs, local files) using macOS AVPlayer.
//
// Usage:
//   play                 play the default station (drone)
//   play <name>          play a built-in station (see --list)
//   play <url>           play any stream URL (MP3/AAC/HLS), or a .pls/.m3u playlist link
//   play <file>          play a local audio file (exits when it ends)
//   play --list          show built-in stations
//
// Build:  swiftc -O ~/.local/src/play/play.swift -o ~/.local/bin/play
// Ctrl-C stops playback. Volume is the system volume.
//
// To add a station, add a line to `stations` below. Find stream URLs on a
// station's "listen" page; a .pls/.m3u link works too.

import AVFoundation

// (name, url, description). Order here is the order --list prints.
let stations: [(name: String, url: String, desc: String)] = [
  // Instrumental / ambient (SomaFM: listener-supported, no ads)
  ("drone",        "https://ice1.somafm.com/dronezone-128-mp3",    "SomaFM Drone Zone: atmospheric ambient, no vocals. Good default for focus."),
  ("deepspace",    "https://ice1.somafm.com/deepspaceone-128-mp3", "SomaFM Deep Space One: darker, spacier ambient."),
  ("spacestation", "https://ice1.somafm.com/spacestation-128-mp3", "SomaFM Space Station: spacey electronica/ambient, a bit more rhythm."),
  ("groove",       "https://ice1.somafm.com/groovesalad-128-mp3",  "SomaFM Groove Salad: downtempo/chill beats, mostly instrumental."),
  // Broader / with vocals
  ("paradise",     "https://stream.radioparadise.com/mellow-128",  "Radio Paradise Mellow Mix: laid-back eclectic, has vocals."),
  ("kexp",         "https://kexp.streamguys1.com/kexp128.mp3",     "KEXP Seattle: indie/alt/world, human DJs, has vocals and talking."),
  ("nts",          "https://stream-relay-geo.ntslive.net/stream",  "NTS Radio 1: live DJ shows, wide range, has talking."),
]

func fail(_ msg: String) -> Never {
  FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
  exit(1)
}

func printList() {
  print("Built-in stations (play <name>):\n")
  for s in stations { print("  " + s.name.padding(toLength: 13, withPad: " ", startingAt: 0) + s.desc) }
  print("\nOr pass any stream URL or .pls/.m3u playlist link: play <url>")
}

// A .pls/.m3u file is a list of stream URLs, not audio. Fetch it and take the first entry.
func firstStreamURL(inPlaylist url: URL) -> URL? {
  var body: String?
  let sem = DispatchSemaphore(value: 0)
  URLSession.shared.dataTask(with: url) { data, _, _ in
    body = data.flatMap { String(data: $0, encoding: .utf8) }
    sem.signal()
  }.resume()
  _ = sem.wait(timeout: .now() + 10)
  for raw in (body ?? "").split(whereSeparator: \.isNewline) {
    let line = raw.trimmingCharacters(in: .whitespaces)
    let candidate: String
    if line.lowercased().hasPrefix("file1=") { candidate = String(line.dropFirst(6)) }  // .pls
    else if line.hasPrefix("http") { candidate = line }                                   // .m3u
    else { continue }
    if let u = URL(string: candidate) { return u }
  }
  return nil
}

let arg = CommandLine.arguments.dropFirst().first ?? "drone"
if ["--list", "-l", "--help", "-h", "help"].contains(arg) { printList(); exit(0) }

var url: URL
var label = arg
if let s = stations.first(where: { $0.name == arg }) {
  url = URL(string: s.url)!
} else if arg.hasPrefix("http"), let u = URL(string: arg) {
  url = u
  let ext = u.pathExtension.lowercased()
  if ext == "pls" || ext == "m3u" {
    guard let real = firstStreamURL(inPlaylist: u) else { fail("could not find a stream URL in playlist: \(arg)") }
    url = real
    label = real.absoluteString
  }
} else if FileManager.default.fileExists(atPath: (arg as NSString).expandingTildeInPath) {
  url = URL(fileURLWithPath: (arg as NSString).expandingTildeInPath)
} else {
  fail("'\(arg)' is not a station, URL, or existing file. Run: play --list")
}

let item = AVPlayerItem(url: url)
let player = AVPlayer(playerItem: item)
player.play()
// Local files end; streams never do. Exit when a file finishes.
NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in exit(0) }
print("playing \(label), Ctrl-C to stop")
// Surface stream failures instead of sitting silent
Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
  if let e = item.error { fail("error: \(e.localizedDescription)") }
}
RunLoop.main.run()
