import SwiftUI

/// The library's stage: wide artwork for the picked game, its verdict, and the one thing to do next.
struct LibraryStage: View {
    let item: LibraryItem
    let shelfTitle: String
    let openPage: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let imageWidth = min(500, geo.size.width * 0.45)
            HStack(spacing: Theme.Spacing.xl) {
                artwork
                    .frame(width: imageWidth, height: 280)
                    .enterOnAppear()
                info
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 280)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("stage.a11y"))
    }

    private var artwork: some View {
        ZStack {
            CoverArt(url: item.heroURL, title: item.title, symbol: item.source.symbol)
                .id(item.id)
                .transition(.opacity)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : Theme.Motion.crossfade, value: item.id)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
    }

    private var info: some View {
        let report = model.compatReport(for: item)
        return VStack(alignment: .leading, spacing: 12) {
            Text(shelfTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .contentTransition(.opacity)
                .enterOnAppear(delay: 0.06)
            Text(item.title)
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(2)
                .contentTransition(.opacity)
                .enterOnAppear(delay: 0.12)
                .accessibilityAddTraits(.isHeader)
            Text(meta)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
                .contentTransition(.opacity)
                .enterOnAppear(delay: 0.18)
            scoreBlock(report)
                .frame(maxWidth: 420, alignment: .leading)
                .padding(.top, 4)
                .enterOnAppear(delay: 0.24)
            actions(report)
                .padding(.top, 8)
                .enterOnAppear(delay: 0.30)
        }
        .animation(reduceMotion ? nil : Theme.Motion.crossfade, value: item.id)
    }

    private var meta: String {
        var parts = [item.source == .custom ? L("source.custom") : item.source.displayName]
        if model.isRunning(item) {
            parts.append(L("status.running"))
        } else if let p = model.installProgress[item.id] ?? item.installProgress {
            parts.append(L("status.installing", Int(p * 100)))
        } else {
            parts.append(item.isInstalled ? L("filter.installed") : L("status.notInstalled"))
        }
        if item.isInstalled, item.playTime > 0 {
            parts.append(L("stage.playtime", item.playTime.playTimeText(L)))
        } else if !item.isInstalled, let size = item.sizeOnDisk, size > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func scoreBlock(_ report: CompatReport?) -> some View {
        if let report, report.tier != .unknown {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(report.score)")
                        .font(Theme.Font.scoreStage)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(report.score)))
                    HStack(spacing: 4) {
                        Image(systemName: report.tier.symbol).font(.system(size: 12))
                        Text(L("compat.tier.\(report.tier.rawValue)"))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(report.tier.color)
                    if let reason = report.leadingFactor {
                        Text("· \(reason.text(L, locale: locale))")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                }
                .animation(Theme.Motion.valueChange, value: report.score)
                StageMeter(score: report.score, tier: report.tier)
                    .animation(Theme.Motion.valueChange, value: report.tier)
            }
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L("cover.notAnalyzed")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textSecondary)
                    if model.isAnalyzing(item) {
                        ProgressView().controlSize(.mini)
                    } else {
                        Button(L("compat.analyze")) { Task { await model.analyze(item) } }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Palette.accent)
                    }
                }
                StageMeter(score: 0, tier: .unknown)
            }
        }
    }

    @ViewBuilder private func actions(_ report: CompatReport?) -> some View {
        let needsD3DMetal = report?.factors.contains { $0.key == "compat.f.dx12noMetal" } == true && !model.d3dMetalReady
        HStack(spacing: 8) {
            if report?.tier == .broken {
                Button(L("stage.whyBroken"), action: openPage).buttonStyle(SecondaryButtonStyle())
            } else if needsD3DMetal {
                Button(L("stage.setUpD3DMetal")) { model.openSettings(.dx12) }.buttonStyle(SecondaryButtonStyle())
            } else {
                primary
                Button(L("stage.openPage"), action: openPage).buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    @ViewBuilder private var primary: some View {
        if model.isRunning(item) {
            Button { model.stop(item) } label: { Label(L("action.stop"), systemImage: "stop.fill") }
                .buttonStyle(PrimaryButtonStyle(role: .destructive))
        } else if item.isInstalled {
            Button { Task { await model.play(item) } } label: {
                HStack(spacing: 8) {
                    if model.isLaunching(item) { ProgressView().controlSize(.small) } else { Image(systemName: "play.fill").font(.system(size: 12)) }
                    Text(model.isLaunching(item) ? L("status.launching") : L("action.play"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isLaunching(item))
        } else if model.installProgress[item.id] != nil {
            EmptyView()
        } else {
            Button { Task { await model.install(item) } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 12, weight: .semibold))
                    Text(L("action.install"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}

extension CompatReport {
    /// The reason with the largest effect, shown next to the score.
    var leadingFactor: CompatFactor? {
        factors.filter { $0.impact != 0 || $0.kind == .blocker }
            .max { abs($0.impact) + ($0.kind == .blocker ? 1000 : 0) < abs($1.impact) + ($1.kind == .blocker ? 1000 : 0) }
    }
}

extension CompatFactor {
    @MainActor func text(_ L: Localizer, locale: Locale) -> String {
        let format = L(key)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: args.map { $0 as CVarArg })
    }
}
