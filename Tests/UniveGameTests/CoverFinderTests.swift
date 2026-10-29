import XCTest
@testable import UniveGame

final class CoverFinderTests: XCTestCase {
    func testProgramWordsAreDroppedFromTheSearch() {
        XCTAssertEqual(CoverFinder.searchTitles(for: "Genshin Impact game"), ["Genshin Impact game", "Genshin Impact"])
        XCTAssertEqual(CoverFinder.searchTitles(for: "Metin2 Launcher x64"), ["Metin2 Launcher x64", "Metin2"])
        XCTAssertEqual(CoverFinder.searchTitles(for: "Hollow Knight"), ["Hollow Knight"])
        XCTAssertEqual(CoverFinder.searchTitles(for: "Game"), ["Game"])   // never down to nothing
    }

    func testOnlyTheGamesOwnArticleMatches() {
        XCTAssertEqual(CoverFinder.wikipediaMatch(for: "Counter-Strike", in: ["Counter-Strike (video game)", "Counter-Strike", "Counter-Strike 2"]),
                       "Counter-Strike (video game)")
        XCTAssertEqual(CoverFinder.wikipediaMatch(for: "Genshin Impact", in: ["Genshin Impact", "Venti (Genshin Impact)"]), "Genshin Impact")
        XCTAssertEqual(CoverFinder.wikipediaMatch(for: "Prey", in: ["Prey (2017 video game)"]), "Prey (2017 video game)")
        // Close but wrong: no cover rather than someone else's.
        XCTAssertNil(CoverFinder.wikipediaMatch(for: "Knight Online", in: ["Star Wars: Knights of the Old Republic (video game)", "Lineage (video game)"]))
        XCTAssertNil(CoverFinder.wikipediaMatch(for: "HoYoPlay", in: ["MiHoYo", "Genshin Impact"]))
    }
}
