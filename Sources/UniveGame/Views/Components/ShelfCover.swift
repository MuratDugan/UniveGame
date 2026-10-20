import SwiftUI

/// A cover on a library shelf. Single click picks it for the stage, double click opens the game page.
struct ShelfCover: View {
    let item: LibraryItem
    let isSelected: Bool
    var delay: Double = 0
    let onSelect: () -> Void
    let onOpen: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        let report = model.compatReport(for: item)
        let tier = report?.tier ?? .unknown
        VStack(alignment: .leading, spacing: 8) {
            CoverArt(url: item.coverURL, title: item.title, symbol: item.source.symbol)
                .frame(width: 132, height: 198)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .coverHover()
                .selectionRing(isSelected)
            TierMeter(score: report?.score ?? 0, tier: tier, delay: delay)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(scoreLine(report))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(width: 132, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(count: 1, perform: onSelect)
        .contextMenu { GameActionsMenu(item: item) }
        .help(item.title)
        .enterOnAppear(delay: delay)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel(report))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect() }
        .accessibilityAction(named: Text(L("stage.openPage"))) { onOpen() }
    }

    private func scoreLine(_ report: CompatReport?) -> String {
        guard let report, report.tier != .unknown else { return L("cover.notAnalyzed") }
        return "\(report.score) · \(L("compat.tier.\(report.tier.rawValue)"))"
    }

    private func a11yLabel(_ report: CompatReport?) -> String {
        var parts = [item.title, scoreLine(report)]
        parts.append(item.isInstalled ? L("filter.installed") : L("status.notInstalled"))
        return parts.joined(separator: ", ")
    }
}
