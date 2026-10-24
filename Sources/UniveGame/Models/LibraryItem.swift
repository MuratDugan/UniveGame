import Foundation
import UniveEngineKit

/// A Windows program the user added by hand (not from a store).
struct CustomGame: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var executable: URL
    var arguments: [String] = []
    /// Copied into the app's own artwork folder, so the original image can be moved or deleted.
    var coverImage: URL?
    /// Wide artwork for the game page (found online or chosen).
    var heroImage: URL?
    var addedAt: Date = Date()
    var profile = LaunchProfile()
    /// Set when UniveGame ran the game's installer: the folder on the environment's C: drive and its uninstaller.
    var installDirectory: URL?
    var uninstaller: URL?
    /// Extra Wine DLL overrides for this game only, e.g. "d3d9=n,b" for a DirectX 9 → 11 wrapper.
    var dllOverrides: [String]?

    var wasInstalledByApp: Bool { installDirectory != nil }

    var workingDirectory: URL { executable.deletingLastPathComponent() }
    var executableExists: Bool { FileManager.default.fileExists(atPath: executable.path) }
}

extension CustomGame {
    /// Fields added later may be missing from older library files.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        executable = try c.decode(URL.self, forKey: .executable)
        arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        coverImage = try c.decodeIfPresent(URL.self, forKey: .coverImage)
        heroImage = try c.decodeIfPresent(URL.self, forKey: .heroImage)
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        profile = try c.decodeIfPresent(LaunchProfile.self, forKey: .profile) ?? LaunchProfile()
        installDirectory = try c.decodeIfPresent(URL.self, forKey: .installDirectory)
        uninstaller = try c.decodeIfPresent(URL.self, forKey: .uninstaller)
        dllOverrides = try c.decodeIfPresent([String].self, forKey: .dllOverrides)
    }
}

/// Where a library entry comes from.
enum GameSource: Hashable {
    case store(StoreKind)
    case custom

    /// Stable name for settings ("steam", "epic"…, "custom").
    var key: String {
        switch self {
        case .store(let kind): kind.rawValue
        case .custom: "custom"
        }
    }

    var displayName: String {
        switch self {
        case .store(let kind): kind.displayName
        case .custom: "Windows (.exe)"
        }
    }

    /// SF Symbol shown on cards and in the sidebar. Store logos are trademarks, so we don't draw them.
    var symbol: String {
        switch self {
        case .store(.steam): "cloud.fill"
        case .store(.epic): "bolt.shield.fill"
        case .store(.gog): "circle.hexagongrid.fill"
        case .store(.ubisoft): "hurricane"
        case .store(.ea): "e.circle.fill"
        case .custom: "square.and.arrow.down.on.square.fill"
        }
    }
}

/// One tile in the library: a store game from UniveEngine or a custom game.
struct LibraryItem: Identifiable, Hashable {
    enum Backing: Hashable {
        case store(Game)
        case custom(CustomGame)
    }

    let backing: Backing
    var isFavorite = false
    var lastPlayed: Date?
    var playTime: TimeInterval = 0

    var id: String {
        switch backing {
        case .store(let g): g.id
        case .custom(let c): "custom:\(c.id.uuidString)"
        }
    }

    var title: String {
        switch backing {
        case .store(let g): g.title
        case .custom(let c): c.title
        }
    }

    var source: GameSource {
        switch backing {
        case .store(let g): .store(g.store)
        case .custom: .custom
        }
    }

    var isInstalled: Bool {
        switch backing {
        case .store(let g): g.isInstalled
        case .custom(let c): c.executableExists
        }
    }

    var coverURL: URL? {
        switch backing {
        case .store(let g): g.coverURL
        case .custom(let c): c.coverImage
        }
    }

    var heroURL: URL? {
        switch backing {
        case .store(let g): g.heroURL ?? g.coverURL
        case .custom(let c): c.heroImage ?? c.coverImage
        }
    }

    var installPath: URL? {
        switch backing {
        case .store(let g): g.installPath
        case .custom(let c): c.executable
        }
    }

    var sizeOnDisk: Int64? {
        if case .store(let g) = backing { return g.sizeOnDisk }
        return nil
    }

    var installProgress: Double? {
        if case .store(let g) = backing { return g.installProgress }
        return nil
    }

    var customGame: CustomGame? {
        if case .custom(let c) = backing { return c }
        return nil
    }
}

enum LibraryFilter: Hashable {
    case all, installed, favorites, recent
    case source(GameSource)
    /// A collection the player made.
    case collection(String)
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case title, lastPlayed, playTime, compatibility
    var id: String { rawValue }
}
