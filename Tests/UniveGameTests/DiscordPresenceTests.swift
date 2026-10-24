import XCTest
@testable import UniveGame

final class DiscordPresenceTests: XCTestCase {
    func testFramesCarryOpcodeAndLengthLittleEndian() throws {
        let frame = try XCTUnwrap(DiscordPresence.frame(op: 1, ["cmd": "SET_ACTIVITY"]))
        XCTAssertEqual(Array(frame.prefix(4)), [1, 0, 0, 0])
        let length = Int(frame[4]) | Int(frame[5]) << 8 | Int(frame[6]) << 16 | Int(frame[7]) << 24
        XCTAssertEqual(length, frame.count - 8)
        XCTAssertEqual(String(decoding: frame.dropFirst(8), as: UTF8.self), #"{"cmd":"SET_ACTIVITY"}"#)
    }

    func testLooksForDiscordSocketsInTheTemporaryFolder() {
        let paths = DiscordPresence.socketPaths()
        XCTAssertEqual(paths.count, 10)
        XCTAssertTrue(paths[0].hasSuffix("discord-ipc-0"))
    }

    func testWithoutAnApplicationIDNothingHappens() {
        // The test bundle has no id: showing must be a harmless no-op.
        DiscordPresence().show("Game")
        DiscordPresence().show(nil)
    }
}
