import XCTest
@testable import UniveGame

final class CompatibilityScorerTests: XCTestCase {
    func testKernelAntiCheatBlocks() {
        var f = FileFindings(); f.analyzedFiles = 5; f.has64Bit = true; f.graphics = [.d3d11]
        f.antiCheats = [AntiCheatFinding(name: "Easy Anti-Cheat", kernel: true)]
        let r = CompatibilityScorer.score(files: f, online: nil, context: .init())
        XCTAssertEqual(r.tier, .broken)
        XCTAssertLessThanOrEqual(r.score, 10)
        XCTAssertEqual(r.factors.first?.kind, .blocker)
    }

    func testLinuxSupportedAntiCheatStillBlocksOnMac() {
        var o = OnlineFindings(); o.antiCheats = ["Easy Anti-Cheat"]; o.antiCheatStatus = "Supported"; o.directXVersion = 11
        let r = CompatibilityScorer.score(files: nil, online: o, context: .init())
        XCTAssertEqual(r.tier, .broken)
        XCTAssertTrue(r.factors.contains { $0.key == "compat.f.acLinuxOnly" })
    }

    func testVACIsHarmless() {
        var o = OnlineFindings(); o.antiCheats = ["VAC"]; o.directXVersion = 11; o.steamDeckCategory = 3
        XCTAssertNotEqual(CompatibilityScorer.score(files: nil, online: o, context: .init()).tier, .broken)
    }

    func testDX11DeckVerifiedPlatinumIsExcellent() {
        var f = FileFindings(); f.analyzedFiles = 10; f.has64Bit = true; f.graphics = [.d3d11]; f.engine = .unity
        var o = OnlineFindings(); o.steamDeckCategory = 3; o.protonTier = "platinum"; o.protonReports = 300; o.protonConfidence = "strong"
        let r = CompatibilityScorer.score(files: f, online: o, context: .init())
        XCTAssertEqual(r.tier, .excellent)
        XCTAssertEqual(r.confidence, .high)
    }

    func testDX12NeedsD3DMetal() {
        var o = OnlineFindings(); o.directXVersion = 12
        let without = CompatibilityScorer.score(files: nil, online: o, context: .init(d3dMetalAvailable: false))
        let with = CompatibilityScorer.score(files: nil, online: o, context: .init(d3dMetalAvailable: true))
        XCTAssertLessThan(without.score, with.score)
        XCTAssertTrue(without.factors.contains { $0.key == "compat.f.dx12noMetal" })
    }

    func testGameSupportingDX11And12UsesBestPath() {
        XCTAssertEqual(CompatibilityScorer.bestPath([.d3d12, .d3d11], is64: true, d3dMetal: false), .d3d11)
        XCTAssertEqual(CompatibilityScorer.bestPath([.d3d9, .d3d11], is64: false, d3dMetal: true), .d3d11)
    }

    /// The S2 Rebirth case: 32-bit DirectX 9 with its own anti-cheat and a .NET launcher → poor/playable, not excellent.
    func testS2RebirthLikeGame() {
        var f = FileFindings(); f.analyzedFiles = 20; f.has32Bit = true; f.graphics = [.d3d9]; f.usesDotNet = true
        f.antiCheats = [AntiCheatFinding(name: "ApexGuard", kernel: false)]; f.shipsDirectXHelpers = true
        let r = CompatibilityScorer.score(files: f, online: nil, context: .init())
        XCTAssertTrue([.poor, .playable].contains(r.tier), "got \(r.tier) \(r.score)")
    }

    func testRequirementsParsing() {
        XCTAssertEqual(CompatibilitySignals.directXVersion(inRequirements: "<strong>DirectX:</strong> Version 11<br>"), 11)
        XCTAssertEqual(CompatibilitySignals.directXVersion(inRequirements: "Graphics: 1GB VRAM / DirectX 10+ support"), 10)
        XCTAssertEqual(CompatibilitySignals.directXVersion(inRequirements: "Requires DX12 capable GPU"), 12)
        XCTAssertNil(CompatibilitySignals.directXVersion(inRequirements: "OS: Windows 10"))
    }
}

final class GameFileAnalyzerTests: XCTestCase {
    private func folder(_ files: [String: Data]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("game-\(UUID().uuidString)", isDirectory: true)
        for (path, data) in files {
            let url = dir.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        return dir
    }

    func testDetectsEngineAntiCheatAndLauncher() throws {
        let dir = try folder(["Game_Data/Managed/UnityEngine.dll": Data(), "UnityPlayer.dll": Data(),
                              "EasyAntiCheat/EasyAntiCheat_EOS_Setup.exe": Data(), "uplay_r1_loader64.dll": Data()])
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = GameFileAnalyzer.analyze(folders: [dir])
        XCTAssertEqual(f.engine, .unity)
        XCTAssertEqual(f.antiCheats.first, AntiCheatFinding(name: "Easy Anti-Cheat", kernel: true))
        XCTAssertEqual(f.launcher, "Ubisoft Connect")
        XCTAssertTrue(f.graphics.contains(.d3d11)) // Unity default when nothing is imported
    }

    func testCustomAntiCheatIsUnknownNotKernel() throws {
        let dir = try folder(["ApexGuard.dll": Data(), "TheRaw.exe": Data()])
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = GameFileAnalyzer.analyze(folders: [dir])
        XCTAssertEqual(f.antiCheats, [AntiCheatFinding(name: "apexguard", kernel: false)])
    }

    func testFindsDynamicallyLoadedDirect3D() throws {
        var bytes = Data(repeating: 0, count: 64)
        bytes.append(Data("D3D9.DLL".utf8))
        bytes.append(Data("d3d11.dll".utf8.flatMap { [$0, 0] })) // UTF-16
        let dir = try folder(["Game.exe": bytes])
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertEqual(GameFileAnalyzer.apis(inBinary: dir.appendingPathComponent("Game.exe")), [.d3d9, .d3d11])
    }
}

final class CompatibilityRulesV2Tests: XCTestCase {
    func testNoEvidenceIsUnknown() {
        XCTAssertEqual(CompatibilityScorer.score(files: nil, online: OnlineFindings(), context: .init()).tier, .unknown)
    }

    func testUnknownGraphicsCappedAtGood() {
        var o = OnlineFindings(); o.protonTier = "platinum"; o.protonReports = 300; o.steamDeckCategory = 3
        let r = CompatibilityScorer.score(files: nil, online: o, context: .init())
        XCTAssertLessThanOrEqual(r.score, 74)
        XCTAssertEqual(r.tier, .good)
    }

    func testGPUHintGivesDX11Guess() {
        XCTAssertTrue(CompatibilitySignals.gpuSuggestsDX11("Graphics: 2 GB, GeForce GTX 660/Radeon HD 7870"))
        XCTAssertFalse(CompatibilitySignals.gpuSuggestsDX11("Graphics: GeForce 8800 GT"))
        var o = OnlineFindings(); o.gpuSuggestsDX11 = true
        XCTAssertTrue(CompatibilityScorer.score(files: nil, online: o, context: .init()).factors.contains { $0.key == "compat.f.dx11guess" })
    }

    func testReportKeepsEvidenceForRescoring() {
        var o = OnlineFindings(); o.directXVersion = 11
        let r = CompatibilityScorer.score(files: nil, online: o, context: .init())
        XCTAssertEqual(r.online, o)
        XCTAssertEqual(r.version, CompatibilityScorer.version)
    }
}

final class AntiCheatRulesTests: XCTestCase {
    func testUserModeAntiCheatThatRunsOnLinuxDoesNotBlock() {
        var o = OnlineFindings(); o.antiCheats = ["GuardingPearSoftware's Anti Cheat Pro"]; o.antiCheatStatus = "Running"; o.directXVersion = 11
        let r = CompatibilityScorer.score(files: nil, online: o, context: .init())
        XCTAssertNotEqual(r.tier, .broken)
        XCTAssertTrue(r.factors.contains { $0.key == "compat.f.userAC" })
    }

    func testUnknownAntiCheatThatIsBrokenOnLinuxBlocks() {
        var o = OnlineFindings(); o.antiCheats = ["Some Custom AC"]; o.antiCheatStatus = "Broken"
        XCTAssertEqual(CompatibilityScorer.score(files: nil, online: o, context: .init()).tier, .broken)
    }
}

final class MatchingRulesTests: XCTestCase {
    func testEditionSuffixFallback() {
        XCTAssertEqual(CompatibilitySignals.baseTitle("Grand Theft Auto V Enhanced"), "Grand Theft Auto V")
        XCTAssertEqual(CompatibilitySignals.baseTitle("Dishonored - Definitive Edition"), "Dishonored")
        XCTAssertEqual(CompatibilitySignals.baseTitle("Hades"), "Hades")
        XCTAssertTrue(CompatibilitySignals.rockstarLauncherNeeded("Grand Theft Auto V Enhanced"))
        XCTAssertFalse(CompatibilitySignals.rockstarLauncherNeeded("Subnautica"))
    }

    func testCoverMatchPrefersExactThenPrefix() {
        let items: [(id: Int, name: String, tiny: String?)] = [(1, "Subnautica: Below Zero", nil), (2, "Subnautica", nil)]
        XCTAssertEqual(CoverFinder.bestMatch(for: "subnautica", in: items)?.id, 2)
        XCTAssertEqual(CoverFinder.bestMatch(for: "Subnautica Below", in: items)?.id, 1)
        XCTAssertNil(CoverFinder.bestMatch(for: "S2 Rebirth", in: items))
    }

    func testThirdPartyLauncherLowersScore() {
        var o = OnlineFindings(); o.directXVersion = 11
        let plain = CompatibilityScorer.score(files: nil, online: o, context: .init()).score
        o.thirdPartyLauncher = "Rockstar Games Launcher"
        XCTAssertEqual(CompatibilityScorer.score(files: nil, online: o, context: .init()).score, plain - 15)
    }
}
