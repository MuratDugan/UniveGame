import AppKit
import XCTest
@testable import UniveGame

final class ShortcutIconTests: XCTestCase {
    func testMakesAnIconFromAPortraitCover() async throws {
        let cover = NSImage(size: NSSize(width: 300, height: 450), flipped: false) { rect in
            NSColor.systemBlue.setFill(); rect.fill(); return true
        }
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(cover.tiffRepresentation))?.representation(using: .png, properties: [:]))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("icon-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let made = await ShortcutIcon.make(from: png, in: folder)
        let icns = try XCTUnwrap(made)
        XCTAssertEqual(icns.pathExtension, "icns")
        XCTAssertNotNil(NSImage(contentsOf: icns))
        let bad = await ShortcutIcon.make(from: Data("not an image".utf8), in: folder)
        XCTAssertNil(bad)
    }
}
