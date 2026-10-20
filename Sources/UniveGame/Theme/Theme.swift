import SwiftUI

/// Semantic design tokens. Views use these, never raw colors.
/// Direction: neutral graphite surfaces, no gradients, one accent. Artwork brings the color; the chrome stays quiet.
enum Theme {
    enum Palette {
        static let background = Color(hex: 0x0C0C0E)
        static let surface = Color(hex: 0x141417)      // sheets
        static let card = Color(hex: 0x18181B)
        static let cardHover = Color(hex: 0x1F1F23)
        static let elevated = Color(hex: 0x232328)     // icon tiles, secondary buttons, inputs
        static let border = Color.white.opacity(0.08)
        static let borderStrong = Color.white.opacity(0.16)
        static let hoverRing = Color.white.opacity(0.5)
        static let textPrimary = Color(hex: 0xF4F4F5)  // 17:1 on background
        static let textSecondary = Color(hex: 0xA1A1AA) // 7.6:1 on card
        static let textTertiary = Color(hex: 0x71717A)
        static let accent = Color(hex: 0x4D8EFF)       // selection, toggles, links (the only hue in the chrome)
        static let cta = Color(hex: 0xF4F4F5)          // primary buttons: light fill, dark label
        static let onCTA = Color(hex: 0x0C0C0E)
        static let success = Color(hex: 0x30D158)
        static let warning = Color(hex: 0xFFB340)
        static let destructive = Color(hex: 0xFF453A)
        static let favorite = Color(hex: 0xFF5C6C)
        static let segmentSelected = Color(hex: 0x3A3A40)   // selected segment in a segmented picker
        static let elevatedHover = Color(hex: 0x2A2A30)     // secondary button hover
        static let tierGood = Color(hex: 0x86D96B)          // CompatTier.good
        static let tierPoor = Color(hex: 0xFF8A3D)          // CompatTier.poor
        static let successTint = Color(hex: 0x30D158, opacity: 0.14)   // "Recommended", discount chip background (text: success)
        static func edge(_ c: Color) -> Color { c.opacity(0.35) }      // warning/destructive notice border
    }

    enum Layout {
        static let railWidth: CGFloat = 80
        static let toolbarHeight: CGFloat = 52
        static let pageInsetX: CGFloat = 48      // Add Game, Stores, Discover, Settings
        static let libraryInsetX: CGFloat = 32   // Library and the game page
        static let pageTitleTop: CGFloat = 52    // above the large page title (toolbar height)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    enum Motion {
        static let quick = Animation.easeOut(duration: 0.15)
        static let standard = Animation.spring(response: 0.3, dampingFraction: 0.9)
    }

    /// SF Pro at the platform's own widths: hierarchy from size and weight, not decoration.
    enum Font {
        static let display = SwiftUI.Font.system(size: 30, weight: .bold)
        static let title = SwiftUI.Font.system(size: 20, weight: .semibold)
        static let section = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let cardTitle = SwiftUI.Font.system(size: 13, weight: .medium)
        static let body = SwiftUI.Font.system(size: 13)
        static let caption = SwiftUI.Font.system(size: 12)
        static let mono = SwiftUI.Font.system(size: 12, design: .monospaced)
        static let stat = SwiftUI.Font.system(size: 17, weight: .semibold)       // Discover's large tile title
        static let statSmall = SwiftUI.Font.system(size: 15, weight: .semibold)  // store name, price, tier label
        static let scoreHero = SwiftUI.Font.system(size: 44, weight: .bold)      // game page score
        static let scoreStage = SwiftUI.Font.system(size: 24, weight: .bold)     // library stage score
        static let micro = SwiftUI.Font.system(size: 11, weight: .medium)        // rail labels, counters, tier scale labels
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Primary call-to-action (one per screen): light fill, dark label.
struct PrimaryButtonStyle: ButtonStyle {
    var role: ButtonRole?
    var height: CGFloat = 40
    var horizontalPadding: CGFloat = Theme.Spacing.lg
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let destructive = role == .destructive
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(destructive ? Color.white : Theme.Palette.onCTA)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background((destructive ? Theme.Palette.destructive : Theme.Palette.cta).opacity(configuration.isPressed ? 0.8 : (hovering ? 0.88 : 1)),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(Theme.Motion.quick, value: hovering)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 40
    var horizontalPadding: CGFloat = Theme.Spacing.md
    var foreground: Color = Theme.Palette.textPrimary
    var weight: SwiftUI.Font.Weight = .medium
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: weight))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(configuration.isPressed ? Theme.Palette.cardHover : (hovering ? Theme.Palette.elevatedHover : Theme.Palette.elevated),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.border))
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(Theme.Motion.quick, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Rounded panel used for grouped content.
struct Panel<Content: View>: View {
    var fillsHeight = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) { content }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Font.section)
            .foregroundStyle(Theme.Palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}
