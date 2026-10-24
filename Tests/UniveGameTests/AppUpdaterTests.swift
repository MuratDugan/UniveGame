import XCTest
@testable import UniveGame

final class AppUpdaterTests: XCTestCase {
    private let digest = String(repeating: "ab", count: 32)

    private func release(tag: String = "v1.2.0", asset: String? = nil, url: String? = nil, size: Int = 3_000_000,
                         digest: String? = nil, prerelease: Bool = false) -> Data {
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let name = asset ?? "UniveGame-\(version).dmg"
        let link = url ?? "https://github.com/MuratDugan/UniveGame/releases/download/\(tag)/\(name)"
        let digestField = digest.map { #","digest":"\#($0)""# } ?? ""
        return Data(#"""
        {"tag_name":"\#(tag)","body":"**Fixed** things","html_url":"https://github.com/MuratDugan/UniveGame/releases/tag/\#(tag)",
         "draft":false,"prerelease":\#(prerelease),
         "assets":[{"name":"\#(name)","size":\#(size),"browser_download_url":"\#(link)"\#(digestField)}]}
        """#.utf8)
    }

    func testFindsANewerReleaseWithItsDigest() throws {
        let update = try XCTUnwrap(AppUpdater.parse(release(digest: "sha256:\(digest)"), current: "1.0.3"))
        XCTAssertEqual(update.version, "1.2.0")
        XCTAssertEqual(update.sha256, digest)
        XCTAssertEqual(update.size, 3_000_000)
        XCTAssertEqual(update.download.absoluteString, "https://github.com/MuratDugan/UniveGame/releases/download/v1.2.0/UniveGame-1.2.0.dmg")
        XCTAssertEqual(update.notes, "**Fixed** things")
    }

    func testSameOrOlderReleaseIsNoUpdate() throws {
        XCTAssertNil(try AppUpdater.parse(release(tag: "v1.0.3"), current: "1.0.3"))
        XCTAssertNil(try AppUpdater.parse(release(tag: "v1.0.2"), current: "1.0.3"))   // never a downgrade
        XCTAssertNil(try AppUpdater.parse(release(prerelease: true), current: "1.0.3"))
    }

    func testVersionsCompareNumerically() {
        XCTAssertTrue(AppUpdater.isNewer("1.0.10", than: "1.0.9"))
        XCTAssertFalse(AppUpdater.isNewer("1.0.9", than: "1.0.10"))
        XCTAssertTrue(AppUpdater.isVersion("1.0.4"))
        XCTAssertFalse(AppUpdater.isVersion("1.0.4-beta"))
        XCTAssertFalse(AppUpdater.isVersion("../1.0"))
    }

    func testOnlyThisRepositorysDiskImageIsAccepted() {
        // Another repository, a lookalike host, plain HTTP, another file name, an absurd size.
        for data in [release(url: "https://github.com/someone/UniveGame/releases/download/v1.2.0/UniveGame-1.2.0.dmg"),
                     release(url: "https://github.com.evil.example/MuratDugan/UniveGame/releases/download/v1.2.0/UniveGame-1.2.0.dmg"),
                     release(url: "http://github.com/MuratDugan/UniveGame/releases/download/v1.2.0/UniveGame-1.2.0.dmg"),
                     release(asset: "UniveGame-1.2.0.pkg"),
                     release(size: 900_000_000)] {
            XCTAssertThrowsError(try AppUpdater.parse(data, current: "1.0.3"))
        }
        XCTAssertThrowsError(try AppUpdater.parse(release(tag: "v1.2.0-rc1"), current: "1.0.3"))
    }

    func testDigestMustBeAFullSHA256() {
        XCTAssertNil(AppUpdater.sha256(fromDigest: "sha1:\(digest)"))
        XCTAssertNil(AppUpdater.sha256(fromDigest: "sha256:abc"))
        XCTAssertEqual(AppUpdater.sha256(fromDigest: "sha256:\(digest.uppercased())"), digest)
    }

    func testRedirectsStayOnGitHub() {
        XCTAssertTrue(UpdateDownloadHosts.allowed(URL(string: "https://release-assets.githubusercontent.com/x")))
        XCTAssertFalse(UpdateDownloadHosts.allowed(URL(string: "http://release-assets.githubusercontent.com/x")))
        XCTAssertFalse(UpdateDownloadHosts.allowed(URL(string: "https://githubusercontent.com.evil.example/x")))
    }

    func testAnUnsignedOrForeignAppIsRejected() throws {
        let fake = FileManager.default.temporaryDirectory.appendingPathComponent("Fake-\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: fake.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fake) }
        XCTAssertThrowsError(try AppUpdater.checkSignature(of: fake))
        // An Apple app is validly signed, but not by UniveGame's team.
        XCTAssertThrowsError(try AppUpdater.checkSignature(of: URL(fileURLWithPath: "/System/Applications/Calculator.app")))
    }

    func testAReleasedUniveGameMeetsTheRequirement() throws {
        // Only where a released copy is installed (not on CI).
        let app = URL(fileURLWithPath: "/Applications/UniveGame.app")
        guard Bundle(url: app)?.bundleIdentifier == AppUpdater.bundleID else { throw XCTSkip("no released UniveGame installed") }
        XCTAssertNoThrow(try AppUpdater.checkSignature(of: app))
    }
}
