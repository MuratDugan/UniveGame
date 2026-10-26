import Foundation

/// Launchers whose window is a Chromium (CEF) page. Wine on macOS can't hand Chromium's GPU drawing to the
/// window, so it stays black; drawing in software fixes it (HoYoPlay's log shows ANGLE failing to share its
/// swap chain). These launchers pass their own command line on to Chromium, so the fix is a few arguments:
/// nothing in their folder is changed.
enum ChromiumLaunchers {
    static let softwareRendering = ["--disable-gpu", "--disable-gpu-compositing", "--in-process-gpu"]

    /// Folder and file names (lowercased) of launchers known to take the arguments.
    static let known: [(folder: String, executables: Set<String>)] = [
        ("hoyoplay", ["launcher.exe", "hyp.exe"]),
    ]

    /// `arguments` plus software rendering when `executable` (a Mac path) is one of those launchers.
    static func arguments(for executable: URL, _ arguments: [String]) -> [String] {
        let file = executable.lastPathComponent.lowercased()
        let folders = executable.deletingLastPathComponent().pathComponents.suffix(2).map { $0.lowercased() }
        guard known.contains(where: { folders.contains($0.folder) && $0.executables.contains(file) }) else { return arguments }
        return arguments + softwareRendering.filter { !arguments.contains($0) }
    }
}
