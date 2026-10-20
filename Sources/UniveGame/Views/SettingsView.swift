import AppKit
import MacadeKit
import SwiftUI

/// v2 settings: a section list on the left, one section at a time on the right.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            SectionNav(selection: $model.settingsSection)
            ScrollView {
                Group {
                    switch model.settingsSection {
                    case .general: GeneralSection()
                    case .engine: EngineSection()
                    case .dx12: D3DMetalSetupPanel()
                    case .about: AboutSection()
                    }
                }
                .id(model.settingsSection)
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.top, 112)
                .padding(.horizontal, 56)
                .padding(.bottom, Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
        }
        .background(Theme.Palette.background)
    }
}

private struct SectionNav: View {
    @Binding var selection: SettingsSection
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("rail.settings"))
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.leading, 12)
                .padding(.bottom, 16)
                .accessibilityAddTraits(.isHeader)
            row(.general, "globe", L("settings.section.general"))
            row(.engine, "cpu", L("settings.section.engine"), flag: !model.hasEngine && !model.isDemo)
            row(.dx12, "square.stack.3d.up", L("settings.section.dx12"), flag: !model.d3dMetalReady)
            row(.about, "info.circle", L("settings.section.about"))
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Layout.pageTitleTop)
        .padding(.horizontal, Theme.Spacing.md)
        .frame(width: 240)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.Palette.border).frame(width: 1) }
    }

    private func row(_ section: SettingsSection, _ symbol: String, _ title: String, flag: Bool = false) -> some View {
        SectionNavRow(symbol: symbol, title: title, isSelected: selection == section, flag: flag,
                      flagLabel: L("settings.dx12.needsSetup")) { selection = section }
    }
}

private struct SectionNavRow: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let flag: Bool
    let flagLabel: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 15))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : (hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary))
                    .frame(width: 18)
                Text(title).font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected || hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                Spacer(minLength: 0)
                if flag {
                    Circle().fill(Theme.Palette.warning).frame(width: 8, height: 8)
                        .accessibilityLabel(flagLabel)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
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

private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary).accessibilityAddTraits(.isHeader)
    }
}

// MARK: General

private struct GeneralSection: View {
    @Environment(Localizer.self) private var L

    var body: some View {
        @Bindable var L = L
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionTitle(text: L("settings.section.general")).enterOnAppear()
            VStack(alignment: .leading, spacing: 10) {
                Text(L("settings.language")).font(Theme.Font.section).foregroundStyle(Theme.Palette.textPrimary)
                SegmentedPicker(options: AppLanguage.allCases, selection: $L.language,
                                label: { $0 == .system ? L("settings.language.system") : $0.nativeName },
                                segmentHeight: 28, fontSize: 13, fillsWidth: true, accessibilityTitle: L("settings.language"))
                    .frame(width: 420)
                Text(L("settings.language.v2help")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            }
            .enterOnAppear(delay: 0.06)
            VStack(alignment: .leading, spacing: 10) {
                Text(L("settings.data")).font(Theme.Font.section).foregroundStyle(Theme.Palette.textPrimary)
                HStack(spacing: Theme.Spacing.md) {
                    Text(AppPaths.home.path).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textSecondary)
                        .textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button(L("settings.openFolder")) {
                        try? FileManager.default.createDirectory(at: AppPaths.home, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(AppPaths.home)
                    }
                    .buttonStyle(SecondaryButtonStyle(height: 34, horizontalPadding: 14))
                }
            }
            .enterOnAppear(delay: 0.12)
        }
    }
}

// MARK: Engine

private struct EngineSection: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionTitle(text: L("settings.section.engine")).enterOnAppear()
            card.enterOnAppear(delay: 0.06)
            Text(L("settings.engine.help"))
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .enterOnAppear(delay: 0.12)
        }
    }

    private var card: some View {
        let engine = model.engines.first
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Text(engine?.version ?? "—")
                    .font(Theme.Font.display).monospacedDigit()
                    .foregroundStyle(Theme.Palette.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if model.engineInstall != nil {
                            Circle().fill(Theme.Palette.accent).frame(width: 8, height: 8).pulsing()
                            Text(L("d3dmetal.downloading")).foregroundStyle(Theme.Palette.textPrimary)
                        } else if engine != nil || model.isDemo {
                            Circle().fill(Theme.Palette.success).frame(width: 8, height: 8).pulsing()
                            Text(L("d3dmetal.status.ready")).foregroundStyle(Theme.Palette.success)
                        } else {
                            Circle().fill(Theme.Palette.warning).frame(width: 8, height: 8)
                            Text(L("engine.missing")).foregroundStyle(Theme.Palette.warning)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    if let engine {
                        Text("\(engine.info.wineDescription) · \(engine.info.backends.map { $0.uppercased() }.joined(separator: " · "))")
                            .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if model.engineInstall == nil {
                    if engine == nil {
                        Button(L("engine.download")) { Task { await model.installEngine() } }
                            .buttonStyle(PrimaryButtonStyle(height: 34, horizontalPadding: 16))
                            .disabled(model.isDemo)
                    } else {
                        Button(L("engine.update")) { Task { await model.installEngine() } }
                            .buttonStyle(SecondaryButtonStyle(height: 34, horizontalPadding: 14))
                            .disabled(model.isDemo)
                    }
                    Button(L("settings.rescan")) { model.reloadEngines() }
                        .buttonStyle(SecondaryButtonStyle(height: 34, horizontalPadding: 14))
                }
            }
            if let progress = model.engineInstall {
                EngineProgressRow(progress: progress)
            }
            if model.engines.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.engines.dropFirst(), id: \.version) { other in
                        HStack(spacing: 8) {
                            Text(L("settings.engineVersion", other.version)).font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Palette.textPrimary).monospacedDigit()
                            Text(other.info.wineDescription).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                            Spacer(minLength: 0)
                            Text(other.info.backends.joined(separator: " · ").uppercased())
                                .font(Theme.Font.mono).foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
                .overlay(alignment: .top) { Rectangle().fill(Theme.Palette.border).frame(height: 1).offset(y: -8) }
            }
        }
        .padding(20)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
    }
}

/// "Downloading · 182 / 290 MB · 40 s left" with a 6 pt meter.
struct EngineProgressRow: View {
    let progress: EngineInstallProgress
    var showsCancel = false
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Theme.Palette.accent).frame(width: 8, height: 8).pulsing()
                    Text(progress.phase == .downloading ? L("d3dmetal.downloading") : L("engine.phase.\(phaseKey)"))
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer()
                if let detail { Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).monospacedDigit() }
            }
            if progress.phase == .downloading {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.elevated)
                        Capsule().fill(Theme.Palette.accent).frame(width: geo.size.width * progress.fraction)
                            .animation(Theme.Motion.valueChange, value: progress.fraction)
                    }
                }
                .frame(height: 6)
            } else {
                IndeterminateBar(height: 6)
            }
            if showsCancel && progress.phase == .downloading {
                Button(L("common.cancel")) { model.cancelEngineInstall() }
                    .buttonStyle(SecondaryButtonStyle(height: 30, horizontalPadding: 12))
                    .font(.system(size: 12))
            }
        }
        .enterOnAppear()
    }

    private var phaseKey: String {
        switch progress.phase {
        case .downloading: "downloading"
        case .verifying: "verifying"
        case .extracting: "extracting"
        case .finishing: "finishing"
        }
    }

    private var detail: String? {
        guard progress.phase == .downloading, progress.totalBytes > 0 else { return nil }
        let mb = Double(progress.totalBytes) / 1_048_576
        let done = Int(mb * progress.fraction), total = Int(mb.rounded())
        let left = progress.secondsLeft.map { Duration.seconds($0).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated, maximumUnitCount: 1)) } ?? "…"
        return L("d3dmetal.progress", "\(done)", "\(total)", left)
    }
}

// MARK: About

private struct AboutSection: View {
    @Environment(\.windowHeight) private var windowHeight
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: Theme.Spacing.md) {
                    if let icon = AppIcon.image {
                        Image(nsImage: icon).resizable().interpolation(.high)
                            .frame(width: 72, height: 72)
                            .padding(-6)   // the icon carries Apple's transparent margin
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: "UniveGame").font(Theme.Font.display).foregroundStyle(Theme.Palette.textPrimary)
                }
                Text(L("settings.about.version", Self.version)).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                Text(L("settings.about.text")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .enterOnAppear()
            legalCard.enterOnAppear(delay: 0.08)
        }
        .sheet(isPresented: $model.reviewingDisclaimer) {
            DisclaimerView(mode: .review, windowHeight: windowHeight)
        }
    }

    /// The accepted disclaimer, with a way to read it again.
    private var legalCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 17))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            VStack(alignment: .leading, spacing: 3) {
                Text(L("settings.legal")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                if let date = model.disclaimerAcceptedAt {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.Palette.success)
                        Text(L("disclaimer.acceptedOn", date.formatted(Date.FormatStyle(date: .long, time: .shortened).locale(L.locale))))
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Button(L("disclaimer.reread")) { model.reviewingDisclaimer = true }
                .buttonStyle(SecondaryButtonStyle(height: 34, horizontalPadding: 14))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
