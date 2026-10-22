import AppKit
import SwiftUI

/// Open-source status, no warranty and limits of liability. Shown once before first use (accept, or
/// decline and quit) and again from Settings → About, where it's read-only.
struct DisclaimerView: View {
    enum Mode { case firstLaunch, review }

    let mode: Mode
    /// Height of the window the sheet is attached to; the sheet never grows past it.
    var windowHeight: CGFloat = 800
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.dismiss) private var dismiss

    static let sections: [(key: String, symbol: String)] = [
        ("os", "chevron.left.forwardslash.chevron.right"),
        ("apple", "square.stack.3d.up"),
        ("warranty", "exclamationmark.shield"),
        ("liability", "scalemass"),
        ("accounts", "person.badge.shield.checkmark"),
        ("games", "gamecontroller"),
        ("trademarks", "c.circle"),
    ]
    static let openSourcePage = URL(string: "https://github.com/MuratDugan/UniveEngine#engines-and-the-manifest")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.lg)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ForEach(Array(Self.sections.enumerated()), id: \.offset) { i, section in
                        sectionView(section.key, symbol: section.symbol)
                            .enter(index: min(i, 6), base: 0.08, step: 0.04)
                    }
                    Link(destination: Self.openSourcePage) {
                        HStack(spacing: 4) {
                            Text(L("disclaimer.more"))
                            Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Palette.accent)
                    }
                    .padding(.leading, 40)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .scrollIndicators(.visible)
            .background(Theme.Palette.background)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Palette.border).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.border).frame(height: 1) }
            footer
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 640, height: min(640, max(420, windowHeight - 100)))
        .background(Theme.Palette.surface)
        .interactiveDismissDisabled(mode == .firstLaunch)
    }

    private var header: some View {
        HStack(alignment: mode == .firstLaunch ? .top : .center, spacing: Theme.Spacing.md) {
            Group {
                if let icon = AppIcon.image {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 56, height: 56).padding(-6)
                } else {
                    Image(systemName: "doc.text").font(.system(size: 20)).foregroundStyle(Theme.Palette.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .firstLaunch ? L("disclaimer.title") : L("disclaimer.reviewTitle"))
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if mode == .firstLaunch {
                    Text(L("disclaimer.subtitle"))
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .enterOnAppear()
    }

    private func sectionView(_ key: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(key == "warranty" || key == "liability" ? Theme.Palette.warning : Theme.Palette.textSecondary)
                .frame(width: 24, height: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("disclaimer.\(key).title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(L("disclaimer.\(key).body"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            switch mode {
            case .firstLaunch:
                Button(L("disclaimer.decline")) { NSApp.terminate(nil) }
                    .buttonStyle(SecondaryButtonStyle(foreground: Theme.Palette.destructive))
                Spacer()
                Button(L("disclaimer.accept")) { model.acceptDisclaimer() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            case .review:
                Label(acceptedLine, systemImage: "checkmark.circle.fill")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .labelStyle(AcceptedLabelStyle())
                Spacer()
                Button(L("common.close")) { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    var acceptedLine: String {
        guard let date = model.disclaimerAcceptedAt else { return "" }
        return L("disclaimer.acceptedOn", date.formatted(Date.FormatStyle(date: .long, time: .shortened).locale(L.locale)))
    }
}

private struct AcceptedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(Theme.Palette.success)
            configuration.title
        }
    }
}
