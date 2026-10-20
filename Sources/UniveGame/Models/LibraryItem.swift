import Foundation
import MacadeKit

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

/// Where a library entry comes from.
enum GameSource: Hashable {
    case store(StoreKind)
    case custom

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

/// One tile in the library: a store game from MacadeKit or a custom game.
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
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case title, lastPlayed, playTime, compatibility
    var id: String { rawValue }
}
