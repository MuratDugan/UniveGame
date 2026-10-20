import AppKit
import ImageIO
import SwiftUI

/// Remote or local artwork with a generated placeholder (title initials on a gradient).
struct CoverArt: View {
    let url: URL?
    let title: String
    var symbol: String = "gamecontroller.fill"

    var body: some View {
        placeholder
            .overlay {
                if let url {
                    if url.isFileURL {
                        LocalImage(url: url)
                    } else {
                        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                            if let image = phase.image { image.resizable().scaledToFill().transition(.opacity) }
                        }
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// Flat tile with the title, so a missing cover reads as "no artwork", not as decoration.
    private var placeholder: some View {
        Rectangle()
            .fill(Theme.Palette.elevated)
            .overlay {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }
    }
}

/// Local artwork, decoded and downsized off the main thread and cached, so a library of hundreds of
/// covers scrolls smoothly.
private struct LocalImage: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        // A clear base so the view exists (and its task runs) before the image arrives.
        Color.clear
            .overlay {
                if let image { Image(nsImage: image).resizable().scaledToFill().transition(.opacity) }
            }
            .task(id: url) {
            if let cached = ImageCache.shared.object(forKey: url as NSURL) { image = cached; return }
            let loaded = await Task.detached(priority: .userInitiated) { ImageCache.downsampled(url, maxPixel: 900) }.value
            if let loaded { ImageCache.shared.setObject(loaded, forKey: url as NSURL) }
            withAnimation(.easeOut(duration: 0.15)) { image = loaded }
        }
    }
}

enum ImageCache {
    static let shared: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 400
        return cache
    }()

    static func downsampled(_ url: URL, maxPixel: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

struct StatusChip: View {
    let text: String
    let color: Color
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text(title).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary)
            Text(message)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(PrimaryButtonStyle())
                    .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lets a whole row of settings toggle from its label, with a description underneath.
struct SettingToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Font.body).foregroundStyle(Theme.Palette.textPrimary)
                Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .tint(Theme.Palette.accent)
    }
}

extension TimeInterval {
    /// "42 sa" / "42 h", or minutes when under an hour.
    @MainActor func playTimeText(_ L: Localizer) -> String {
        let hours = Int(self / 3600)
        if hours >= 1 { return L("time.hours", hours) }
        return L("time.minutes", max(Int(self / 60), 0))
    }
}
