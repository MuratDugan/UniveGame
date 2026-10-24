import AppKit
import SwiftUI

/// Shared between the card's context menu and the detail page's "more" menu.
struct GameActionsMenu: View {
    let item: LibraryItem
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    private func chooseFolder(for item: LibraryItem) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = L("maintain.move.panel")
        if panel.runModal() == .OK, let url = panel.url { Task { await model.moveGame(item, to: url) } }
    }

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
        Menu(L("collections.addTo"), systemImage: "folder.badge.plus") {
            let current = model.collections(containing: item)
            ForEach(model.collectionNames, id: \.self) { name in
                Toggle(name, isOn: Binding(get: { current.contains(name) }, set: { _ in model.toggle(item, in: name) }))
            }
            if !model.collectionNames.isEmpty { Divider() }
            Button(L("collections.new")) { model.namingCollectionFor = item }
        }
        if model.isQueued(item) {
            Button(L("queue.remove"), systemImage: "xmark.circle") { model.removeFromQueue(item) }
        }
        if item.isInstalled, case .store(let game) = item.backing, game.store == .epic || game.store == .gog {
            Divider()
            Button(L(model.hasUpdate(item) ? "maintain.update.available" : "maintain.update"), systemImage: "arrow.down.circle") {
                Task { await model.maintain(item, .update) }
            }
            Button(L("maintain.repair"), systemImage: "wrench.and.screwdriver") { Task { await model.maintain(item, .repair) } }
            Button(L("maintain.move"), systemImage: "folder") { chooseFolder(for: item) }
        }
        Divider()
        if item.installPath != nil {
            Button(L("action.showInFinder"), systemImage: "folder") { model.revealInFinder(item) }
        }
        if item.isInstalled || item.customGame != nil {
            Button(L("diag.menu"), systemImage: "stethoscope") { model.reviewLastLaunch(item) }
        }
        if item.isInstalled {
            Button(L("shortcut.create"), systemImage: "app.badge") { Task { await model.createShortcut(item) } }
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
