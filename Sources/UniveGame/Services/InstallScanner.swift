import Foundation

/// Finds what an installer put on the bottle's C: drive by comparing .exe files before and after,
/// and guesses which one starts the game.
struct ExeCandidate: Identifiable, Hashable {
    let url: URL
    let windowsPath: String
    let size: Int64
    let score: Int

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

struct InstallScanResult: Equatable {
    var candidates: [ExeCandidate]
    var installDirectory: URL?
    var uninstaller: URL?
}

enum InstallScanner {
    struct FileStamp: Equatable { let size: Int64; let modified: Date }
    typealias Snapshot = [String: FileStamp]   // keyed by absolute path

    /// Helpers that ship next to games but never start them.
    static let excludedNames = [
        "unins", "uninstall", "setup", "install", "redist", "vcredist", "vc_redist", "dxsetup", "dxwebsetup",
        "crashreport", "crashhandler", "crashpad", "unitycrashhandler", "cefsharp.browsersubprocess",
        "qtwebengineprocess", "notification_helper", "prereq", "dotnet", "ue4prereqsetup", "easyanticheat_setup",
    ]

    /// Folders Windows itself owns; installers don't put games there.
    static let systemFolders: Set<String> = ["windows", "programdata/microsoft", "program files/common files",
                                              "program files (x86)/common files", "program files/internet explorer",
                                              "program files (x86)/internet explorer", "program files/windows nt",
                                              "program files (x86)/windows nt", "program files/windows media player",
                                              "program files (x86)/windows media player"]

    static func snapshot(driveC: URL) -> Snapshot {
        let driveC = driveC.resolvingSymlinksInPath() // the enumerator doesn't descend into a symlinked root
        var result: Snapshot = [:]
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        guard let walker = FileManager.default.enumerator(at: driveC, includingPropertiesForKeys: keys,
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [:] }
        for case let url as URL in walker {
            let relative = relativePath(of: url, in: driveC).lowercased()
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                if systemFolders.contains(relative) || relative.hasSuffix("/temp") { walker.skipDescendants() }
                continue
            }
            guard url.pathExtension.lowercased() == "exe" else { continue }
            result[url.resolvingSymlinksInPath().path] = FileStamp(size: Int64(values?.fileSize ?? 0),
                                                            modified: values?.contentModificationDate ?? .distantPast)
        }
        return result
    }

    /// New or changed executables, ranked best first. Empty when the installer added nothing: programs
    /// that were already there (an earlier game in the same environment) are never offered as its result.
    static func scan(before: Snapshot, after: Snapshot, driveC: URL) -> InstallScanResult {
        // Compare real paths: /tmp vs /private/tmp (or a symlinked home) must not split one folder in two.
        let driveC = driveC.resolvingSymlinksInPath()
        let changed = after.filter { before[$0.key] != $0.value }.map(\.key)
        let urls = changed.map { URL(fileURLWithPath: $0) }
        let root = installRoot(of: urls, driveC: driveC)

        let candidates = urls.map { url in
            ExeCandidate(url: url, windowsPath: windowsPath(of: url, driveC: driveC),
                         size: after[url.path]?.size ?? 0, score: score(url, root: root, size: after[url.path]?.size ?? 0))
        }
        .filter { $0.score > -100 }
        .sorted { $0.score != $1.score ? $0.score > $1.score : $0.windowsPath < $1.windowsPath }

        let uninstaller = urls.first { url in
            url.lastPathComponent.lowercased().hasPrefix("unins") && (root.map { url.path.hasPrefix($0.path) } ?? true)
        }
        return InstallScanResult(candidates: candidates, installDirectory: root, uninstaller: uninstaller)
    }

    /// The folder most new programs live under: `C:\Games\S2Rebirth`, `C:\Program Files\Studio\Game`…
    static func installRoot(of urls: [URL], driveC: URL) -> URL? {
        let containers: Set<String> = ["games", "program files", "program files (x86)", "users"]
        var counts: [String: Int] = [:]
        for url in urls {
            var parts = relativePath(of: url, in: driveC).split(separator: "/").map(String.init).dropLast()
            guard !parts.isEmpty else { continue }
            var key = [parts.removeFirst()]
            if containers.contains(key[0].lowercased()), let next = parts.first { key.append(next) }
            counts[key.joined(separator: "/"), default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }) else { return nil }
        return driveC.appendingPathComponent(best.key, isDirectory: true)
    }

    static func score(_ url: URL, root: URL?, size: Int64) -> Int {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        if excludedNames.contains(where: { name.contains($0) }) { return -1000 }
        var score = 0
        // A launcher usually has to start the game (it passes sign-in or update checks), so it wins.
        if name.contains("launcher") { score += 70 }
        if let root {
            guard url.path.hasPrefix(root.path) else { return score - 40 }
            let folder = normalized(root.lastPathComponent)
            let file = normalized(name)
            if !folder.isEmpty, file.contains(folder) || folder.contains(file) { score += 40 }
            let depth = url.deletingLastPathComponent().pathComponents.count - root.pathComponents.count
            score += max(0, 20 - depth * 8)
        }
        if size > 0 { score += min(20, Int(log2(Double(size) / 1_000_000 + 1) * 3)) } // bigger binaries lean game
        return score
    }

    static func windowsPath(of url: URL, driveC: URL) -> String {
        "C:\\" + relativePath(of: url, in: driveC).replacingOccurrences(of: "/", with: "\\")
    }

    static func relativePath(of url: URL, in base: URL) -> String {
        let path = url.resolvingSymlinksInPath().path, basePath = base.resolvingSymlinksInPath().path
        guard path.hasPrefix(basePath) else { return path }
        return String(path.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// "S2_Rebirth-Launcher" → "s2rebirthlauncher", for loose name matching.
    static func normalized(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// "S2Rebirth" → "S2 Rebirth": a readable default title from a folder name.
    static func displayTitle(fromFolder folder: String) -> String {
        var out = ""
        let chars = Array(folder.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " "))
        for (i, c) in chars.enumerated() {
            if i > 0, c.isUppercase, chars[i - 1].isLowercase || chars[i - 1].isNumber, chars[i - 1] != " " { out.append(" ") }
            out.append(c)
        }
        return out.split(separator: " ").joined(separator: " ")
    }
}
