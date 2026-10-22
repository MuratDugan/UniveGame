import XCTest
@testable import UniveGame

final class InstallerKindTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("kind-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func file(_ name: String, _ marker: [UInt8], padding: Int = 100_000) throws -> URL {
        let url = dir.appendingPathComponent(name)
        var data = Data("MZ".utf8) + Data(count: padding) + Data(marker) + Data(count: 64)
        if marker.isEmpty { data = Data("MZ".utf8) + Data(count: padding) }
        try data.write(to: url)
        return url
    }

    func testRecognizesBuildersFromTheirMarkers() throws {
        XCTAssertEqual(InstallerKind.detect(try file("a.exe", Array("Inno Setup Setup Data (5.5.7)".utf8))), .inno)
        XCTAssertEqual(InstallerKind.detect(try file("b.exe", Array("NullsoftInst".utf8))), .nsis)
        XCTAssertEqual(InstallerKind.detect(try file("c.exe", [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])), .sevenZip)
        XCTAssertEqual(InstallerKind.detect(try file("d.exe", [])), .unknown)
    }

    func testMarkerSplitAcrossReadChunksIsFound() throws {
        // The reader works in 4 MB chunks; a marker straddling two of them must still count.
        let url = try file("e.exe", Array("Inno Setup Setup Data".utf8), padding: (4 << 20) - 10)
        XCTAssertEqual(InstallerKind.detect(url), .inno)
    }

    func testExtensionsWin() throws {
        XCTAssertEqual(InstallerKind.detect(try file("game.msi", [])), .msi)
        XCTAssertEqual(InstallerKind.detect(try file("game.zip", [])), .zip)
    }

    func testGoldSrcGamesStartTheirMod() throws {
        let game = dir.appendingPathComponent("CS", isDirectory: true)
        try FileManager.default.createDirectory(at: game.appendingPathComponent("cstrike"), withIntermediateDirectories: true)
        XCTAssertEqual(InstallScanner.defaultArguments(for: game.appendingPathComponent("hl.exe")), ["-game", "cstrike"])
        XCTAssertEqual(InstallScanner.defaultArguments(for: game.appendingPathComponent("game.exe")), [])
    }
}
