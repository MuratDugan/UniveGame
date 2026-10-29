import XCTest
@testable import UniveGame

final class CloudGamingTests: XCTestCase {
    func testKnownGamesAreFoundWhateverTheirFolderIsCalled() {
        XCTAssertTrue(CloudGaming.isOnGeForceNow("Genshin Impact game"))
        XCTAssertTrue(CloudGaming.isOnGeForceNow("Honkai: Star Rail"))
        XCTAssertTrue(CloudGaming.isOnGeForceNow("Zenless Zone Zero"))
        XCTAssertFalse(CloudGaming.isOnGeForceNow("VALORANT"))   // not on the service: no false promise
        XCTAssertFalse(CloudGaming.isOnGeForceNow("Metin2"))
    }
}
