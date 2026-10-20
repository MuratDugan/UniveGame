import SwiftUI

// MARK: Add Game

/// One of the three ways to add a game.
struct MethodTile: View {
    let title: String
    let detail: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                    Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(isSelected ? Theme.Palette.card : (hovering ? Theme.Palette.cardHover : Theme.Palette.surface),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
        .animation(Theme.Motion.quick, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Installer

/// The installer's three steps, with a connecting line that grows as steps finish.
struct StepRail: View {
    struct Step { let title: String; let detail: String }
    let steps: [Step]
    let current: Int
    var failed = false
    @Environment(Localizer.self) private var L

    private let spacing: CGFloat = 36
    private let circle: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 14) {
                    marker(i)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(i <= current ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        Text(step.detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(.top, 4)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(i == current ? .isSelected : [])
                .accessibilityValue(i == current ? L("installer.a11y.step", "\(i + 1)", "\(steps.count)") : "")
            }
        }
        .background(alignment: .topLeading) { line }
        .accessibilityElement(children: .contain)
    }

    /// From the first circle's centre to the last one's, 2 pt wide.
    private var line: some View {
        GeometryReader { geo in
            let rowHeight = (geo.size.height - spacing * CGFloat(steps.count - 1)) / CGFloat(steps.count)
            let total = (rowHeight + spacing) * CGFloat(steps.count - 1)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.Palette.elevated).frame(width: 2, height: total)
                RoundedRectangle(cornerRadius: 2).fill(Theme.Palette.accent)
                    .frame(width: 2, height: total * CGFloat(min(current, steps.count - 1)) / CGFloat(steps.count - 1))
                    .frame(height: total, alignment: .top)
                    .animation(Theme.Motion.valueChange, value: current)
            }
            .offset(x: circle / 2 - 1, y: circle / 2)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func marker(_ i: Int) -> some View {
        let done = i < current
        let now = i == current
        ZStack {
            Circle()
                .fill(done ? Theme.Palette.success : (now && failed ? Theme.Palette.destructive : Theme.Palette.background))
            Circle()
                .strokeBorder(done ? Theme.Palette.success : (now ? (failed ? Theme.Palette.destructive : Theme.Palette.accent) : Theme.Palette.borderStrong),
                              lineWidth: 2)
            if done {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Palette.onCTA)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if now && failed {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Palette.onCTA)
            } else {
                Text("\(i + 1)").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(now ? Theme.Palette.accent : Theme.Palette.textSecondary)
            }
        }
        .frame(width: circle, height: circle)
        .animation(.easeOut(duration: 0.3), value: current)
    }
}

/// A program the installer added: radio, name, "Recommended", Windows path, size.
struct ProgramChoiceRow: View {
    let name: String
    let path: String
    let size: String
    let recommended: Bool
    let isSelected: Bool
    let action: () -> Void
    @Environment(Localizer.self) private var L
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(isSelected ? Theme.Palette.accent : Color.white.opacity(0.3), lineWidth: isSelected ? 5 : 2)
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                        if recommended {
                            Text(L("installer.recommended"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.Palette.success)
                                .padding(.horizontal, 8)
                                .frame(height: 20)
                                .background(Theme.Palette.successTint, in: Capsule())
                        }
                    }
                    Text(path).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Text(size).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).monospacedDigit()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(hovering ? Theme.Palette.cardHover : Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
        .animation(Theme.Motion.quick, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Empty library

/// Dashed placeholder cover that floats gently.
struct GhostCover: View {
    let width: CGFloat
    let height: CGFloat
    var showsPlus = false
    var bobDelay: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.md)
            .fill(showsPlus ? Theme.Palette.card : Theme.Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.Palette.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .overlay {
                if showsPlus {
                    Image(systemName: "plus").font(.system(size: 28)).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .frame(width: width, height: height)
            .bobbing(delay: bobDelay)
    }
}

/// Dashed hint box whose edge breathes between borderStrong and accent; solid accent while a file is over the window.
struct DropHint<Label: View>: View {
    var isTargeted: Bool
    var symbol = "arrow.down.to.line"
    @ViewBuilder var label: Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(Theme.Palette.textSecondary)
            label
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(isTargeted ? Theme.Palette.card : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .strokeBorder(edge, style: StrokeStyle(lineWidth: 1, dash: isTargeted ? [] : [4, 3])))
        .animation(Theme.Motion.quick, value: isTargeted)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Theme.Motion.edgePulse) { lit = true }
        }
    }

    private var edge: Color {
        if isTargeted { return Theme.Palette.accent }
        return lit ? Theme.Palette.accent.opacity(0.6) : Theme.Palette.borderStrong
    }
}
