import XCTest
@testable import UniveGame

final class DisplayModesTests: XCTestCase {
    func testReadsTheBottleWideValueOnly() {
        let reg = """
        [Software\\\\Wine\\\\AppDefaults\\\\HYP.exe\\\\X11 Driver] 1700000000
        "EmulateModeset"="N"

        [Software\\\\Wine\\\\X11 Driver] 1700000000
        #time=1da0
        "Decorated"="Y"
        "EmulateModeset"="Y"

        [Software\\\\Wine\\\\Other] 1700000000
        """
        XCTAssertEqual(DisplayModes.current(inUserReg: reg), true)
        XCTAssertNil(DisplayModes.current(inUserReg: "[Software\\\\Wine\\\\X11 Driver] 1\n\"Decorated\"=\"N\"\n"))
        XCTAssertNil(DisplayModes.current(inUserReg: ""))
        XCTAssertEqual(DisplayModes.current(inUserReg: "[Software\\\\Wine\\\\X11 Driver] 1\r\n\"EmulateModeset\"=\"n\"\r\n"), false)
    }

    func testCommand() {
        XCTAssertEqual(DisplayModes.command(on: true),
                       ["reg", "add", #"HKCU\Software\Wine\X11 Driver"#, "/v", "EmulateModeset", "/t", "REG_SZ", "/d", "Y", "/f"])
        XCTAssertEqual(DisplayModes.command(on: false).dropLast(2).last, "/d")
    }
}
