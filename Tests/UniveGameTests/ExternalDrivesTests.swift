import XCTest
@testable import UniveGame

final class ExternalDrivesTests: XCTestCase {
    func testAddsALetterOncePerDiskAndKeepsExistingOnes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("drives-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let dos = root.appendingPathComponent("dosdevices", isDirectory: true)
        try FileManager.default.createDirectory(at: dos, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: dos.appendingPathComponent("c:").path, withDestinationPath: "../drive_c")
        try FileManager.default.createSymbolicLink(atPath: dos.appendingPathComponent("d:").path, withDestinationPath: "/Volumes/Old")
        try FileManager.default.createSymbolicLink(atPath: dos.appendingPathComponent("z:").path, withDestinationPath: "/")

        let strix = URL(fileURLWithPath: "/Volumes/STRIX ARION")
        XCTAssertEqual(ExternalDrives.link([strix], into: dos), ["e:"])
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: dos.appendingPathComponent("e:").path), "/Volumes/STRIX ARION")
        XCTAssertEqual(ExternalDrives.link([strix], into: dos), [])   // already there
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: dos.appendingPathComponent("d:").path), "/Volumes/Old")
        XCTAssertEqual(ExternalDrives.link([strix], into: root.appendingPathComponent("missing")), [])
    }
}
