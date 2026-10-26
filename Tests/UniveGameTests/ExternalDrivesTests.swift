import XCTest
@testable import UniveGame

final class ExternalDrivesTests: XCTestCase {
    private func disk(_ id: String, _ path: String) -> ExternalDrives.Disk {
        ExternalDrives.Disk(id: id, name: id, url: URL(fileURLWithPath: path), capacity: nil, available: nil, format: nil, readOnly: false)
    }

    func testNewDisksGetFreeLettersAndKnownOnesKeepTheirs() {
        let saved = ["A": ExternalDrives.Assignment(letter: "e:", path: "/Volumes/Old name"),
                     "H": ExternalDrives.Assignment(letter: nil, path: "/Volumes/Hidden")]
        let result = ExternalDrives.assign([disk("A", "/Volumes/STRIX"), disk("B", "/Volumes/USB"), disk("H", "/Volumes/Hidden")],
                                           saved: saved, reserved: ["c:", "d:", "z:"])
        XCTAssertEqual(result["A"], .init(letter: "e:", path: "/Volumes/STRIX"))   // renamed: same letter, new path
        XCTAssertEqual(result["B"]?.letter, "f:")                                   // d: is taken by something else
        XCTAssertNil(result["H"]?.letter)                                          // the player hid it
    }

    func testApplyManagesOnlyItsOwnLinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("drives-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let dos = root.appendingPathComponent("dosdevices", isDirectory: true)
        try FileManager.default.createDirectory(at: dos, withIntermediateDirectories: true)
        let fm = FileManager.default
        try fm.createSymbolicLink(atPath: dos.appendingPathComponent("c:").path, withDestinationPath: "../drive_c")
        try fm.createSymbolicLink(atPath: dos.appendingPathComponent("d:").path, withDestinationPath: "/Users/me/iso")   // not ours
        try fm.createSymbolicLink(atPath: dos.appendingPathComponent("g:").path, withDestinationPath: "/Volumes/Gone")     // ours, unwanted
        try fm.createSymbolicLink(atPath: dos.appendingPathComponent("z:").path, withDestinationPath: "/")
        XCTAssertEqual(ExternalDrives.foreignLetters(in: dos), ["c:", "d:", "z:"])

        ExternalDrives.apply(["e:": "/Volumes/STRIX ARION", "d:": "/Volumes/Other"], to: dos)
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: dos.appendingPathComponent("e:").path), "/Volumes/STRIX ARION")
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: dos.appendingPathComponent("d:").path), "/Users/me/iso")
        XCTAssertFalse(fm.fileExists(atPath: dos.appendingPathComponent("g:").path))

        // A new letter for the disk moves the link.
        ExternalDrives.apply(["f:": "/Volumes/STRIX ARION"], to: dos)
        XCTAssertNil(try? fm.destinationOfSymbolicLink(atPath: dos.appendingPathComponent("e:").path))
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: dos.appendingPathComponent("f:").path), "/Volumes/STRIX ARION")
    }
}
