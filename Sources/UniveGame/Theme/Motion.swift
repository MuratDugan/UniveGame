import SwiftUI

extension Theme.Motion {
    private static func curve(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0.7, 0.2, 1, duration: duration)
    }
    static let enter = curve(0.55)
    static let fill = curve(1.0)
    static let valueChange = curve(0.6)
    static let zoom = curve(0.5)
    static let pop = curve(0.5)
    static let crossfade = Animation.easeOut(duration: 0.4)
    static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    static let indeterminate = Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: false)
    static let bob = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let edgePulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    static let stagger: Double = 0.06
}

// MARK: Enter: fade + rise once on appear (.ug-in)

struct EnterOnAppear: ViewModifier {
    var delay: Double = 0
    var distance: CGFloat = 10
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : distance)
            .onAppear {
                guard !reduceMotion, !shown else { return }
                withAnimation(Theme.Motion.enter.delay(delay)) { shown = true }
            }
    }
}

// MARK: Grow: scaleX 0 → 1 from the leading edge (.ug-grow)

struct GrowOnAppear: ViewModifier {
    var delay: Double = 0
    var animation: Animation = Theme.Motion.fill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: grown || reduceMotion ? 1 : 0, y: 1, anchor: .leading)
            .onAppear {
                guard !reduceMotion, !grown else { return }
                withAnimation(animation.delay(delay)) { grown = true }
            }
    }
}

// MARK: Pop: scale 0.94 → 1 + fade (.ug-pop)

struct PopOnAppear: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            .onAppear {
                guard !reduceMotion, !shown else { return }
                withAnimation(Theme.Motion.pop.delay(delay)) { shown = true }
            }
    }
}

// MARK: Loops

struct Pulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(dim ? 0.4 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Theme.Motion.pulse) { dim = true }
            }
    }
}

struct Bob: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -8 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Theme.Motion.bob.delay(delay)) { up = true }
            }
    }
}

extension View {
    func enterOnAppear(delay: Double = 0, distance: CGFloat = 10) -> some View { modifier(EnterOnAppear(delay: delay, distance: distance)) }
    /// Index-based stagger: `.enter(index: i)` = delay base + i × step.
    func enter(index: Int, base: Double = 0, step: Double = Theme.Motion.stagger) -> some View {
        modifier(EnterOnAppear(delay: base + Double(index) * step))
    }
    func growOnAppear(delay: Double = 0, animation: Animation = Theme.Motion.fill) -> some View { modifier(GrowOnAppear(delay: delay, animation: animation)) }
    func popOnAppear(delay: Double = 0) -> some View { modifier(PopOnAppear(delay: delay)) }
    func pulsing() -> some View { modifier(Pulse()) }
    func bobbing(delay: Double = 0) -> some View { modifier(Bob(delay: delay)) }
}

// MARK: Indeterminate bar (.ug-slide)

/// A 34%-wide accent segment sliding across an elevated track. Used where progress can't be known (an external installer, store sync).
struct IndeterminateBar: View {
    var height: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travelling = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.34
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.elevated)
                Capsule().fill(Theme.Palette.accent)
                    .frame(width: w)
                    .offset(x: reduceMotion ? (geo.size.width - w) / 2 : (travelling ? geo.size.width : -w))
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Theme.Motion.indeterminate) { travelling = true }
        }
        .accessibilityElement()
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: Cover hover (.ug-cover / .ug-pick:hover)

/// Hover on a cover: lift 4 pt, scale 1.02, 1 pt hover ring, cover shadow. Reduced motion keeps the ring only.
struct CoverHoverEffect: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.md
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func body(content: Content) -> some View {
        let lift = hovering && !reduceMotion
        content
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(hovering ? Theme.Palette.hoverRing : Theme.Palette.border, lineWidth: 1))
            .shadow(color: .black.opacity(hovering ? 0.4 : 0), radius: 12, y: 6)   // shadow-cover-hover: 0 6 24 → radius = blur/2
            .scaleEffect(lift ? 1.02 : 1)
            .offset(y: lift ? -4 : 0)
            .animation(Theme.Motion.quick, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Accent selection ring drawn 2 pt outside the shape with a 2 pt gap (CSS: 0 0 0 2px bg, 0 0 0 4px accent).
struct SelectionRing: ViewModifier {
    var isOn: Bool
    var cornerRadius: CGFloat = Theme.Radius.md

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius + 4)
                .strokeBorder(Theme.Palette.accent, lineWidth: 2)
                .padding(-4)
                .opacity(isOn ? 1 : 0)
                .animation(Theme.Motion.quick, value: isOn)
        )
    }
}

extension View {
    func coverHover(cornerRadius: CGFloat = Theme.Radius.md) -> some View { modifier(CoverHoverEffect(cornerRadius: cornerRadius)) }
    func selectionRing(_ isOn: Bool, cornerRadius: CGFloat = Theme.Radius.md) -> some View { modifier(SelectionRing(isOn: isOn, cornerRadius: cornerRadius)) }
}

// MARK: Hover fill for rows/tiles (.ug-tile, .ug-rail, .ug-chip, .ug-opt)

struct HoverFill: ViewModifier {
    var normal: Color
    var hover: Color
    var cornerRadius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(hovering ? hover : normal, in: RoundedRectangle(cornerRadius: cornerRadius))
            .animation(Theme.Motion.quick, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverFill(_ normal: Color, hover: Color, cornerRadius: CGFloat) -> some View {
        modifier(HoverFill(normal: normal, hover: hover, cornerRadius: cornerRadius))
    }
}
