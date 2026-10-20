// Captures the frontmost window of a process by name: swift window-shot.swift UniveGame out.png
import CoreGraphics
import Foundation

let name = CommandLine.arguments[1], out = CommandLine.arguments[2]
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
guard let w = list.first(where: { ($0[kCGWindowOwnerName as String] as? String) == name && ($0[kCGWindowLayer as String] as? Int) == 0 }),
      let id = w[kCGWindowNumber as String] as? Int else { print("window not found"); exit(1) }
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
p.arguments = ["-x", "-o", "-l", String(id), out]
try p.run(); p.waitUntilExit()
print(out)
