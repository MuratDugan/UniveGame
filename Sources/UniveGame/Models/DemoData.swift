import Foundation
import UniveEngineKit

/// Sample library for `--demo`: lets the interface be shown and tested without engines or accounts.
/// Nothing in demo mode is saved.
enum DemoData {
    private static func steamArt(_ id: String, _ file: String) -> URL? {
        URL(string: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(id)/\(file)")
    }

    private static func steam(_ id: String, _ title: String, installed: Bool, size: Int64? = nil) -> Game {
        Game(store: .steam, storeID: id, title: title, isInstalled: installed,
             installPath: installed ? URL(fileURLWithPath: "/Users/demo/Steam/\(title)") : nil,
             sizeOnDisk: size, coverURL: steamArt(id, "library_600x900.jpg"), heroURL: steamArt(id, "library_hero.jpg"))
    }

    private static func gog(_ id: String, _ steamID: String, _ title: String, installed: Bool) -> Game {
        Game(store: .gog, storeID: id, title: title, isInstalled: installed,
             coverURL: steamArt(steamID, "library_600x900.jpg"), heroURL: steamArt(steamID, "library_hero.jpg"))
    }

    static var state: LibraryState {
        var s = LibraryState()
        s.storeGames = [
            steam("1145360", "Hades", installed: true, size: 15_000_000_000),
            steam("367520", "Hollow Knight", installed: true, size: 9_000_000_000),
            steam("413150", "Stardew Valley", installed: true, size: 500_000_000),
            steam("1091500", "Cyberpunk 2077", installed: false),
            steam("1245620", "ELDEN RING", installed: false),
            steam("892970", "Valheim", installed: true, size: 1_500_000_000),
            gog("1207658924", "292030", "The Witcher 3: Wild Hunt", installed: true),
            gog("1495134320", "1086940", "Baldur's Gate 3", installed: false),
        ]
        s.customGames = [
            CustomGame(title: "Eski Oyunum", executable: URL(fileURLWithPath: "/Users/demo/Games/OldGame/game.exe")),
        ]
        let now = Date()
        s.lastPlayed = ["steam:1145360": now.addingTimeInterval(-3_600), "gog:1207658924": now.addingTimeInterval(-86_400 * 2),
                        "steam:413150": now.addingTimeInterval(-86_400 * 6)]
        s.playTime = ["steam:1145360": 3_600 * 42, "gog:1207658924": 3_600 * 118, "steam:413150": 3_600 * 76]
        s.favorites = ["steam:1145360", "gog:1207658924"]
        return s
    }

    /// Plausible reports for the demo library, built by the real scorer.
    static func compat(for item: LibraryItem) -> CompatReport {
        var files = FileFindings()
        var online = OnlineFindings()
        switch item.title {
        case "Hades", "Stardew Valley", "Hollow Knight":
            files.analyzedFiles = 12; files.has64Bit = true; files.graphics = [.d3d11]; files.engine = item.title == "Hades" ? nil : .unity
            online.steamDeckCategory = 3; online.protonTier = "platinum"; online.protonReports = 300
            online.hasMacVersion = item.title != "Hades"
        case "Valheim":
            files.analyzedFiles = 9; files.has64Bit = true; files.graphics = [.d3d11, .vulkan]; files.engine = .unity
            online.steamDeckCategory = 3; online.protonTier = "gold"; online.protonReports = 120
        case "Cyberpunk 2077":
            online.directXVersion = 12; online.steamDeckCategory = 3; online.protonTier = "gold"; online.protonReports = 900
        case "ELDEN RING":
            online.directXVersion = 12; online.antiCheats = ["Easy Anti-Cheat"]; online.antiCheatStatus = "Running"
            online.steamDeckCategory = 3; online.protonTier = "gold"; online.protonReports = 2000
        case "The Witcher 3: Wild Hunt":
            online.directXVersion = 11; online.protonTier = "platinum"; online.protonReports = 1500; online.steamDeckCategory = 3
        case "Baldur's Gate 3":
            online.directXVersion = 11; online.hasMacVersion = true; online.protonTier = "platinum"; online.protonReports = 800
        default:
            files.analyzedFiles = 4; files.has32Bit = true; files.graphics = [.d3d9]; files.usesDotNet = true
            files.antiCheats = [AntiCheatFinding(name: "ApexGuard", kernel: false)]
        }
        let hasFiles = files.analyzedFiles > 0
        return CompatibilityScorer.score(files: hasFiles ? files : nil, online: online, context: .init())
    }
}
