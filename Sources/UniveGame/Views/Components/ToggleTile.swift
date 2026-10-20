import SwiftUI

/// A whole-tile switch for the game page's launch settings grid.
struct ToggleTile: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(Theme.Palette.textPrimary)
                Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(TileToggleStyle())
    }
}

struct TileToggleStyle: ToggleStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label.frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(on ? Theme.Palette.accent : Theme.Palette.elevated)
                    .frame(width: 34, height: 20)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle().fill(on ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                            .frame(width: 16, height: 16)
                            .padding(2)
                    }
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: on)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .background(hovering ? Theme.Palette.cardHover : Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(on ? Theme.Palette.accent.opacity(0.45) : Theme.Palette.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
        .animation(Theme.Motion.quick, value: on)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? Text(verbatim: "1") : Text(verbatim: "0"))
    }
}

/// Key/value rows with hairlines, the game page's left column.
struct FactList: View {
    let facts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(fact.0).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    Spacer(minLength: 8)
                    Text(fact.1).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(fact.1)
                }
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.border).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
