import Foundation

/// Launchers whose window is a Chromium (CEF) page. Wine on macOS can't hand Chromium's GPU drawing to the
/// window, so it stays black; drawing in software fixes it (HoYoPlay's log shows ANGLE failing to share its
/// swap chain). These launchers pass their own command line on to Chromium, so the fix is a few arguments:
/// nothing in their folder is changed.
///
/// They also draw their own title bar inside the window. Wine gives such a window a Mac title bar in place of
/// the Windows one it expects, which hides the launcher's own (settings, minimize, close), even in full screen.
/// Wine's per-program `Decorated` setting turns that off for the launcher's process only.
enum ChromiumLaunchers {
    static let softwareRendering = ["--disable-gpu", "--disable-gpu-compositing", "--in-process-gpu"]

    /// Folder and file names (lowercased) of launchers known to take the arguments, and the programs among them
    /// that draw their own title bar.
    static let known: [(folder: String, executables: Set<String>, selfDrawn: [String])] = [
        ("hoyoplay", ["launcher.exe", "hyp.exe"], ["HYP.exe"]),
    ]

    private static func launcher(for executable: URL) -> (folder: String, executables: Set<String>, selfDrawn: [String])? {
        let file = executable.lastPathComponent.lowercased()
        let folders = executable.deletingLastPathComponent().pathComponents.suffix(2).map { $0.lowercased() }
        return known.first { folders.contains($0.folder) && $0.executables.contains(file) }
    }

    /// `arguments` plus software rendering when `executable` (a Mac path) is one of those launchers.
    static func arguments(for executable: URL, _ arguments: [String]) -> [String] {
        guard launcher(for: executable) != nil else { return arguments }
        return arguments + softwareRendering.filter { !arguments.contains($0) }
    }

    /// `wine reg` commands that keep Mac title bars off the launcher's self-drawn windows (none for other programs).
    static func registryCommands(for executable: URL) -> [[String]] {
        (launcher(for: executable)?.selfDrawn ?? []).map { program in
            ["reg", "add", "HKCU\\Software\\Wine\\AppDefaults\\\(program)\\X11 Driver", "/v", "Decorated", "/t", "REG_SZ", "/d", "N", "/f"]
        }
    }
}
