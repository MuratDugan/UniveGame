import SwiftUI

/// The one problem that stops a game, on the game page.
struct NoticeBanner: View {
    enum Kind { case warning, destructive }
    enum Action {
        case primary(String, () -> Void)
        case link(String, URL)
    }

    let kind: Kind
    let title: String
    let message: String
    var action: Action?

    private var color: Color { kind == .warning ? Theme.Palette.warning : Theme.Palette.destructive }
    private var symbol: String { kind == .warning ? "exclamationmark.triangle.fill" : "xmark.octagon.fill" }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                Text(message).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            switch action {
            case .primary(let label, let run)?:
                Button(label, action: run)
                    .buttonStyle(PrimaryButtonStyle(height: 32, horizontalPadding: 20))
            case .link(let label, let url)?:
                Link(label, destination: url)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.accent)
            case nil:
                EmptyView()
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.edge(color)))
        .accessibilityElement(children: .contain)
    }
}
