import Foundation
import UniveEngineKit

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
    /// Games the player chose to install or start despite the "won't run on a Mac" warning.
    var acceptedRisks: Set<String>?
    /// The PlayStation-as-Xbox setting last written to each environment (keyed by its folder).
    var appliedControllerMode: [String: Bool]?
    /// The folders that hold each game's saves, as the player confirmed them.
    var saveSources: [String: [SaveSource]]?
    /// When each game's saves were last backed up.
    var lastSaveBackup: [String: Date]?
    /// The secret each game's shortcut puts in its link (see `GameLink`).
    var shortcutKeys: [String: String]?
    /// Collections the player made: name → game ids, in the order they were added.
    var collections: [String: [String]]?
    /// When each game's cloud saves were last synced, and GOG's per-location sync times.
    var lastCloudSync: [String: Date]?
    var gogCloudTimestamps: [String: [String: String]]?
}

extension LibraryState {
    /// Every field may be missing: a file written by an older (or newer) version still loads instead of being
    /// set aside as corrupt, which would empty the library.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        customGames = try c.decodeIfPresent([CustomGame].self, forKey: .customGames) ?? []
        storeGames = try c.decodeIfPresent([Game].self, forKey: .storeGames) ?? []
        favorites = try c.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
        lastPlayed = try c.decodeIfPresent([String: Date].self, forKey: .lastPlayed) ?? [:]
        playTime = try c.decodeIfPresent([String: TimeInterval].self, forKey: .playTime) ?? [:]
        profiles = try c.decodeIfPresent([String: LaunchProfile].self, forKey: .profiles) ?? [:]
        appliedMacDriver = try c.decodeIfPresent([String: [String: Bool]].self, forKey: .appliedMacDriver)
        compat = try c.decodeIfPresent([String: CompatReport].self, forKey: .compat)
        acceptedRisks = try c.decodeIfPresent(Set<String>.self, forKey: .acceptedRisks)
        appliedControllerMode = try c.decodeIfPresent([String: Bool].self, forKey: .appliedControllerMode)
        saveSources = try c.decodeIfPresent([String: [SaveSource]].self, forKey: .saveSources)
        lastSaveBackup = try c.decodeIfPresent([String: Date].self, forKey: .lastSaveBackup)
        shortcutKeys = try c.decodeIfPresent([String: String].self, forKey: .shortcutKeys)
        collections = try c.decodeIfPresent([String: [String]].self, forKey: .collections)
        lastCloudSync = try c.decodeIfPresent([String: Date].self, forKey: .lastCloudSync)
        gogCloudTimestamps = try c.decodeIfPresent([String: [String: String]].self, forKey: .gogCloudTimestamps)
    }
}

/// UniveGame keeps its own folder (`~/Library/Application Support/UniveGame`) with the same layout
/// UniveEngine expects, so it never touches MaPC's environments.
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

    /// UniveEngine's shared folder (an existing MaPC folder counts), read-only: engines already downloaded
    /// there are reused instead of downloaded again.
    static let sharedEnginePaths = Paths()
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
        // Same path as the old cover: drop the cached image so the new one shows right away.
        ImageCache.shared.removeObject(forKey: target as NSURL)
        return target
    }

    func removeCover(of game: CustomGame) {
        guard let cover = game.coverImage, cover.path.hasPrefix(AppPaths.customArtwork.path) else { return }
        try? FileManager.default.removeItem(at: cover)
    }
}
