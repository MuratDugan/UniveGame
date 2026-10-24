import AppKit
import SwiftUI
import UniveEngineKit

/// "Why didn't it start?": the last launch of a game, what its log says went wrong, and one thing to do about each
/// problem. Nothing leaves the Mac unless the player copies the report.
struct LaunchReviewSheet: View {
    let review: AppModel.LaunchReview
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("diag.title", review.item.title)).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary)
                if let summary { Text(summary).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if review.diagnosis.findings.isEmpty {
                        card(title: L("diag.nothing"), detail: L("diag.nothing.detail"), evidence: nil, action: nil)
                    }
                    ForEach(review.diagnosis.findings) { finding in
                        card(title: text(finding.id, "title", fallback: finding.title),
                             detail: text(finding.id, "detail", fallback: finding.detail),
                             evidence: finding.evidence, action: finding.action)
                    }
                }
            }
            .frame(maxHeight: 360)
            HStack(spacing: 8) {
                Button(L("action.openLogs")) { NSWorkspace.shared.activateFileViewerSelecting([review.log]) }
                    .buttonStyle(SecondaryButtonStyle())
                Button(copied ? L("diag.copied") : L("diag.copyReport")) { copyReport() }
                    .buttonStyle(SecondaryButtonStyle())
                    .help(L("diag.copyReport.help"))
                Spacer()
                Button(L("common.close")) { model.launchReview = nil }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 600)
        .background(Theme.Palette.surface)
    }

    /// "DXVK · engine 1.1.0 · closed after 3 s (exit 1)".
    private var summary: String? {
        guard let launch = review.diagnosis.launch else { return nil }
        var parts: [String] = []
        if let backend = launch.backend.flatMap(GraphicsBackend.init(rawValue:)) { parts.append(backend.displayName) }
        if let engine = launch.engine { parts.append(L("settings.engineVersion", engine)) }
        if let seconds = launch.seconds {
            parts.append(L("diag.ranFor", "\(Int(seconds))") + (launch.status.map { " (\(L("diag.exit", "\($0)")))" } ?? ""))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The Turkish (or other) text for a finding when there is one; the engine's English otherwise.
    private func text(_ id: String, _ part: String, fallback: String) -> String {
        let key = "diag.\(id).\(part)"
        let value = L(key)
        return value == key ? fallback : value
    }

    private func card(title: String, detail: String, evidence: String?, action: LogDiagnosis.Action?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let evidence {
                Text(evidence).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(3).textSelection(.enabled)
            }
            if let action, let label = label(for: action) {
                Button(label) {
                    if action == .reportProblem { copyReport() } else { model.apply(action, for: review.item) }
                }
                .buttonStyle(SecondaryButtonStyle(height: 30, horizontalPadding: 12))
                .padding(.top, 2)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
    }

    private func label(for action: LogDiagnosis.Action) -> String? {
        switch action {
        case .useBackend(let backend): L("diag.action.useBackend", backend.displayName)
        case .installExtendedEngine: L("diag.action.extendedEngine")
        case .setUpDirectX12: L("d3dmetal.setUp")
        case .updateEngine: L("diag.action.updateEngine")
        case .installComponent(let component): L("components.install", component.title)
        case .reportProblem: L("diag.copyReport")
        case .none: nil
        }
    }

    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AppModel.problemReport(review), forType: .string)
        copied = true
    }
}
