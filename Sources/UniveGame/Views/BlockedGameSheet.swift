import AppKit
import SwiftUI

/// Before installing or starting a game the analysis says can't run on a Mac: why, what it risks, and how to play
/// it anyway (in the cloud or streamed from a PC). "Try anyway" is remembered for that game.
struct BlockedGameSheet: View {
    let warning: AppModel.BlockedGameWarning
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale

    private var isAntiCheat: Bool {
        ["compat.f.onlineAC", "compat.f.kernelAC", "compat.f.acLinuxOnly", "compat.f.deckAC"].contains(warning.reason.key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: isAntiCheat ? "exclamationmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Palette.destructive)
                    .frame(width: 44, height: 44)
                    .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("blocked.title", warning.item.title)).font(Theme.Font.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(warning.reason.text(L, locale: locale)).font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(L(isAntiCheat ? "blocked.antiCheat.body" : "blocked.known.body"))
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(L("blocked.alternatives")).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                ForEach(AppModel.cloudServices, id: \.name) { service in
                    alternative(service.name, L("blocked.cloud.\(service.name == "GeForce NOW" ? "gfn" : "xbox")"),
                                symbol: "cloud", url: service.url)
                }
                alternative("Moonlight", L("blocked.moonlight"), symbol: "display", url: AppModel.moonlight)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))

            HStack {
                Text(L("blocked.remembered")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                Spacer()
                Button(L(warning.action == .install ? "blocked.installAnyway" : "blocked.startAnyway")) {
                    model.continueDespiteWarning(warning)
                }
                .buttonStyle(SecondaryButtonStyle())
                Button(L("common.cancel")) { model.blockedWarning = nil }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 560)
        .background(Theme.Palette.surface)
    }

    private func alternative(_ name: String, _ detail: String, symbol: String, url: URL) -> some View {
        Button { NSWorkspace.shared.open(url) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(Theme.Palette.accent).frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
                    Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.Palette.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L("blocked.opensInBrowser"))
    }
}
