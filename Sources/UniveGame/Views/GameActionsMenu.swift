import SwiftUI

/// Shared between the card's context menu and the detail page's "more" menu.
struct GameActionsMenu: View {
    let item: LibraryItem
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        if model.isRunning(item) {
            Button(L("action.stop"), systemImage: "stop.fill") { model.stop(item) }
        } else if item.isInstalled {
            Button(L("action.play"), systemImage: "play.fill") { Task { await model.play(item) } }
        } else {
            Button(L("action.install"), systemImage: "arrow.down.circle") { Task { await model.install(item) } }
        }
        Button(item.isFavorite ? L("action.unfavorite") : L("action.favorite"),
               systemImage: item.isFavorite ? "heart.slash" : "heart") { model.toggleFavorite(item) }
        Divider()
        if item.installPath != nil {
            Button(L("action.showInFinder"), systemImage: "folder") { model.revealInFinder(item) }
        }
        Button(L("action.openLogs"), systemImage: "doc.text.magnifyingglass") { model.openLogs(item) }
        if let custom = item.customGame {
            Button(L("cover.findOnline"), systemImage: "photo.badge.magnifyingglass") {
                Task { await model.findCover(for: custom, languageCode: L.resolvedCode) }
            }
            if custom.wasInstalledByApp {
                Button(L("installer.openDrive"), systemImage: "externaldrive") { model.revealDriveC() }
            }
            Divider()
            Button(L("action.edit"), systemImage: "pencil") { model.editingCustomGame = custom }
            if custom.wasInstalledByApp {
                Button(L("action.uninstall"), systemImage: "trash", role: .destructive) { model.pendingUninstall = custom }
            } else {
                Button(L("action.remove"), systemImage: "trash", role: .destructive) { model.removeCustomGame(custom) }
            }
        }
    }
}
