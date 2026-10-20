import AppKit
import SwiftUI

/// v2 Discover: Steam's featured list or a search, as a bento grid with Mac scores where we have them.
/// Buying happens on Steam's own site or app.
struct DiscoverView: View {
    enum Chip: String, CaseIterable { case featured, deals, macGreat, new }

    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale

    @State private var query = ""
    @State private var chip: Chip = .featured
    @State private var listings: [StoreListing] = []
    @State private var loading = false
    @State private var failed = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: L("sidebar.discover"), subtitle: L("discover.v2.subtitle")) {
                    SearchPill(text: $query, prompt: L("discover.search"), height: 32, showsShortcut: false)
                }
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Chip.allCases, id: \.self) { c in
                            FilterChip(title: L("discover.chip.\(c.rawValue)"), isSelected: chip == c) { chip = c }
                        }
                    }
                    .enterOnAppear(delay: 0.06)
                }
                grid
            }
            .padding(.top, Theme.Layout.pageTitleTop)
            .padding(.horizontal, Theme.Layout.pageInsetX)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollIndicators(.automatic)
        .background(Theme.Palette.background)
        .onChange(of: query) { _, _ in debounceSearch() }
        .task(id: locale.identifier) { load() }
    }

    @ViewBuilder private var grid: some View {
        let shown = filtered
        if loading && listings.isEmpty {
            BentoLayout(spacing: 16, rowHeight: 210) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Palette.card)
                        .pulsing()
                        .layoutValue(key: BentoSpan.self, value: BentoSpan.kind(for: i))
                }
            }
            .accessibilityHidden(true)
        } else if failed {
            EmptyStateView(symbol: "wifi.exclamationmark", title: L("discover.error.title"), message: L("discover.error.message"),
                           actionTitle: L("common.retry")) { load() }
        } else if shown.isEmpty {
            EmptyStateView(symbol: "magnifyingglass", title: L("empty.search.title"),
                           message: query.isEmpty ? L("empty.filter.message") : L("empty.search.message", query))
        } else {
            BentoLayout(spacing: 16, rowHeight: 210) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, listing in
                    let kind = BentoSpan.kind(for: i)
                    BentoTile(listing: listing, isLarge: kind == .large, report: model.compatReport(steamAppID: listing.id))
                        .enter(index: min(i, 12), base: 0.12, step: 0.05)
                        .layoutValue(key: BentoSpan.self, value: kind)
                        .transition(.opacity)
                }
            }
            .id(chip.rawValue + query)
            .animation(Theme.Motion.crossfade, value: chip)
        }
    }

    private var filtered: [StoreListing] {
        guard query.trimmingCharacters(in: .whitespaces).isEmpty else { return listings }
        switch chip {
        case .featured: return listings
        case .deals: return listings.filter { $0.discountPercent > 0 }
        case .macGreat: return listings.filter { model.compatReport(steamAppID: $0.id)?.tier == .excellent }
        case .new: return listings.filter(\.isNew)
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            load()
        }
    }

    private func load() {
        let term = query.trimmingCharacters(in: .whitespaces)
        let api = SteamStoreAPI(appLanguage: locale.language.languageCode?.identifier ?? "en")
        loading = true
        failed = false
        Task {
            do {
                let result = term.isEmpty ? try await api.featured() : try await api.search(term)
                guard term == query.trimmingCharacters(in: .whitespaces) else { return }
                listings = result
            } catch {
                if !(error is CancellationError) { failed = true }
            }
            loading = false
        }
    }
}

// MARK: Bento grid

enum BentoSpan: LayoutValueKey {
    enum Kind { case large, wide, normal }
    static let defaultValue: Kind = .normal

    /// Every eight tiles: one 2×2, four 1×1, one 2×1, two 1×1.
    static func kind(for index: Int) -> Kind {
        switch index % 8 {
        case 0: .large
        case 5: .wide
        default: .normal
        }
    }
}

/// Four columns with fixed-height rows, packed densely; two columns (large tiles 2×1) when narrow.
struct BentoLayout: Layout {
    var spacing: CGFloat
    var rowHeight: CGFloat

    private func columns(for width: CGFloat) -> Int { width < 820 ? 2 : 4 }

    private func placements(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        let cols = columns(for: width)
        let colWidth = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
        var occupied: [[Bool]] = []
        var frames: [CGRect] = []
        func free(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
            guard c + w <= cols else { return false }
            for rr in r..<(r + h) {
                while occupied.count <= rr { occupied.append(Array(repeating: false, count: cols)) }
                for cc in c..<(c + w) where occupied[rr][cc] { return false }
            }
            return true
        }
        for view in subviews {
            let (w, h): (Int, Int) = switch view[BentoSpan.self] {
            case .large: cols == 4 ? (2, 2) : (2, 1)
            case .wide: (2, 1)
            case .normal: (1, 1)
            }
            var r = 0, placed = false
            while !placed {
                for c in 0..<cols where free(r, c, w, h) {
                    for rr in r..<(r + h) { for cc in c..<(c + w) { occupied[rr][cc] = true } }
                    frames.append(CGRect(x: CGFloat(c) * (colWidth + spacing), y: CGFloat(r) * (rowHeight + spacing),
                                         width: CGFloat(w) * colWidth + CGFloat(w - 1) * spacing,
                                         height: CGFloat(h) * rowHeight + CGFloat(h - 1) * spacing))
                    placed = true
                    break
                }
                r += 1
            }
        }
        let rows = occupied.lastIndex { $0.contains(true) }.map { $0 + 1 } ?? 0
        return (frames, rows == 0 ? 0 : CGFloat(rows) * rowHeight + CGFloat(rows - 1) * spacing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 900
        return CGSize(width: width, height: placements(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = placements(width: bounds.width, subviews: subviews).frames
        for (view, frame) in zip(subviews, frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}

private struct BentoTile: View {
    let listing: StoreListing
    let isLarge: Bool
    let report: CompatReport?
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        Button { NSWorkspace.shared.open(listing.storeURL) } label: {
            VStack(spacing: 0) {
                artwork
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(hovering && !reduceMotion ? 1.04 : 1)
                    .animation(Theme.Motion.zoom, value: hovering)
                    .clipped()
                strip
            }
            .background(Theme.Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(hovering ? Theme.Palette.hoverRing : Theme.Palette.border))
            .animation(Theme.Motion.quick, value: hovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(L("discover.openInSteam"))
        .accessibilityLabel(a11yLabel)
    }

    @ViewBuilder private var artwork: some View {
        if isLarge, let large = listing.largeArtworkURL {
            AsyncImage(url: large) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else if case .failure = phase { CoverArt(url: listing.artworkURL, title: listing.name) }
                else { Theme.Palette.elevated }
            }
        } else {
            CoverArt(url: listing.artworkURL, title: listing.name)
        }
    }

    private var strip: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(listing.name)
                    .font(isLarge ? Theme.Font.stat : .system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                if let report, report.tier != .unknown {
                    HStack(spacing: 4) {
                        Image(systemName: report.tier.symbol).font(.system(size: 11)).foregroundStyle(report.tier.color)
                        Text("\(report.score) · \(L("compat.tier.\(report.tier.rawValue)"))").monospacedDigit()
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if listing.discountPercent > 0 {
                Text("-\(listing.discountPercent)%")
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(Theme.Palette.success)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Theme.Palette.successTint, in: Capsule())
            }
            VStack(alignment: .trailing, spacing: 0) {
                if let original = listing.formattedOriginalPrice(locale: locale) {
                    Text(original).font(.system(size: 11)).strikethrough().foregroundStyle(Theme.Palette.textSecondary).monospacedDigit()
                }
                Text(listing.isFree ? L("discover.free") : (listing.formattedPrice(locale: locale) ?? "—"))
                    .font(Theme.Font.statSmall).foregroundStyle(Theme.Palette.textPrimary).monospacedDigit()
            }
        }
        .padding(.vertical, isLarge ? 16 : 12)
        .padding(.horizontal, isLarge ? 20 : 14)
        .background(Theme.Palette.card)
    }

    private var a11yLabel: String {
        var parts = [listing.name]
        if let report, report.tier != .unknown { parts.append("\(report.score), \(L("compat.tier.\(report.tier.rawValue)"))") }
        parts.append(listing.isFree ? L("discover.free") : (listing.formattedPrice(locale: locale) ?? ""))
        return parts.joined(separator: ", ")
    }
}
