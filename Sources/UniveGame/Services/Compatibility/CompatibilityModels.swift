import Foundation

/// How well a Windows game is expected to run through UniveGame on this Mac.
enum CompatTier: String, Codable, CaseIterable {
    case excellent, good, playable, poor, broken
    /// Not enough evidence to say.
    case unknown

    init(score: Int) {
        switch score {
        case 80...: self = .excellent
        case 65..<80: self = .good
        case 45..<65: self = .playable
        case 25..<45: self = .poor
        default: self = .broken
        }
    }

    /// Rank for sorting (higher plays better).
    var rank: Int { CompatTier.allCases.count - (CompatTier.allCases.firstIndex(of: self) ?? 0) }
}

enum CompatConfidence: String, Codable { case low, medium, high }

/// One reason behind a score. `key` is a localization key; `args` fill its placeholders.
struct CompatFactor: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case positive, negative, blocker, info }
    var kind: Kind
    var key: String
    var args: [String] = []
    /// Points this factor added or removed (0 for information).
    var impact: Int = 0

    var id: String { key + args.joined(separator: "|") }

    /// The game runs, but playing it online this way can cost the account (shown before it starts, like a blocker).
    static let accountRiskKey = "compat.f.accountRisk"
}

struct CompatReport: Codable, Equatable {
    var score: Int
    var tier: CompatTier
    var confidence: CompatConfidence
    var factors: [CompatFactor]
    var analyzedAt: Date
    /// The game also has a macOS version (better played through Steam/Epic for Mac).
    var hasMacVersion: Bool = false
    /// Where the evidence came from ("files", "steam", "protondb", "awacy"), for the footnote.
    var sources: [String] = []
    /// The evidence, kept so scores can be recomputed locally when the rules improve.
    var files: FileFindings?
    var online: OnlineFindings?
    var version: Int?
}

// MARK: Evidence

enum GraphicsAPI: String, Codable, CaseIterable, Comparable {
    case ddraw, d3d8, d3d9, opengl, vulkan, d3d10, d3d11, d3d12

    static func < (a: GraphicsAPI, b: GraphicsAPI) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }

    var displayName: String {
        switch self {
        case .ddraw: "DirectDraw"
        case .d3d8: "DirectX 8"
        case .d3d9: "DirectX 9"
        case .opengl: "OpenGL"
        case .vulkan: "Vulkan"
        case .d3d10: "DirectX 10"
        case .d3d11: "DirectX 11"
        case .d3d12: "DirectX 12"
        }
    }
}

enum GameEngineKind: String, Codable {
    case unity, unreal4, unreal5, source, source2, godot, gamemaker, rpgmakerNW, renpy, electron, java, xna

    var displayName: String {
        switch self {
        case .unity: "Unity"
        case .unreal4: "Unreal Engine 4"
        case .unreal5: "Unreal Engine 5"
        case .source: "Source"
        case .source2: "Source 2"
        case .godot: "Godot"
        case .gamemaker: "GameMaker"
        case .rpgmakerNW: "RPG Maker (NW.js)"
        case .renpy: "Ren'Py"
        case .electron: "Electron"
        case .java: "Java"
        case .xna: "XNA / FNA / MonoGame"
        }
    }
}

struct AntiCheatFinding: Codable, Hashable {
    var name: String
    /// Kernel-level anti-cheat never runs under Wine on macOS.
    var kernel: Bool
}

/// What the game's own files say. Produced by `GameFileAnalyzer`.
struct FileFindings: Codable, Equatable {
    var analyzedFiles = 0
    var has64Bit = false
    var has32Bit = false
    var graphics: Set<GraphicsAPI> = []
    var engine: GameEngineKind?
    var antiCheats: [AntiCheatFinding] = []
    var usesDotNet = false
    var usesMediaFoundation = false
    var usesChromium = false
    var launcher: String?
    var shipsDirectXHelpers = false

    /// The architecture the game itself runs as (64-bit wins when both exist).
    var is64Bit: Bool { has64Bit }
}

extension FileFindings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        analyzedFiles = try c.decodeIfPresent(Int.self, forKey: .analyzedFiles) ?? 0
        has64Bit = try c.decodeIfPresent(Bool.self, forKey: .has64Bit) ?? false
        has32Bit = try c.decodeIfPresent(Bool.self, forKey: .has32Bit) ?? false
        // An API or engine name a later version added shouldn't make the whole report unreadable.
        graphics = Set((try? c.decodeIfPresent([String].self, forKey: .graphics))??.compactMap(GraphicsAPI.init(rawValue:)) ?? [])
        engine = (try? c.decodeIfPresent(String.self, forKey: .engine))?.flatMap(GameEngineKind.init(rawValue:))
        antiCheats = try c.decodeIfPresent([AntiCheatFinding].self, forKey: .antiCheats) ?? []
        usesDotNet = try c.decodeIfPresent(Bool.self, forKey: .usesDotNet) ?? false
        usesMediaFoundation = try c.decodeIfPresent(Bool.self, forKey: .usesMediaFoundation) ?? false
        usesChromium = try c.decodeIfPresent(Bool.self, forKey: .usesChromium) ?? false
        launcher = try c.decodeIfPresent(String.self, forKey: .launcher)
        shipsDirectXHelpers = try c.decodeIfPresent(Bool.self, forKey: .shipsDirectXHelpers) ?? false
    }
}

/// What stores and community databases say. Produced by `CompatibilitySignals`.
struct OnlineFindings: Codable, Equatable {
    var steamDeckCategory: Int?          // 1 unsupported, 2 playable, 3 verified
    var steamDeckAntiCheatIssue = false
    var protonTier: String?              // platinum, gold, silver, bronze, borked
    var protonConfidence: String?
    var protonReports: Int?
    var antiCheatStatus: String?         // AreWeAntiCheatYet: Supported, Running, Planned, Broken, Denied
    var antiCheats: [String] = []
    var directXVersion: Int?             // from the store's system requirements
    var hasMacVersion = false
    var releaseYear: Int?
    /// The minimum GPU in the requirements is a DirectX 11-class card (no DirectX version written).
    var gpuSuggestsDX11: Bool?
    /// Another company's launcher the store says the game needs (Ubisoft Connect, EA app, Rockstar).
    var thirdPartyLauncher: String?
    var steamAppID: String?
}

// Stored reports may predate a field: decode what's there, default the rest (a failure here would lose the library).
extension OnlineFindings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        steamDeckCategory = try c.decodeIfPresent(Int.self, forKey: .steamDeckCategory)
        steamDeckAntiCheatIssue = try c.decodeIfPresent(Bool.self, forKey: .steamDeckAntiCheatIssue) ?? false
        protonTier = try c.decodeIfPresent(String.self, forKey: .protonTier)
        protonConfidence = try c.decodeIfPresent(String.self, forKey: .protonConfidence)
        protonReports = try c.decodeIfPresent(Int.self, forKey: .protonReports)
        antiCheatStatus = try c.decodeIfPresent(String.self, forKey: .antiCheatStatus)
        antiCheats = try c.decodeIfPresent([String].self, forKey: .antiCheats) ?? []
        directXVersion = try c.decodeIfPresent(Int.self, forKey: .directXVersion)
        hasMacVersion = try c.decodeIfPresent(Bool.self, forKey: .hasMacVersion) ?? false
        releaseYear = try c.decodeIfPresent(Int.self, forKey: .releaseYear)
        gpuSuggestsDX11 = try c.decodeIfPresent(Bool.self, forKey: .gpuSuggestsDX11)
        thirdPartyLauncher = try c.decodeIfPresent(String.self, forKey: .thirdPartyLauncher)
        steamAppID = try c.decodeIfPresent(String.self, forKey: .steamAppID)
    }
}
