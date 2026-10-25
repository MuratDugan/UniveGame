import UniveEngineKit
import SwiftUI

/// v2 game page: cover, the one action and facts on the left; verdict and launch settings on the right.
struct GameDetailView: View {
    let itemID: String
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let item = model.item(id: itemID) {
                VStack(spacing: 0) {
                    topBar(item)
                    ScrollView {
                        HStack(alignment: .top, spacing: 40) {
                            leftColumn(item).frame(width: 260)
                            rightColumn(item).frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, Theme.Layout.libraryInsetX)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                    .scrollIndicators(.automatic)
                }
            } else {
                EmptyStateView(symbol: "questionmark.square.dashed", title: L("detail.missing.title"), message: L("detail.missing.message"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.background)
    }

    // MARK: Top bar

    private func topBar(_ item: LibraryItem) -> some View {
        TopBar(leading: 24, spacing: 8) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text(L("game.back")).font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 6).padding(.trailing, 10)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverFill(.clear, hover: Theme.Palette.card, cornerRadius: Theme.Radius.md)
            .keyboardShortcut("[", modifiers: .command)
            Spacer()
            Button { model.toggleFavorite(item) } label: {
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isFavorite ? Theme.Palette.favorite : Theme.Palette.textPrimary)
                    .symbolEffect(.bounce, value: reduceMotion ? false : item.isFavorite)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(SecondaryButtonStyle(height: 32, horizontalPadding: 0))
            .help(item.isFavorite ? L("action.unfavorite") : L("action.favorite"))
            .accessibilityLabel(item.isFavorite ? L("action.unfavorite") : L("action.favorite"))
            moreMenu(item)
        }
    }

    private func moreMenu(_ item: LibraryItem) -> some View {
        let profile = Binding<LaunchProfile>(get: { model.profile(for: item) }, set: { model.setProfile($0, for: item) })
        return Menu {
            GameActionsMenu(item: item)
            Divider()
            Toggle(L("launch.verbose"), isOn: profile.verboseLogs)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.border))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help(L("detail.more"))
        .accessibilityLabel(L("detail.more"))
    }

    // MARK: Left column

    private func leftColumn(_ item: LibraryItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            CoverArt(url: item.coverURL, title: item.title, symbol: item.source.symbol)
                .frame(width: 260, height: 390)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.borderStrong))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
                .enterOnAppear()
            cta(item)
                .enterOnAppear(delay: 0.08)
            FactList(facts: facts(item))
                .enterOnAppear(delay: 0.14)
            if let custom = item.customGame, !custom.executableExists {
                Label(L("detail.exeMissing"), systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.warning)
            }
        }
    }

    private func state(_ item: LibraryItem) -> (blocker: CompatFactor?, needsD3DMetal: Bool) {
        let report = model.compatReport(for: item)
        let blocker = report?.factors.first { $0.kind == .blocker }
        let d3d = report?.factors.contains { $0.key == "compat.f.dx12noMetal" } == true && !model.d3dMetalReady
        return (blocker, d3d)
    }

    @ViewBuilder private func cta(_ item: LibraryItem) -> some View {
        let (blocker, needsD3DMetal) = state(item)
        if let progress = model.installProgress[item.id] {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.elevated)
                        Capsule().fill(Theme.Palette.accent).frame(width: geo.size.width * progress)
                            .animation(Theme.Motion.valueChange, value: progress)
                    }
                }
                .frame(height: 6)
                Text(L(model.progressLabelKey(item), Int(progress * 100)))
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).monospacedDigit()
            }
            .frame(height: 44)
        } else if model.isQueued(item) {
            Button { model.removeFromQueue(item) } label: { ctaLabel(L("queue.waiting"), "clock") }
                .buttonStyle(SecondaryButtonStyle(height: 44))
                .help(L("queue.remove"))
        } else if model.isRunning(item) {
            Button { model.stop(item) } label: { ctaLabel(L("action.stop"), "stop.fill") }
                .buttonStyle(PrimaryButtonStyle(role: .destructive, height: 44))
        } else if blocker != nil {
            if item.isInstalled {
                Button { Task { await model.play(item) } } label: { ctaLabel(L("action.play"), "play.fill") }
                    .buttonStyle(SecondaryButtonStyle(height: 44))
            } else {
                Button { Task { await model.install(item) } } label: { ctaLabel(L("game.installAnyway"), "arrow.down.to.line") }
                    .buttonStyle(SecondaryButtonStyle(height: 44))
            }
        } else if needsD3DMetal {
            if item.isInstalled {
                Button {} label: { ctaLabel(L("action.play"), "play.fill") }
                    .buttonStyle(SecondaryButtonStyle(height: 44))
                    .disabled(true)
            } else {
                Button { Task { await model.install(item) } } label: { ctaLabel(L("action.install"), "arrow.down.to.line") }
                    .buttonStyle(SecondaryButtonStyle(height: 44))
            }
        } else if item.isInstalled {
            Button { Task { await model.play(item) } } label: {
                if model.isLaunching(item) {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L("status.launching")) }.frame(maxWidth: .infinity)
                } else {
                    ctaLabel(L("action.play"), "play.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 44))
            .disabled(model.isLaunching(item))
            .keyboardShortcut(.return, modifiers: .command)
        } else {
            Button { Task { await model.install(item) } } label: { ctaLabel(L("action.install"), "arrow.down.to.line") }
                .buttonStyle(PrimaryButtonStyle(height: 44))
        }
    }

    private func ctaLabel(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }

    private func facts(_ item: LibraryItem) -> [(String, String)] {
        let size = item.sizeOnDisk.flatMap { $0 > 0 ? ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) : nil }
        let source = item.source == .custom ? L("source.custom") : item.source.displayName
        if item.isInstalled {
            var status = L("filter.installed")
            if let size { status += " · \(size)" }
            let last = item.lastPlayed.map { $0.formatted(.relative(presentation: .named).locale(locale)) } ?? L("detail.never")
            var rows = [(L("game.fact.status"), status),
                        (L("game.fact.playtime"), item.playTime > 0 ? item.playTime.playTimeText(L) : "—"),
                        (L("game.fact.lastPlayed"), last)]
            if let location = location(item) { rows.append((L("game.fact.location"), location)) }
            return rows
        }
        var rows = [(L("game.fact.status"), L("status.notInstalled"))]
        if let size { rows.append((L("game.fact.size"), size)) }
        rows.append((L("game.fact.source"), source))
        return rows
    }

    private func location(_ item: LibraryItem) -> String? {
        guard var url = item.installPath else { return nil }
        if item.customGame != nil { url = url.deletingLastPathComponent() }
        if let custom = item.customGame, custom.wasInstalledByApp {
            return InstallScanner.windowsPath(of: url, driveC: model.customDriveC)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }

    // MARK: Right column

    private func rightColumn(_ item: LibraryItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.source == .custom ? L("source.custom") : item.source.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(item.title)
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
            }
            .enterOnAppear()
            notice(item)
            if let note = model.knownIssue(for: item) {
                KnownIssueBanner(gameID: item.id, englishNote: note)
                    .enterOnAppear(delay: 0.06)
            }
            CompatibilityPanel(item: item)
                .enterOnAppear(delay: 0.12)
            LaunchSettingsPanel(item: item)
                .enterOnAppear(delay: 0.18)
            if item.isInstalled {
                SavesPanel(item: item)
                    .enterOnAppear(delay: 0.22)
            }
        }
    }

    @ViewBuilder private func notice(_ item: LibraryItem) -> some View {
        let (blocker, needsD3DMetal) = state(item)
        if model.hasUpdate(item), model.installProgress[item.id] == nil {
            NoticeBanner(kind: .warning, title: L("maintain.update.banner"), message: L("maintain.update.banner.body"),
                         action: .primary(L("maintain.update")) { Task { await model.maintain(item, .update) } })
                .enterOnAppear(delay: 0.06)
        } else if model.failedLaunches.contains(item.id) {
            NoticeBanner(kind: .warning, title: L("diag.failed.title"), message: L("diag.failed.body"),
                         action: .primary(L("diag.failed.action")) { model.reviewLastLaunch(item) })
                .enterOnAppear(delay: 0.06)
        } else if let blocker {
            let titleKey = blocker.key + ".title"
            let title = L(titleKey) == titleKey ? L("compat.notice.blocked")
                : (blocker.args.isEmpty ? L(titleKey) : String(format: L(titleKey), locale: locale, arguments: blocker.args.map { $0 as CVarArg }))
            let antiCheat = ["compat.f.onlineAC", "compat.f.kernelAC", "compat.f.acLinuxOnly", "compat.f.deckAC"].contains(blocker.key)
            NoticeBanner(kind: .destructive, title: title, message: L("compat.notice.blocked.body"),
                         action: antiCheat ? .link(L("compat.notice.track"), Self.antiCheatPage(item.title)) : nil)
                .enterOnAppear(delay: 0.06)
        } else if model.compatReport(for: item)?.factors.contains(where: { $0.key == CompatFactor.accountRiskKey }) == true {
            NoticeBanner(kind: .warning, title: L("blocked.risk.title", item.title), message: L("compat.notice.risk.body"))
                .enterOnAppear(delay: 0.06)
        } else if needsD3DMetal {
            NoticeBanner(kind: .warning, title: L("compat.notice.d3d"), message: L("compat.notice.d3d.body"),
                         action: .primary(L("d3dmetal.setUp")) { model.openSettings(.dx12) })
                .enterOnAppear(delay: 0.06)
        }
    }

    static func antiCheatPage(_ title: String) -> URL {
        var components = URLComponents(string: "https://areweanticheatyet.com/")!
        components.queryItems = [URLQueryItem(name: "search", value: title)]
        return components.url!
    }
}

/// The game page's compatibility panel: score, verdict, the tier scale and the reasons.
struct CompatibilityPanel: View {
    let item: LibraryItem
    @State private var width: CGFloat = 800
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let report = model.compatReport(for: item) {
                header(report)
                if report.tier != .unknown {
                    TierScale(score: report.score, tier: report.tier)
                }
                factors(report)
                    .transition(.opacity)
                    .id(report.analyzedAt)
                CommunityRow(item: item)
            } else {
                HStack(spacing: Theme.Spacing.md) {
                    if model.isAnalyzing(item) {
                        ProgressView().controlSize(.small)
                        Text(L("compat.analyzing")).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                    } else {
                        Text(L("compat.empty")).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    analyzeButton
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
        .animation(Theme.Motion.crossfade, value: model.compatReport(for: item)?.analyzedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("compat.title"))
    }

    private func header(_ r: CompatReport) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            Text(r.tier == .unknown ? "?" : "\(r.score)")
                .font(Theme.Font.scoreHero)
                .foregroundStyle(Theme.Palette.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(r.score)))
                .animation(Theme.Motion.valueChange, value: r.score)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: r.tier.symbol).font(.system(size: 15))
                    Text("\(L("compat.tier.\(r.tier.rawValue)")) · \(Self.trimmed(L("compat.tier.\(r.tier.rawValue).help")))")
                        .lineLimit(2)
                }
                .font(Theme.Font.statSmall)
                .foregroundStyle(r.tier.color)
                .animation(Theme.Motion.valueChange, value: r.tier)
                Text("\(L("compat.confidence.\(r.confidence.rawValue)")) \(L("compat.analyzedAt")) \(r.analyzedAt.formatted(.relative(presentation: .named).locale(locale)))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(r.sources.map { L("compat.source.\($0)") }.joined(separator: " · "))
            }
            Spacer(minLength: 0)
            analyzeButton
        }
        .accessibilityElement(children: .combine)
    }

    static func trimmed(_ s: String) -> String {
        s.hasSuffix(".") ? String(s.dropLast()) : s
    }

    private var analyzeButton: some View {
        Button {
            Task { await model.analyze(item) }
        } label: {
            HStack(spacing: 6) {
                if model.isAnalyzing(item) { ProgressView().controlSize(.mini) }
                else { Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)) }
                Text(model.compatReport(for: item) == nil ? L("compat.analyze") : L("compat.reanalyze"))
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .buttonStyle(SecondaryButtonStyle(height: 30, horizontalPadding: 12))
        .disabled(model.isAnalyzing(item))
        .help(L("compat.analyze.help"))
    }

    /// Two columns, one when the panel is narrower than 560 pt.
    private func factors(_ r: CompatReport) -> some View {
        factorGrid(r, columns: width < 560 ? 1 : 2)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private func factorGrid(_ r: CompatReport, columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24, alignment: .topLeading), count: columns),
                  alignment: .leading, spacing: 10) {
            ForEach(r.factors) { factorRow($0) }
        }
    }

    private func factorRow(_ f: CompatFactor) -> some View {
        let (symbol, color): (String, Color) = switch f.kind {
        case .blocker: ("xmark.octagon.fill", Theme.Palette.destructive)
        case .negative: ("minus.circle.fill", Theme.Palette.warning)
        case .positive: ("plus.circle.fill", Theme.Palette.success)
        case .info: ("info.circle.fill", Theme.Palette.textTertiary)
        }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).font(.system(size: 13))
            Text(f.text(L, locale: locale))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if f.impact != 0 {
                Text(f.impact > 0 ? "+\(f.impact)" : "−\(abs(f.impact))")
                    .font(Theme.Font.mono).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Per-game Wine options from UniveEngine's `LaunchProfile`.
struct LaunchSettingsPanel: View {
    let item: LibraryItem
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        let binding = Binding<LaunchProfile>(get: { model.profile(for: item) }, set: { model.setProfile($0, for: item) })
        let backend = binding.wrappedValue.backend
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: Theme.Spacing.md) {
                Text(L("settings.launch")).font(Theme.Font.section).foregroundStyle(Theme.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SegmentedPicker(options: GraphicsBackend.allCases, selection: binding.backend,
                                label: { $0 == .auto ? L("launch.backend.auto") : $0.displayName },
                                accessibilityTitle: L("launch.backend"))
                    .fixedSize()
            }
            Text(backend == .auto ? L("launch.backend.help")
                 : backend == .wined3d ? L("launch.backend.wined3d")
                 : L("launch.backend.manual", backend.displayName))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(Theme.Motion.crossfade, value: backend)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    ToggleTile(title: L("launch.retina"), detail: L("launch.retina.short"), isOn: binding.retina)
                    ToggleTile(title: L("launch.metalfx"), detail: L("launch.metalfx.short"), isOn: binding.metalFX)
                }
                GridRow {
                    ToggleTile(title: L("launch.hud"), detail: L("launch.hud.short"), isOn: binding.performanceHUD)
                    ToggleTile(title: L("launch.cmdctrl"), detail: L("launch.cmdctrl.short"), isOn: binding.commandAsControl)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("launch.fpsLimit")).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
                    Text(L("launch.fpsLimit.help")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                SegmentedPicker(options: [0, 30, 60, 120], selection: binding.frameRateLimit,
                                label: { $0 == 0 ? L("launch.fpsLimit.off") : "\($0)" },
                                accessibilityTitle: L("launch.fpsLimit"))
                    .fixedSize()
            }
            if item.isInstalled { ComponentsRow(item: item) }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
    }
}

/// What players reported for the game, and a way to add a report.
struct CommunityRow: View {
    let item: LibraryItem
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        let entry = model.communityEntry(for: item)
        HStack(spacing: 8) {
            Image(systemName: "person.2").foregroundStyle(Theme.Palette.textSecondary)
            if let entry, !entry.counts.isEmpty {
                let parts = CommunityReports.results.compactMap { r in entry.counts[r].map { L("community.\(r)", "\($0)") } }
                VStack(alignment: .leading, spacing: 1) {
                    Text(parts.joined(separator: " · ")).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
                    if let last = entry.recent.first {
                        Text(L("community.last", last.date ?? "", last.mac ?? "?", last.backend ?? "?"))
                            .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            } else {
                Text(L("community.none")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 0)
            Button(L("community.report")) { model.reportingGame = item }
                .buttonStyle(SecondaryButtonStyle(height: 28, horizontalPadding: 10))
        }
    }
}

/// "How did it run?" before the report form opens in the browser.
struct ReportSheet: View {
    let item: LibraryItem
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @State private var result = "great"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L("community.sheet.title", item.title)).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary)
            Picker(L("community.sheet.result"), selection: $result) {
                ForEach(CommunityReports.results, id: \.self) { r in Text(L("community.result.\(r)")).tag(r) }
            }
            .pickerStyle(.radioGroup)
            Text(L("community.sheet.help")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("common.cancel")) { model.reportingGame = nil }.buttonStyle(SecondaryButtonStyle())
                Button(L("community.sheet.open")) { model.openReportForm(item, result: result) }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 520)
        .background(Theme.Palette.surface)
    }
}

/// Microsoft runtimes in the game's environment, and the game's recipe when it has one.
struct ComponentsRow: View {
    let item: LibraryItem
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        let installed = model.installedComponents(for: item)
        let progress = model.componentProgress[item.id]
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Theme.Palette.border).frame(height: 1)
            Text(L("components.title")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            if let recipe = model.recipe(for: item) {
                Label(L("components.recipe", recipe.note ?? ""), systemImage: "wand.and.stars")
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(WindowsComponent.allCases) { component in
                HStack(spacing: 8) {
                    Text(component.title).font(Theme.Font.body).foregroundStyle(Theme.Palette.textPrimary)
                    Spacer(minLength: 0)
                    if let progress, progress.component == component {
                        ProgressView(value: progress.fraction).frame(width: 120)
                        Text(L("components.installing")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    } else if installed.contains(component) {
                        Label(L("components.installed"), systemImage: "checkmark")
                            .font(Theme.Font.caption).foregroundStyle(Theme.Palette.success)
                        Button(L("components.reinstall")) { Task { await model.installComponent(component, for: item) } }
                            .buttonStyle(SecondaryButtonStyle(height: 28, horizontalPadding: 10))
                            .disabled(progress != nil || model.isRunning(item))
                    } else {
                        Button(L("components.install.size", "\(component.downloadMegabytes)")) {
                            Task { await model.installComponent(component, for: item) }
                        }
                        .buttonStyle(SecondaryButtonStyle(height: 28, horizontalPadding: 10))
                        .disabled(progress != nil || model.isRunning(item))
                    }
                }
            }
            Text(L("components.help")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The engine's notes are in English; known ones have a translation under `issue.<game id>`.
struct KnownIssueBanner: View {
    let gameID: String
    let englishNote: String
    @Environment(Localizer.self) private var L

    var body: some View {
        let key = "issue.\(gameID)"
        let text = L(key) == key ? englishNote : L(key)
        NoticeBanner(kind: .warning, title: L("issue.title"), message: text)
    }
}
