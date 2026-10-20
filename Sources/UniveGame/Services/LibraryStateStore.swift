import Foundation
import MacadeKit

/// Everything UniveGame saves on its own: custom games and per-game library data.
struct LibraryState: Codable, Equatable {
    var customGames: [CustomGame] = []
    var storeGames: [Game] = []
    var favorites: Set<String> = []
    var lastPlayed: [String: Date] = [:]
    var playTime: [String: TimeInterval] = [:]
    var profiles: [String: LaunchProfile] = [:]
    /// Mac driver options last written to each environment (keyed by its folder), so they're set only on change.
    var appliedMacDriver: [String: [String: Bool]]?
    /// Compatibility analyses by library id.
    var compat: [String: CompatReport]?
}

/// UniveGame keeps its own folder (`~/Library/Application Support/UniveGame`) with the same layout
/// MacadeKit expects, so it never touches MaPC's environments.
enum AppPaths {
    static let home: URL = {
        let env = ProcessInfo.processInfo.environment
        if let override = env["UNIVEGAME_HOME"] ?? env["ARCADIA_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let home = support.appendingPathComponent("UniveGame", isDirectory: true)
        migrateLegacyFolder(from: support.appendingPathComponent("Arcadia", isDirectory: true), to: home)
        return home
    }()

    /// The app used to be called Arcadia. Moves its folder (bottles, accounts, library) once and points the
    /// saved file paths at the new place. Wine environments only use relative links, so they move cleanly.
    static func migrateLegacyFolder(from old: URL, to new: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { return }
        do { try fm.moveItem(at: old, to: new) } catch { return }
        let legacyState = new.appendingPathComponent("Arcadia.json")
        guard var text = try? String(contentsOf: legacyState, encoding: .utf8) else { return }
        for (from, to) in [("Application Support/Arcadia/", "Application Support/UniveGame/"),
                           ("Application%20Support/Arcadia/", "Application%20Support/UniveGame/"),
                           (#"Application Support\/Arcadia\/"#, #"Application Support\/UniveGame\/"#),
                           (#"Application%20Support\/Arcadia\/"#, #"Application%20Support\/UniveGame\/"#)] {
            text = text.replacingOccurrences(of: from, with: to)
        }
        if (try? text.write(to: new.appendingPathComponent("UniveGame.json"), atomically: true, encoding: .utf8)) != nil {
            try? fm.removeItem(at: legacyState)
        }
    }

    static let paths = Paths(home: home)
    static var stateFile: URL { home.appendingPathComponent("UniveGame.json") }
    static var customArtwork: URL { home.appendingPathComponent("Artwork/custom", isDirectory: true) }

    /// MaPC's folder, read-only: lets UniveGame reuse engines MaPC already downloaded.
    static let mapcPaths = Paths()
}

struct LibraryStateStore {
    private let store = JSONStore<LibraryState>(url: AppPaths.stateFile)

    func load() -> LibraryState { store.load(default: LibraryState()) }

    func save(_ state: LibraryState) {
        try? FileManager.default.createDirectory(at: AppPaths.home, withIntermediateDirectories: true)
        try? store.save(state)
    }

    /// Copies a chosen cover image next to the library so the original can go away.
    func importCover(from source: URL, for id: UUID) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: AppPaths.customArtwork, withIntermediateDirectories: true)
        let target = AppPaths.customArtwork.appendingPathComponent("\(id.uuidString).\(source.pathExtension.lowercased())")
        try? fm.removeItem(at: target)
        try fm.copyItem(at: source, to: target)
        return target
    }

    func removeCover(of game: CustomGame) {
        guard let cover = game.coverImage, cover.path.hasPrefix(AppPaths.customArtwork.path) else { return }
        try? FileManager.default.removeItem(at: cover)
    }
}
