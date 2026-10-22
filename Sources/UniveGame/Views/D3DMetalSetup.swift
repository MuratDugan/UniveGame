import AppKit
import UniveEngineKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings → DirectX 12: a two-step timeline (the D3DMetal engine, then Apple's toolkit).
struct D3DMetalSetupPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    private var step1Done: Bool { model.hasD3DMetalEngine }
    private var step2Done: Bool { model.d3dMetalImported }
    private var downloading: Bool { model.engineInstall != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(L("d3dmetal.title")).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    statusChip
                }
                Text(L("d3dmetal.about")).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .enterOnAppear()

            VStack(alignment: .leading, spacing: 32) {
                TimelineStep(number: 1, done: step1Done, isCurrent: !step1Done, isLast: false) {
                    stepText(L("d3dmetal.step1"), L("d3dmetal.step1.help"))
                    if !step1Done {
                        if let progress = model.engineInstall {
                            EngineProgressRow(progress: progress, showsCancel: true)
                                .padding(.top, 4)
                                .transition(.opacity)
                        } else {
                            Button(L("d3dmetal.step1.button")) { model.startD3DMetalEngineInstall() }
                                .buttonStyle(PrimaryButtonStyle(height: 36, horizontalPadding: 20))
                                .disabled(model.isDemo)
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                    }
                }
                .enterOnAppear(delay: 0.08)
                TimelineStep(number: 2, done: step2Done, isCurrent: step1Done && !step2Done, isLast: true) {
                    stepText(L("d3dmetal.step2"), L("d3dmetal.step2.help"))
                    if !step2Done {
                        HStack(spacing: 8) {
                            Button(L("d3dmetal.step2.open")) { NSWorkspace.shared.open(D3DMetalStore.downloadPage) }
                                .buttonStyle(SecondaryButtonStyle(height: 34, horizontalPadding: 14))
                            if step1Done {
                                Button(L("d3dmetal.step2.choose")) { choose() }
                                    .buttonStyle(PrimaryButtonStyle(height: 34, horizontalPadding: 16))
                                    .disabled(model.importingD3DMetal)
                            } else {
                                Button(L("d3dmetal.step2.choose")) { choose() }
                                    .buttonStyle(SecondaryButtonStyle(height: 34, horizontalPadding: 14))
                                    .disabled(model.importingD3DMetal)
                            }
                            if model.importingD3DMetal { ProgressView().controlSize(.small) }
                        }
                        .padding(.top, 4)
                    }
                }
                .enterOnAppear(delay: 0.16)
            }
            .animation(Theme.Motion.quick, value: downloading)

            Text(L("d3dmetal.license.note"))
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 48)
                .enterOnAppear(delay: 0.22)
        }
        .sheet(isPresented: Binding(get: { model.stagedD3DMetal != nil }, set: { if !$0 { model.declineD3DMetalLicense() } })) {
            LicenseSheet()
        }
    }

    @ViewBuilder private var statusChip: some View {
        let (text, color, symbol): (String, Color, String?) =
            model.d3dMetalReady ? (L("d3dmetal.status.ready"), Theme.Palette.success, "checkmark")
            : (downloading || step1Done) ? (L("d3dmetal.step", step1Done ? "2" : "1", "2"), Theme.Palette.accent, nil)
            : (L("d3dmetal.status.notInstalled"), Theme.Palette.textSecondary, nil)
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
            Text(text).contentTransition(.opacity)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Theme.Palette.elevated, in: Capsule())
        .animation(Theme.Motion.quick, value: text)
    }

    private func stepText(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .diskImage, .folder]
        panel.canChooseDirectories = true
        panel.message = L("d3dmetal.step2.panel")
        if panel.runModal() == .OK, let url = panel.url { Task { await model.importD3DMetal(from: url) } }
    }
}

/// One step of a vertical timeline: a 32 pt circle with a line down to the next step, and a card.
struct TimelineStep<Content: View>: View {
    let number: Int
    let done: Bool
    let isCurrent: Bool
    let isLast: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(done ? Theme.Palette.success : Theme.Palette.background)
                Circle().strokeBorder(done ? Theme.Palette.success : (isCurrent ? Theme.Palette.accent : Theme.Palette.borderStrong), lineWidth: 2)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Palette.onCTA)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    Text("\(number)").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isCurrent ? Theme.Palette.accent : Theme.Palette.textSecondary)
                }
            }
            .frame(width: 32, height: 32)
            .animation(.easeOut(duration: 0.3), value: done)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(alignment: .top) {
                if !isLast {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.Palette.elevated)
                        .frame(width: 2)
                        .padding(.top, 36)
                        .padding(.bottom, -28)
                }
            }
            VStack(alignment: .leading, spacing: 8) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isCurrent ? Theme.Palette.card : Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }
}

/// Apple's license, shown before D3DMetal is installed.
private struct LicenseSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L("d3dmetal.license.title")).font(Theme.Font.title)
            Text(L("d3dmetal.license.subtitle")).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                Text(model.stagedD3DMetalLicense.isEmpty ? L("d3dmetal.license.missing") : model.stagedD3DMetalLicense)
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
            }
            .frame(height: 320)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            HStack {
                Spacer()
                Button(L("common.cancel")) { model.declineD3DMetalLicense() }
                    .buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Button(L("d3dmetal.license.accept")) { model.acceptD3DMetalLicense() }
                    .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 600)
        .background(Theme.Palette.surface)
    }
}
