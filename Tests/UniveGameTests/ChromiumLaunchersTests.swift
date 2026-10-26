import XCTest
@testable import UniveGame

final class ChromiumLaunchersTests: XCTestCase {
    func testHoYoPlayDrawsInSoftware() {
        let launcher = URL(fileURLWithPath: "/b/drive_c/Program Files/HoYoPlay/launcher.exe")
        XCTAssertEqual(ChromiumLaunchers.arguments(for: launcher, []), ChromiumLaunchers.softwareRendering)
        // The versioned folder's HYP.exe too, and nothing is added twice.
        let hyp = URL(fileURLWithPath: "/b/drive_c/Program Files/HoYoPlay/1.18.0.380/HYP.exe")
        XCTAssertEqual(ChromiumLaunchers.arguments(for: hyp, ["--disable-gpu"]).filter { $0 == "--disable-gpu" }.count, 1)
    }

    func testOtherProgramsAreLeftAlone() {
        let game = URL(fileURLWithPath: "/b/drive_c/Games/Some/launcher.exe")
        XCTAssertEqual(ChromiumLaunchers.arguments(for: game, ["-windowed"]), ["-windowed"])
        XCTAssertTrue(ChromiumLaunchers.registryCommands(for: game).isEmpty)
    }

    func testHoYoPlayKeepsItsOwnTitleBar() {
        let launcher = URL(fileURLWithPath: "/b/drive_c/Program Files/HoYoPlay/launcher.exe")
        XCTAssertEqual(ChromiumLaunchers.registryCommands(for: launcher),
                       [["reg", "add", #"HKCU\Software\Wine\AppDefaults\HYP.exe\X11 Driver"#, "/v", "Decorated", "/t", "REG_SZ", "/d", "N", "/f"]])
    }
}
