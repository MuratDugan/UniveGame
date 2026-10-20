import SwiftUI

/// The 80 pt icon rail that replaces the v1 sidebar. The window's traffic lights sit in its top 52 pt.
struct RailView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Theme.Layout.toolbarHeight)
            VStack(spacing: 6) {
                RailItem(title: L("rail.library"), symbol: "books.vertical", isSelected: isLibrary) {
                    if !isLibrary { model.selection = .library(.all) } else { model.libraryReset &+= 1 }
                }
                RailItem(title: L("rail.discover"), symbol: "safari", isSelected: model.selection == .discover) {
                    model.selection = .discover
                }
                RailItem(title: L("rail.stores"), symbol: "link", isSelected: model.selection == .stores) {
                    model.selection = .stores
                }
                RailItem(title: L("rail.add"), symbol: "plus", isSelected: model.selection == .addGame) {
                    model.selection = .addGame
                }
            }
            .padding(.top, Theme.Spacing.md)
            Spacer(minLength: 0)
            settingsButton
            engineStatus
        }
        .frame(width: Theme.Layout.railWidth)
        .frame(maxHeight: .infinity)
        .background(Theme.Palette.background)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.Palette.border).frame(width: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("rail.a11y"))
    }

    private var isLibrary: Bool {
        if case .library = model.selection ?? .library(.all) { return true }
        return false
    }

    private var settingsButton: some View {
        let on = model.selection == .settings
        return RailIconButton(symbol: "gearshape", isSelected: on) { model.selection = .settings }
            .help(L("rail.settings"))
            .accessibilityLabel(L("rail.settings"))
    }

    private var engineStatus: some View {
        let ready = model.hasEngine || model.isDemo
        return VStack(spacing: 4) {
            Group {
                if ready {
                    Circle().fill(Theme.Palette.success).frame(width: 8, height: 8).pulsing()
                } else {
                    Circle().fill(Theme.Palette.warning).frame(width: 8, height: 8)
                }
            }
            Text(L("rail.engine")).font(.system(size: 10)).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(height: 56)
        .help(ready ? L("engine.ready") : L("engine.missing"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ready ? L("engine.ready") : L("engine.missing"))
    }
}

struct RailItem: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : (hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary))
                    .frame(height: 20)
                Text(title).font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected || hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            .frame(width: 64, height: 56)
            .background(isSelected || hovering ? Theme.Palette.card : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
        .animation(Theme.Motion.quick, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Icon-only rail button (settings).
struct RailIconButton: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18))
                .foregroundStyle(isSelected ? Theme.Palette.accent : (hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary))
                .frame(width: 44, height: 44)
                .background(isSelected || hovering ? Theme.Palette.card : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
