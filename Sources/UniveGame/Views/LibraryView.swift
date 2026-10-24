import SwiftUI

/// v2 library: source chips and search on top, a stage for the picked game, then shelves sorted by
/// how well the games run on this Mac.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale
    @State private var path: [String] = []
    @State private var stageID: String?
    @FocusState private var shelvesFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: String.self) { id in
                    GameDetailView(itemID: id)
                        .navigationBarBackButtonHidden(true)
                }
        }
        .onAppear {
            // macOS hands the first text field (search) focus on launch; start on the shelves instead.
            DispatchQueue.main.async { shelvesFocused = true }
            if let id = model.pendingDetailID {
                model.pendingDetailID = nil
                stageID = id
                path = [id]
            }
        }
        .onChange(of: model.libraryReset) { _, _ in path = [] }
        .defaultFocus($shelvesFocused, true)
    }

    private var filter: LibraryFilter {
        if case .library(let f) = model.selection ?? .library(.all) { return f }
        return .all
    }

    @ViewBuilder private var root: some View {
        if model.items.isEmpty {
            EmptyLibraryView()
        } else {
            VStack(spacing: 0) {
                topBar
                let shelves = makeShelves()
                if shelves.isEmpty {
                    noResults
                } else {
                    content(shelves)
                }
            }
            .background(Theme.Palette.background)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        @Bindable var model = model
        return TopBar {
            FilterChip(title: L("library.chip.all"), count: model.count(for: .all), isSelected: filter == .all) {
                select(.all)
            }
            .keyboardShortcut("1", modifiers: .command)
            ForEach(Array(model.visibleSources.enumerated()), id: \.element) { i, source in
                let chip = FilterChip(title: source == .custom ? L("source.custom") : source.displayName,
                                      count: model.count(for: .source(source)),
                                      isSelected: filter == .source(source)) { select(.source(source)) }
                if i < 3 { chip.keyboardShortcut(KeyEquivalent(Character("\(i + 2)")), modifiers: .command) } else { chip }
            }
            ForEach(model.collectionNames, id: \.self) { name in
                FilterChip(title: name, count: model.count(for: .collection(name)), isSelected: filter == .collection(name)) {
                    select(.collection(name))
                }
                .contextMenu {
                    Button(L("collections.delete"), systemImage: "trash", role: .destructive) { model.removeCollection(name) }
                }
            }
            Spacer(minLength: Theme.Spacing.md)
            if let progress = model.bulkAnalysis {
                HStack(spacing: 6) {
                    ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                        .progressViewStyle(.linear)
                        .frame(width: 70).tint(Theme.Palette.accent)
                    Text(L("compat.progress", progress.done, progress.total))
                        .font(Theme.Font.caption).monospacedDigit().foregroundStyle(Theme.Palette.textSecondary)
                }
                .help(L("compat.cancelAll"))
            }
            libraryMenu
            SearchPill(text: $model.searchText, prompt: L("library.search.v2"))
        }
    }

    private func select(_ f: LibraryFilter) {
        model.selection = .library(f)
        path = []
    }

    /// Sort order inside shelves, analyze-all and refresh: optional in the design, kept from v1.
    private var libraryMenu: some View {
        @Bindable var model = model
        return Menu {
            Picker(L("library.sort"), selection: $model.sort) {
                Text(L("sort.title")).tag(LibrarySort.title)
                Text(L("sort.lastPlayed")).tag(LibrarySort.lastPlayed)
                Text(L("sort.playTime")).tag(LibrarySort.playTime)
                Text(L("sort.compatibility")).tag(LibrarySort.compatibility)
            }
            .pickerStyle(.inline)
            Divider()
            Toggle(L("library.onlyInstalled"), isOn: $model.onlyInstalled)
            Toggle(L("library.onlyFavorites"), isOn: $model.onlyFavorites)
            Menu(L("library.hideStores")) {
                ForEach(model.populatedSources, id: \.self) { source in
                    Toggle(source == .custom ? L("source.custom") : source.displayName,
                           isOn: Binding(get: { model.hiddenSources.contains(source.key) }, set: { _ in model.toggleHidden(source) }))
                }
            }
            if !model.collectionNames.isEmpty {
                Menu(L("collections.manage")) {
                    ForEach(model.collectionNames, id: \.self) { name in
                        Button(L("collections.deleteNamed", name), role: .destructive) { model.removeCollection(name) }
                    }
                }
            }
            Divider()
            if model.bulkAnalysis == nil {
                Button(L("compat.analyzeAll"), systemImage: "waveform.badge.magnifyingglass") { Task { await model.analyzeAll() } }
            } else {
                Button(L("compat.cancelAll"), systemImage: "stop.circle") { model.cancelBulkAnalysis() }
            }
            Divider()
            Button(L("menu.refresh"), systemImage: "arrow.clockwise") { Task { await model.refreshStores() } }
                .disabled(model.refreshing)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .hoverFill(.clear, hover: Theme.Palette.card, cornerRadius: Theme.Radius.md)
        .help(L("library.sort"))
        .accessibilityLabel(L("library.sort"))
    }

    private var noResults: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("empty.search.title")).font(Theme.Font.section).foregroundStyle(Theme.Palette.textPrimary)
            if !model.searchText.isEmpty {
                Text(L("empty.search.message", model.searchText)).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Layout.libraryInsetX)
        .padding(.top, Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Shelves

    struct Shelf: Identifiable {
        let key: String
        let items: [LibraryItem]
        var id: String { key }
    }

    private func makeShelves() -> [Shelf] {
        let list = model.visibleItems(for: filter, locale: locale)
        let byScore: (LibraryItem, LibraryItem) -> Bool = { a, b in
            (model.compatReport(for: a)?.score ?? -1) > (model.compatReport(for: b)?.score ?? -1)
        }
        let customOrder = model.sort != .title
        func tier(_ item: LibraryItem) -> CompatTier { model.compatReport(for: item)?.tier ?? .unknown }

        var ready = list.filter(\.isInstalled)
        if !customOrder {
            ready.sort {
                let a = $0.lastPlayed ?? .distantPast, b = $1.lastPlayed ?? .distantPast
                if a != b { return a > b }
                return $0.title.compare($1.title, options: [.caseInsensitive, .numeric], locale: locale) == .orderedAscending
            }
        }
        let notInstalled = list.filter { !$0.isInstalled }
        var install = notInstalled.filter { [.excellent, .good].contains(tier($0)) }
        var hard = notInstalled.filter { [.playable, .poor, .broken].contains(tier($0)) }
        let unknown = notInstalled.filter { tier($0) == .unknown }
        if !customOrder {
            install.sort(by: byScore)
            hard.sort(by: byScore)
        }
        return [Shelf(key: "shelf.ready", items: ready), Shelf(key: "shelf.install", items: install),
                Shelf(key: "shelf.hard", items: hard), Shelf(key: "shelf.unknown", items: unknown)]
            .filter { !$0.items.isEmpty }
    }

    private func content(_ shelves: [Shelf]) -> some View {
        let all = shelves.flatMap(\.items)
        let current = all.first { $0.id == stageID } ?? shelves[0].items[0]
        let shelfKey = shelves.first { $0.items.contains { $0.id == current.id } }?.key ?? shelves[0].key
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    LibraryStage(item: current, shelfTitle: L(shelfKey)) { open(current) }
                    ForEach(shelves) { shelf in
                        shelfView(shelf, selectedID: current.id)
                    }
                }
                .padding(.top, Theme.Spacing.md)
                .padding(.horizontal, Theme.Layout.libraryInsetX)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.never)
            .focusable()
            .focusEffectDisabled()
            .focused($shelvesFocused)
            .onKeyPress(.leftArrow) { move(in: shelves, current: current, dx: -1, dy: 0, proxy: proxy) }
            .onKeyPress(.rightArrow) { move(in: shelves, current: current, dx: 1, dy: 0, proxy: proxy) }
            .onKeyPress(.upArrow) { move(in: shelves, current: current, dx: 0, dy: -1, proxy: proxy) }
            .onKeyPress(.downArrow) { move(in: shelves, current: current, dx: 0, dy: 1, proxy: proxy) }
            .onKeyPress(.return) { open(current); return .handled }
        }
    }

    private func shelfView(_ shelf: Shelf, selectedID: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L(shelf.key)).font(Theme.Font.section).foregroundStyle(Theme.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("\(shelf.items.count)").font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).monospacedDigit()
                Text("· \(L(shelf.key + ".hint"))").font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(Array(shelf.items.enumerated()), id: \.element.id) { i, item in
                        ShelfCover(item: item, isSelected: item.id == selectedID, delay: 0.2 + Double(min(i, 12)) * 0.05,
                                   onSelect: { stageID = item.id; shelvesFocused = true },
                                   onOpen: { stageID = item.id; open(item) })
                            .id(item.id)
                    }
                }
                // Room for the hover lift and the selection ring.
                .padding(.vertical, 6)
                .padding(.horizontal, 5)
            }
            .scrollIndicators(.never)
            .padding(.horizontal, -5)
            .padding(.vertical, -6)
        }
    }

    private func move(in shelves: [Shelf], current: LibraryItem, dx: Int, dy: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        guard let s = shelves.firstIndex(where: { $0.items.contains { $0.id == current.id } }),
              let i = shelves[s].items.firstIndex(where: { $0.id == current.id }) else { return .ignored }
        let ns = min(max(s + dy, 0), shelves.count - 1)
        let ni = dy == 0 ? min(max(i + dx, 0), shelves[ns].items.count - 1) : min(i, shelves[ns].items.count - 1)
        let next = shelves[ns].items[ni]
        stageID = next.id
        withAnimation(Theme.Motion.quick) { proxy.scrollTo(next.id) }
        return .handled
    }

    private func open(_ item: LibraryItem) {
        path = [item.id]
    }
}

/// Shown when there isn't a single game yet (no store connected, nothing added).
struct EmptyLibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.windowDropTargeted) private var dropTargeted

    var body: some View {
        VStack(spacing: 40) {
            HStack(alignment: .bottom, spacing: 20) {
                GhostCover(width: 120, height: 180, bobDelay: 0).rotationEffect(.degrees(-6))
                GhostCover(width: 140, height: 210, showsPlus: true, bobDelay: 0.65).offset(y: -16)
                GhostCover(width: 120, height: 180, bobDelay: 1.3).rotationEffect(.degrees(6))
            }
            .frame(height: 230, alignment: .bottom)
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(L("empty.v2.title"))
                    .font(Theme.Font.display).foregroundStyle(Theme.Palette.textPrimary)
                    .enterOnAppear()
                Text(L("empty.v2.body"))
                    .font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .enterOnAppear(delay: 0.08)
                HStack(spacing: 8) {
                    Button(L("empty.v2.connect")) { model.selection = .stores }
                        .buttonStyle(PrimaryButtonStyle())
                    Button(L("sidebar.addGame")) { model.selection = .addGame }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 12)
                .enterOnAppear(delay: 0.16)
            }
            .frame(maxWidth: 460)

            DropHint(isTargeted: dropTargeted) { dropText }
                .enterOnAppear(delay: 0.24)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
    }

    /// "Or drag an .exe …" with the extension set in mono.
    private var dropText: Text {
        let full = L("empty.v2.drop")
        guard let range = full.range(of: ".exe") else {
            return Text(full).font(Theme.Font.body).foregroundColor(Theme.Palette.textSecondary)
        }
        return Text(full[..<range.lowerBound]).font(Theme.Font.body).foregroundColor(Theme.Palette.textSecondary)
            + Text(".exe").font(Theme.Font.mono).foregroundColor(Theme.Palette.textPrimary)
            + Text(full[range.upperBound...]).font(Theme.Font.body).foregroundColor(Theme.Palette.textSecondary)
    }
}
