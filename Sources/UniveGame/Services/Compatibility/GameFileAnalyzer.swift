import Foundation
import MacadeKit

/// Reads a game's folder without running anything: PE headers and imports, plus the files engines,
/// anti-cheats and launchers leave behind.
enum GameFileAnalyzer {
    static let maxDepth = 4
    static let maxBinaries = 160
    /// Bytes of an executable searched for DLL names it loads at run time (LoadLibrary), not via imports.
    static let stringScanLimit = 48 * 1024 * 1024

    /// Helpers that import Direct3D themselves but say nothing about the game's renderer.
    static let helperPrefixes = ["d3dx", "d3dcompiler", "xinput", "xaudio", "x3daudio", "fmod", "bink", "physx",
                                 "nvngx", "amd_", "ffx_", "steam_api", "galaxy", "eossdk", "discord", "crashpad",
                                 "unitycrashhandler", "crashreport", "vcredist", "unins", "dxsetup", "dotnet",
                                 "msvc", "vcruntime", "mfc", "concrt", "ucrtbase", "api-ms-", "d3d9on12", "gameoverlay"]

    /// Kernel anti-cheats by the files they install next to the game. All of them block Wine on macOS.
    static let kernelAntiCheats: [(name: String, markers: [String])] = [
        ("Easy Anti-Cheat", ["easyanticheat", "start_protected_game.exe", "eac_launcher"]),
        ("BattlEye", ["battleye", "beservice", "beclient"]),
        ("Riot Vanguard", ["vgk.sys", "vgc.exe"]),
        ("nProtect GameGuard", ["gameguard", "gamemon.des", "npgg"]),
        ("XIGNCODE3", ["xigncode", "x3.xem", "xhunter1"]),
        ("EA Javelin Anti-Cheat", ["eaanticheat"]),
        ("Anti-Cheat Expert", ["anticheatexpert", "ace-base", "sguard"]),
        ("NetEase Game Security", ["neacsafe"]),
        ("FACEIT", ["faceit"]),
        ("mhyprot", ["mhyprot"]),
        ("Wellbia XIGNCODE", ["wellbia"]),
    ]

    static func analyze(folders: [URL]) -> FileFindings {
        var f = FileFindings()
        var binaries: [URL] = []
        var names: [String] = []   // lowercased relative paths, for marker matching
        let fm = FileManager.default

        for root in folders {
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in walker {
                if walker.level > maxDepth { walker.skipDescendants(); continue }
                let rel = InstallScanner.relativePath(of: url, in: root).lowercased()
                names.append(rel)
                let ext = url.pathExtension.lowercased()
                if (ext == "exe" || ext == "dll"), binaries.count < maxBinaries { binaries.append(url) }
            }
        }

        detectEngine(names: names, into: &f)
        detectAntiCheat(names: names, into: &f)
        detectLauncher(names: names, into: &f)
        f.shipsDirectXHelpers = !NativeDLLPolicy.shippedHelpers(in: folders).isEmpty
        if names.contains(where: { $0.hasSuffix("app.asar") || $0.hasSuffix("nw.dll") || $0.hasSuffix("libcef.dll") }) {
            f.usesChromium = true
        }

        var stringScans = 0
        for url in binaries {
            let file = url.lastPathComponent.lowercased()
            let isHelper = helperPrefixes.contains { file.hasPrefix($0) }
            guard let image = PEImage(url: url) else { continue }
            f.analyzedFiles += 1
            let imports = image.imports
            let isDotNet = imports.contains("mscoree.dll")
            if isDotNet { f.usesDotNet = true }
            if imports.contains(where: { $0.hasPrefix("mfplat") || $0.hasPrefix("mfreadwrite") }) { f.usesMediaFoundation = true }
            if !isHelper && !isDotNet && file.hasSuffix(".exe") {
                if image.is64Bit { f.has64Bit = true } else { f.has32Bit = true }
            }
            guard !isHelper else { continue }
            f.graphics.formUnion(apis(fromImports: imports))
            // Many renderers load Direct3D dynamically; look for the DLL names in the binary itself.
            if stringScans < 12, file.hasSuffix(".exe") || file.contains("engine") || file.contains("client")
                || file.contains("render") || file == "unityplayer.dll" || file == "gameassembly.dll" {
                stringScans += 1
                f.graphics.formUnion(apis(inBinary: url))
            }
        }

        // Engine defaults fill gaps when nothing was imported directly.
        switch f.engine {
        case .unity where f.graphics.isEmpty: f.graphics.insert(.d3d11)
        case .unreal4 where f.graphics.isEmpty: f.graphics.insert(.d3d11)
        case .unreal5: f.graphics.insert(.d3d12)
        default: break
        }
        if GraphicsProbe.scan(folders.first ?? URL(fileURLWithPath: "/"), maxDepth: maxDepth).usesDirectX12 {
            f.graphics.insert(.d3d12)
        }
        return f
    }

    // MARK: Detection

    static func apis(fromImports imports: Set<String>) -> Set<GraphicsAPI> {
        var s = Set<GraphicsAPI>()
        for dll in imports {
            switch dll {
            case "ddraw.dll": s.insert(.ddraw)
            case "d3d8.dll": s.insert(.d3d8)
            case "d3d9.dll": s.insert(.d3d9)
            case "opengl32.dll": s.insert(.opengl)
            case "vulkan-1.dll": s.insert(.vulkan)
            case "d3d10.dll", "d3d10_1.dll", "d3d10core.dll": s.insert(.d3d10)
            case "d3d11.dll": s.insert(.d3d11)
            case "d3d12.dll": s.insert(.d3d12)
            default: break
            }
        }
        return s
    }

    /// Finds Direct3D/OpenGL/Vulkan DLL names (ASCII or UTF-16) inside a binary.
    static func apis(inBinary url: URL) -> Set<GraphicsAPI> {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: stringScanLimit) else { return [] }
        try? handle.close()
        let needles: [(String, GraphicsAPI)] = [("d3d9.dll", .d3d9), ("d3d8.dll", .d3d8), ("ddraw.dll", .ddraw),
                                                 ("d3d11.dll", .d3d11), ("d3d12.dll", .d3d12), ("d3d10.dll", .d3d10),
                                                 ("opengl32.dll", .opengl), ("vulkan-1.dll", .vulkan)]
        var found = Set<GraphicsAPI>()
        let lower = Data(data.map { $0 >= 65 && $0 <= 90 ? $0 + 32 : $0 })
        for (needle, api) in needles {
            let ascii = Data(needle.utf8)
            let wide = Data(needle.utf8.flatMap { [$0, 0] })
            if lower.range(of: ascii) != nil || lower.range(of: wide) != nil { found.insert(api) }
        }
        return found
    }

    static func detectEngine(names: [String], into f: inout FileFindings) {
        func has(_ p: (String) -> Bool) -> Bool { names.contains(where: p) }
        if has({ $0.hasSuffix("unityplayer.dll") || $0.hasSuffix("gameassembly.dll") || $0.hasSuffix("unityengine.dll") }) {
            f.engine = .unity
        } else if has({ $0.contains("engine/binaries/win64") || $0.hasSuffix("-shipping.exe") }) {
            // UE5 ships its own D3D12 agility runtime and Nanite/Lumen shaders under Engine/Binaries.
            let ue5 = has({ $0.contains("engine/binaries/thirdparty/d3d12") || $0.contains("/d3d12/d3d12core.dll") })
            f.engine = ue5 ? .unreal5 : .unreal4
        } else if has({ $0.hasSuffix("engine2.dll") }) {
            f.engine = .source2
        } else if has({ $0.hasSuffix("bin/engine.dll") || $0.hasSuffix("gameinfo.txt") }) {
            f.engine = .source
        } else if has({ $0.hasSuffix(".pck") }) {
            f.engine = .godot
        } else if has({ $0.hasSuffix("data.win") }) {
            f.engine = .gamemaker
        } else if has({ $0.hasSuffix("nw.dll") }) && has({ $0.hasSuffix("package.json") || $0.contains("www/") }) {
            f.engine = .rpgmakerNW
        } else if has({ $0.hasPrefix("renpy/") || $0.contains("/renpy/") }) {
            f.engine = .renpy
        } else if has({ $0.hasSuffix("app.asar") }) {
            f.engine = .electron
        } else if has({ $0.hasSuffix(".jar") }) {
            f.engine = .java
        } else if has({ $0.hasSuffix("fna.dll") || $0.hasSuffix("monogame.framework.dll") || $0.hasSuffix("microsoft.xna.framework.dll") }) {
            f.engine = .xna
        }
    }

    static func detectAntiCheat(names: [String], into f: inout FileFindings) {
        for (name, markers) in kernelAntiCheats where names.contains(where: { path in markers.contains { path.contains($0) } }) {
            f.antiCheats.append(AntiCheatFinding(name: name, kernel: true))
        }
        if names.contains(where: { $0.hasSuffix("pbsvc.exe") || $0.hasPrefix("pb/") }) {
            f.antiCheats.append(AntiCheatFinding(name: "PunkBuster", kernel: false))
        }
        // A game's own anti-cheat (e.g. "ApexGuard.dll", an "AntiCheat" folder): unknown until tested.
        // A named DLL ("ApexGuard.dll") says more than a folder called "AntiCheat".
        let dll = names.first { path in
            let file = (path as NSString).lastPathComponent
            return file.hasSuffix(".dll") && (file.contains("anticheat") || file.contains("guard"))
        }
        if f.antiCheats.isEmpty, let custom = dll ?? names.first(where: { $0.hasPrefix("anticheat/") || $0 == "anticheat" }) {
            let file = (custom as NSString).lastPathComponent
            let label = file.hasSuffix(".dll") ? (file as NSString).deletingPathExtension : "AntiCheat"
            f.antiCheats.append(AntiCheatFinding(name: label, kernel: false))
        }
    }

    static func detectLauncher(names: [String], into f: inout FileFindings) {
        if names.contains(where: { $0.contains("rockstar games") || $0.hasSuffix("playgtav.exe") || $0.contains("socialclub") }) {
            f.launcher = "Rockstar Games Launcher"
        } else if names.contains(where: { $0.contains("uplay_r1_loader") || $0.contains("upc_r2_loader") || $0.contains("uplay_r2") }) {
            f.launcher = "Ubisoft Connect"
        } else if names.contains(where: { $0.contains("link2ea") || $0.contains("eacore") || $0.hasSuffix("activation.dll") && $0.contains("origin") }) {
            f.launcher = "EA app"
        } else if names.contains(where: { $0.contains("battle.net") }) {
            f.launcher = "Battle.net"
        }
    }
}
