import SwiftUI

/// Large page title for Add Game, Stores, Discover and Settings, with an optional trailing slot
/// aligned to the title's bottom edge.
struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 640, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .enterOnAppear()
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String?) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// The 52 pt bar drawn inside a page (the window's own toolbar is hidden).
struct TopBar<Content: View>: View {
    var leading: CGFloat = Theme.Layout.libraryInsetX
    var trailing: CGFloat = Theme.Spacing.md
    var spacing: CGFloat = 6
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: spacing) { content }
            .padding(.leading, leading)
            .padding(.trailing, trailing)
            .frame(height: Theme.Layout.toolbarHeight)
            .frame(maxWidth: .infinity)
    }
}
