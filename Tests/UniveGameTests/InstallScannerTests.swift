import XCTest
@testable import UniveGame

final class InstallScannerTests: XCTestCase {
    private var driveC: URL!

    override func setUpWithError() throws {
        driveC = FileManager.default.temporaryDirectory.appendingPathComponent("drive_c-\(UUID().uuidString)", isDirectory: true)
        try touch("windows/system32/notepad.exe")
        try touch("Program Files/Common Files/helper.exe")
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: driveC) }

    private func touch(_ path: String, size: UInt64 = 1024) throws {
        let url = driveC.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: size) // sparse: no real disk use
        try handle.close()
    }

    func testFindsGameFolderLauncherAndUninstaller() throws {
        let before = InstallScanner.snapshot(driveC: driveC)
        try touch("Games/S2Rebirth/S2Rebirth.exe", size: 3_000_000_000)
        try touch("Games/S2Rebirth/Launcher.exe", size: 8_000_000)
        try touch("Games/S2Rebirth/unins000.exe")
        try touch("Games/S2Rebirth/Redist/vcredist_x64.exe")
        try touch("Games/S2Rebirth/Engine/Binaries/UnityCrashHandler64.exe")
        let after = InstallScanner.snapshot(driveC: driveC)

        let result = InstallScanner.scan(before: before, after: after, driveC: driveC)
        XCTAssertEqual(result.installDirectory?.lastPathComponent, "S2Rebirth")
        XCTAssertEqual(result.uninstaller?.lastPathComponent, "unins000.exe")
        XCTAssertEqual(result.candidates.map(\.name), ["Launcher.exe", "S2Rebirth.exe"])
        XCTAssertEqual(result.candidates.first?.windowsPath, #"C:\Games\S2Rebirth\Launcher.exe"#)
    }

    func testWithoutLauncherPrefersExeNamedLikeFolder() throws {
        let before = InstallScanner.snapshot(driveC: driveC)
        try touch("Program Files (x86)/Studio/My Game/MyGame.exe", size: 200_000_000)
        try touch("Program Files (x86)/Studio/My Game/tools/editor.exe", size: 300_000_000)
        let result = InstallScanner.scan(before: before, after: InstallScanner.snapshot(driveC: driveC), driveC: driveC)
        XCTAssertEqual(result.candidates.first?.name, "MyGame.exe")
        XCTAssertEqual(result.installDirectory?.lastPathComponent, "Studio")
    }

    func testSystemFoldersAreIgnoredAndOlderGamesAreNotOffered() throws {
        try touch("Games/Old/Old.exe")
        let snap = InstallScanner.snapshot(driveC: driveC)
        XCTAssertFalse(snap.keys.contains { $0.contains("/windows/") || $0.contains("Common Files") })
        // An installer that crashed or added nothing must not offer a game installed earlier.
        let result = InstallScanner.scan(before: snap, after: snap, driveC: driveC)
        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertNil(result.installDirectory)
    }

    func testDisplayTitle() {
        XCTAssertEqual(InstallScanner.displayTitle(fromFolder: "S2Rebirth"), "S2 Rebirth")
        XCTAssertEqual(InstallScanner.displayTitle(fromFolder: "my_cool-game"), "my cool game")
        XCTAssertEqual(InstallScanner.displayTitle(fromFolder: "GTAV"), "GTAV")
    }
}

final class InstallScannerSymlinkTests: XCTestCase {
    /// The bottle may be reached through a symlink (/tmp → /private/tmp); the uninstaller must still be found.
    func testSymlinkedDriveFindsUninstaller() throws {
        let fm = FileManager.default
        let real = fm.temporaryDirectory.appendingPathComponent("real-\(UUID().uuidString)", isDirectory: true)
        let link = fm.temporaryDirectory.appendingPathComponent("link-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: real); try? fm.removeItem(at: link) }
        try fm.createDirectory(at: real.appendingPathComponent("windows"), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: link, withDestinationURL: real)

        let before = InstallScanner.snapshot(driveC: link)
        for name in ["Game.exe", "unins000.exe"] {
            let url = real.appendingPathComponent("Games/Game/\(name)")
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            fm.createFile(atPath: url.path, contents: Data(count: 10))
        }
        let result = InstallScanner.scan(before: before, after: InstallScanner.snapshot(driveC: link), driveC: link)
        XCTAssertEqual(result.uninstaller?.lastPathComponent, "unins000.exe")
        XCTAssertEqual(result.candidates.map(\.name), ["Game.exe"])
        XCTAssertEqual(result.candidates.first?.windowsPath, #"C:\Games\Game\Game.exe"#)
    }
}

final class AppInfoReaderTests: XCTestCase {
    /// A minimal v29 appinfo.vdf: one app with appinfo/common/{name,type}, keys in a string table.
    func testReadsNameAndTypeFromV29() {
        var body = Data()
        func u8(_ v: UInt8) { body.append(v) }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { body.append(contentsOf: $0) } }
        func str(_ s: String) { body.append(contentsOf: Array(s.utf8)); body.append(0) }
        // strings: 0 appinfo, 1 common, 2 name, 3 type
        u8(0x00); u32(0)          // appinfo {
        u8(0x00); u32(1)          //   common {
        u8(0x01); u32(2); str("Hollow Knight")
        u8(0x01); u32(3); str("Game")
        u8(0x02); u32(2); u32(7)  //   (an int under common named "name" must not be mistaken for a string)
        u8(0x08); u8(0x08); u8(0x08)

        var entry = Data()
        let header = 4 + 4 + 8 + 20 + 4 + 20
        withUnsafeBytes(of: UInt32(367520).littleEndian) { entry.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(header + body.count).littleEndian) { entry.append(contentsOf: $0) }
        entry.append(Data(count: header))
        entry.append(body)
        entry.append(contentsOf: [0, 0, 0, 0]) // end of apps

        var file = Data()
        withUnsafeBytes(of: UInt32(0x07564429).littleEndian) { file.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(1).littleEndian) { file.append(contentsOf: $0) }
        let tableOffset = Int64(16 + entry.count)
        withUnsafeBytes(of: tableOffset.littleEndian) { file.append(contentsOf: $0) }
        file.append(entry)
        withUnsafeBytes(of: UInt32(4).littleEndian) { file.append(contentsOf: $0) }
        for s in ["appinfo", "common", "name", "type"] { file.append(contentsOf: Array(s.utf8)); file.append(0) }

        let apps = AppInfoReader.read(file)
        XCTAssertEqual(apps[367520], AppInfoReader.App(name: "Hollow Knight", type: "game"))
        XCTAssertTrue(AppInfoReader.read(file, only: [1]).isEmpty)
    }
}

final class EpicLibraryFilterTests: XCTestCase {
    func testDropsPluginsEditorsAndExtras() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("legendary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func meta(_ app: String, _ cats: [String]) throws {
            let json: [String: Any] = ["metadata": ["categories": cats.map { ["path": $0] }]]
            try JSONSerialization.data(withJSONObject: json).write(to: dir.appendingPathComponent("\(app).json"))
        }
        try meta("Game", ["public", "games", "applications"])
        try meta("Plugin", ["plugins/engine", "plugins"])
        try meta("Editor", ["engines", "applications"])
        try meta("Soundtrack", ["public", "digitalextras", "games", "applications"])
        XCTAssertTrue(EpicLibraryFilter.isGame(appName: "Game", title: "ABZU", metadataFolder: dir))
        XCTAssertFalse(EpicLibraryFilter.isGame(appName: "Plugin", title: "Substance 3D for Unreal Engine", metadataFolder: dir))
        XCTAssertFalse(EpicLibraryFilter.isGame(appName: "Editor", title: "Squad Editor", metadataFolder: dir))
        XCTAssertFalse(EpicLibraryFilter.isGame(appName: "Soundtrack", title: "Death Stranding Content", metadataFolder: dir))
        XCTAssertFalse(EpicLibraryFilter.isGame(appName: "Game", title: "Cyberpunk 2077 Bonus Content", metadataFolder: dir))
        XCTAssertTrue(EpicLibraryFilter.isGame(appName: "Unknown", title: "No Metadata Yet", metadataFolder: dir))
    }
}

final class NativeDLLPolicyTests: XCTestCase {
    func testPrefersShippedDirectXHelpersOnly() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("game-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for f in ["D3DCompiler_43.dll", "D3DX9_43.dll", "d3dx9_27.dll", "msvcr100.dll", "fmodex.dll", "readme.txt"] {
            FileManager.default.createFile(atPath: dir.appendingPathComponent(f).path, contents: Data())
        }
        XCTAssertEqual(NativeDLLPolicy.overrides(for: [dir]), ["d3dcompiler_43,d3dx9_27,d3dx9_43=n,b"])
        XCTAssertEqual(NativeDLLPolicy.overrides(for: []), [])
    }
}
