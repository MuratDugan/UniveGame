import Foundation

/// Turns evidence into a 0–100 score for *this* setup: Wine on macOS with WineD3D (OpenGL), DXVK for
/// Direct3D 10/11, and D3DMetal for 64-bit Direct3D 12 when the user installed it. The weights follow what
/// actually limits games here, not on Linux: kernel anti-cheat never runs, Direct3D 9 goes through Apple's
/// frozen OpenGL, Vulkan lacks geometry shaders on Metal.
enum CompatibilityScorer {
    struct Context {
        var d3dMetalAvailable = false
        var storeLauncher: String?       // Ubisoft Connect / EA app for those stores
        var knownIssue: String?
    }

    static let baseline = 70
    /// Bump when the rules change; stored reports are then re-scored from their saved evidence.
    static let version = 6

    /// Anti-cheats that don't stop a Wine game on macOS (server-side or user-mode).
    static let harmlessAntiCheats: Set<String> = ["vac", "valve anti-cheat", "fairfight", "punkbuster"]

    /// Kernel drivers, or anti-cheats whose Linux support needs their own Linux runtime (EAC, BattlEye).
    /// None of them run under Wine on macOS, even when "Supported" on Linux.
    static let blockingAntiCheats: Set<String> = [
        "easy anti-cheat", "battleye", "riot vanguard", "vanguard", "nprotect gameguard", "xigncode3", "x-trap",
        "anti-cheat expert", "netease game security", "ea anticheat", "ea javelin anti-cheat", "faceit", "hyperion",
        "denuvo anti-cheat", "zakynthos", "uncheater", "nexon game security", "mhyprot", "ricochet", "arkos", "sard",
    ]

    static func score(files: FileFindings?, online: OnlineFindings?, context: Context, now: Date = Date()) -> CompatReport {
        var factors: [CompatFactor] = []
        var score = baseline
        var blocked = false
        func add(_ kind: CompatFactor.Kind, _ key: String, _ args: [String] = [], _ impact: Int = 0) {
            factors.append(CompatFactor(kind: kind, key: key, args: args, impact: impact))
            score += impact
            if kind == .blocker { blocked = true }
        }

        // 1. Things that stop a game outright.
        if let issue = context.knownIssue { add(.blocker, "compat.f.knownIssue", [issue]) }
        for ac in files?.antiCheats ?? [] where ac.kernel { add(.blocker, "compat.f.kernelAC", [ac.name]) }
        if let online {
            let status = online.antiCheatStatus ?? ""
            let worksOnLinux = status == "Supported" || status == "Running"
            let relevant = online.antiCheats.filter { !harmlessAntiCheats.contains($0.lowercased()) }
            let runtimeBound = relevant.filter { blockingAntiCheats.contains($0.lowercased()) }
            // User-mode/custom anti-cheats that run inside Wine on Linux should run inside Wine on macOS too.
            let userMode = relevant.filter { !blockingAntiCheats.contains($0.lowercased()) }
            let alreadyFound = Set((files?.antiCheats ?? []).filter(\.kernel).map { $0.name.lowercased() })
            if !runtimeBound.isEmpty, !runtimeBound.allSatisfy({ alreadyFound.contains($0.lowercased()) }) {
                add(.blocker, worksOnLinux ? "compat.f.acLinuxOnly" : "compat.f.onlineAC", [runtimeBound.joined(separator: ", ")])
            } else if !userMode.isEmpty {
                if worksOnLinux { add(.negative, "compat.f.userAC", [userMode.joined(separator: ", ")], -6) }
                else { add(.blocker, "compat.f.onlineAC", [userMode.joined(separator: ", ")]) }
            } else if online.steamDeckAntiCheatIssue && !factors.contains(where: { $0.kind == .blocker }) {
                add(.blocker, "compat.f.deckAC")
            }
            if online.antiCheats.contains(where: { $0.lowercased() == "punkbuster" }) { add(.negative, "compat.f.punkbuster", [], -5) }
        }

        // 2. Graphics: the biggest factor for speed on a Mac.
        // Unknown (nil) unless a game binary was actually classified: no files, or only .NET/helper programs,
        // mustn't read as 32-bit and cost a DirectX 12 game D3DMetal.
        let is64: Bool? = files.flatMap { $0.has64Bit || $0.has32Bit ? $0.has64Bit : nil }
        var apis = files?.graphics ?? []
        if apis.isEmpty, let dx = online?.directXVersion {
            switch dx {
            case 12: apis = [.d3d12]
            case 11: apis = [.d3d11]
            case 10: apis = [.d3d10]
            case 9: apis = [.d3d9]
            default: apis = [.d3d8]
            }
        }
        let guessedDX11 = apis.isEmpty && online?.gpuSuggestsDX11 == true
        let path = guessedDX11 ? GraphicsAPI.d3d11 : bestPath(apis, is64: is64 ?? true, d3dMetal: context.d3dMetalAvailable)
        switch path {
        case .d3d11? where guessedDX11: add(.positive, "compat.f.dx11guess", [], 6)
        case .d3d11?: add(.positive, "compat.f.dx11", [], 12)
        case .d3d10?: add(.positive, "compat.f.dx10", [], 8)
        case .d3d12?:
            if context.d3dMetalAvailable && is64 != false { add(.positive, "compat.f.dx12metal", [], 4) }
            else if is64 == false { add(.negative, "compat.f.dx12x86", [], -35) }
            else { add(.negative, "compat.f.dx12noMetal", [], -30) }
        case .d3d9?:
            let old = (online?.releaseYear ?? 9999) < 2008
            add(.negative, old ? "compat.f.dx9old" : "compat.f.dx9", [], old ? -6 : -14)
        case .d3d8?, .ddraw?: add(.negative, "compat.f.dxOld", [], -6)
        case .opengl?: add(.negative, "compat.f.opengl", [], -8)
        case .vulkan?: add(.negative, "compat.f.vulkan", [], -15)
        case nil: add(.info, "compat.f.gfxUnknown")
        }

        // 3. The game's own build.
        if let files {
            if files.has32Bit && !files.has64Bit { add(.negative, "compat.f.32bit", [], -5) }
            if let engine = files.engine {
                let (impact, key): (Int, String) = switch engine {
                case .unity: (4, "compat.f.engineGood")
                case .godot, .gamemaker, .renpy: (4, "compat.f.engineLight")
                case .unreal5: (-8, "compat.f.engineHeavy")
                case .rpgmakerNW, .electron: (-6, "compat.f.engineChromium")
                default: (0, "compat.f.engine")
                }
                add(impact > 0 ? .positive : (impact < 0 ? .negative : .info), key, [engine.displayName], impact)
            } else if files.usesChromium {
                add(.negative, "compat.f.chromium", [], -5)
            }
            for ac in files.antiCheats where !ac.kernel {
                if ac.name == "PunkBuster" { add(.negative, "compat.f.punkbuster", [], -5) }
                else { add(.negative, "compat.f.customAC", [ac.name], -12) }
            }
            if files.usesDotNet { add(.negative, "compat.f.dotnet", [], -3) }
            if files.usesMediaFoundation { add(.negative, "compat.f.mediaFoundation", [], -6) }
            if let launcher = files.launcher { add(.negative, "compat.f.launcher", [launcher], launcher.hasPrefix("Rockstar") ? -15 : -10) }
            if files.shipsDirectXHelpers { add(.positive, "compat.f.dxHelpers", [], 2) }
        }
        if files?.launcher == nil, let launcher = context.storeLauncher ?? online?.thirdPartyLauncher {
            add(.negative, "compat.f.launcher", [launcher], launcher.hasPrefix("Rockstar") ? -15 : -10)
        }

        // 4. What others saw (Linux/Proton results transfer partly: same Wine, different graphics stack).
        if let online {
            switch online.steamDeckCategory {
            case 3?: add(.positive, "compat.f.deckVerified", [], 12)
            case 2?: add(.positive, "compat.f.deckPlayable", [], 5)
            case 1? where !online.steamDeckAntiCheatIssue: add(.negative, "compat.f.deckUnsupported", [], -8)
            default: break
            }
            if let tier = online.protonTier?.lowercased() {
                let weak = online.protonConfidence == "low" || (online.protonReports ?? 0) < 5
                let base: Int = switch tier {
                case "platinum": 10
                case "gold": 6
                case "silver": 0
                case "bronze": -8
                case "borked": -30
                default: 0
                }
                let impact = weak ? base / 2 : base
                add(impact > 0 ? .positive : (impact < 0 ? .negative : .info), "compat.f.proton",
                    [tier.capitalized, String(online.protonReports ?? 0)], impact)
            }
            if online.hasMacVersion { add(.info, "compat.f.macVersion") }
        }

        let evidence = (files?.analyzedFiles ?? 0 > 0 ? 1 : 0)
            + (online?.steamDeckCategory != nil ? 1 : 0) + (online?.protonTier != nil ? 1 : 0)
            + (online?.directXVersion != nil || !(files?.graphics.isEmpty ?? true) ? 1 : 0)
        if evidence == 0 { add(.info, "compat.f.noData") }

        score = max(0, min(100, score))
        // Without knowing the renderer we can't promise the fast path.
        if path == nil { score = min(score, 74) }
        if blocked { score = min(score, 10) }
        let confidence: CompatConfidence = evidence >= 3 ? .high : (evidence >= 2 ? .medium : .low)
        // Strongest reasons first: blockers, then by size of impact.
        let order: [CompatFactor.Kind: Int] = [.blocker: 0, .negative: 1, .positive: 2, .info: 3]
        factors.sort { (order[$0.kind]!, -abs($0.impact)) < (order[$1.kind]!, -abs($1.impact)) }

        var sources: [String] = []
        if files?.analyzedFiles ?? 0 > 0 { sources.append("files") }
        if online?.steamDeckCategory != nil || online?.directXVersion != nil { sources.append("steam") }
        if online?.protonTier != nil { sources.append("protondb") }
        if online?.antiCheatStatus != nil { sources.append("awacy") }

        let tier: CompatTier = blocked ? .broken : (evidence == 0 ? .unknown : CompatTier(score: score))
        return CompatReport(score: score, tier: tier, confidence: confidence, factors: factors, analyzedAt: now,
                            hasMacVersion: online?.hasMacVersion ?? false, sources: sources,
                            files: files, online: online, version: version)
    }

    /// The renderer UniveGame would end up using: games that support several APIs run on the best one here.
    static func bestPath(_ apis: Set<GraphicsAPI>, is64: Bool, d3dMetal: Bool) -> GraphicsAPI? {
        if apis.contains(.d3d11) { return .d3d11 }
        if apis.contains(.d3d12) && d3dMetal && is64 { return .d3d12 }
        if apis.contains(.d3d10) { return .d3d10 }
        if apis.contains(.d3d12) { return .d3d12 }
        if apis.contains(.d3d9) { return .d3d9 }
        if apis.contains(.opengl) { return .opengl }
        if apis.contains(.vulkan) { return .vulkan }
        if apis.contains(.d3d8) { return .d3d8 }
        if apis.contains(.ddraw) { return .ddraw }
        return nil
    }
}
