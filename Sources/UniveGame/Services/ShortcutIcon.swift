import AppKit
import UniveEngineKit

/// A Dock icon for a game shortcut, from its cover: the cover cropped to a square on a rounded tile, as an `.icns`.
enum ShortcutIcon {
    static func make(from imageData: Data, in folder: URL) async -> URL? {
        guard let cover = NSImage(data: imageData) else { return nil }
        let fm = FileManager.default
        let iconset = folder.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        guard (try? fm.createDirectory(at: iconset, withIntermediateDirectories: true)) != nil else { return nil }
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let suffix = scale == 2 ? "@2x" : ""
                guard let png = tile(cover, pixels: size * scale) else { return nil }
                try? png.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
            }
        }
        let icns = folder.appendingPathComponent("AppIcon.icns")
        let r = try? await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/iconutil"), ["-c", "icns", iconset.path, "-o", icns.path])
        return r?.succeeded == true && fm.fileExists(atPath: icns.path) ? icns : nil
    }

    /// The cover's top square (covers are portrait), inset on a rounded tile like other Mac icons.
    static func tile(_ cover: NSImage, pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let side = CGFloat(pixels)
        let inset = side * 0.1
        let rect = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
        NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225).addClip()
        let size = cover.size
        let square = min(size.width, size.height)
        let source = NSRect(x: (size.width - square) / 2, y: size.height - square, width: square, height: square)
        cover.draw(in: rect, from: source, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
