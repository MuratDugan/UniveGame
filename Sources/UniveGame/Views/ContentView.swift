import SwiftUI

/// v2 shell: the icon rail and the selected page. The installer flow takes the whole window.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @State private var dropTargeted = false
    @State private var windowHeight: CGFloat = 800
    @State private var collectionName = ""

    var body: some View {
        @Bindable var model = model
        ZStack {
            if let session = model.installer {
                InstallerFlowView(session: session)
                    .transition(.opacity)
            } else {
                HStack(spacing: 0) {
                    RailView()
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Palette.background)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.installer?.id)
        .background(Theme.Palette.background)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { windowHeight = $0 }
        .environment(\.windowHeight, windowHeight)
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.windowDropTargeted, dropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            guard model.installer == nil, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { model.handleDroppedFile(url) }
            }
            return true
        }
        .tint(Theme.Palette.accent)
        .sheet(isPresented: Binding(get: { model.needsDisclaimer }, set: { _ in })) {
            DisclaimerView(mode: .firstLaunch, windowHeight: windowHeight)
        }
        .sheet(item: $model.editingCustomGame) { game in
            ImportGameSheet(editing: game)
        }
        .sheet(item: $model.blockedWarning) { warning in
            BlockedGameSheet(warning: warning)
        }
        .sheet(item: $model.launchReview) { review in
            LaunchReviewSheet(review: review)
        }
        .sheet(item: $model.reportingGame) { item in
            ReportSheet(item: item)
        }
        .confirmationDialog(L("uninstall.title", model.pendingUninstall?.title ?? ""),
                            isPresented: Binding(get: { model.pendingUninstall != nil },
                                                 set: { if !$0 { model.pendingUninstall = nil } }),
                            titleVisibility: .visible) {
            if let game = model.pendingUninstall {
                Button(L("uninstall.confirm"), role: .destructive) { Task { await model.uninstall(game) } }
                Button(L("action.remove")) { model.removeCustomGame(game); model.pendingUninstall = nil }
            }
            Button(L("common.cancel"), role: .cancel) { model.pendingUninstall = nil }
        } message: {
            if let game = model.pendingUninstall {
                if game.uninstaller != nil {
                    Text(L("uninstall.message.uninstaller"))
                } else if let folder = model.trashableInstallFolder(of: game) {
                    Text(L("uninstall.message.trashFolder", InstallScanner.windowsPath(of: folder, driveC: model.customDriveC)))
                } else {
                    Text(L("uninstall.message.keepFiles"))
                }
            }
        }
        .confirmationDialog(L("steam.repair.title"), isPresented: $model.confirmingSteamRepair, titleVisibility: .visible) {
            Button(L("steam.repair.confirm")) { Task { await model.repairSteam() } }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("steam.repair.message"))
        }
        .alert(L("collections.new.title"), isPresented: Binding(get: { model.namingCollectionFor != nil },
                                                                set: { if !$0 { model.namingCollectionFor = nil } })) {
            TextField(L("collections.new.placeholder"), text: $collectionName)
            Button(L("collections.create")) {
                model.addCollection(collectionName, with: model.namingCollectionFor)
                collectionName = ""
                model.namingCollectionFor = nil
            }
            .keyboardShortcut(.defaultAction)
            Button(L("common.cancel"), role: .cancel) { collectionName = ""; model.namingCollectionFor = nil }
        }
        .alert(item: $model.alert) { alert in
            Alert(title: Text(L(alert.titleKey)),
                  message: alert.message.isEmpty ? nil : Text(alert.message),
                  dismissButton: .default(Text(L("common.ok"))))
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.selection ?? .library(.all) {
        case .library:
            LibraryView()
        case .discover:
            DiscoverView()
        case .stores:
            StoresView()
        case .addGame:
            AddGameView()
        case .settings:
            SettingsView()
        }
    }
}

private struct WindowDropTargetedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct WindowHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 800
}

extension EnvironmentValues {
    /// The main window's content height (sheets size themselves to fit).
    var windowHeight: CGFloat {
        get { self[WindowHeightKey.self] }
        set { self[WindowHeightKey.self] = newValue }
    }

    /// A file is being dragged over the window (drop hints light up).
    var windowDropTargeted: Bool {
        get { self[WindowDropTargetedKey.self] }
        set { self[WindowDropTargetedKey.self] = newValue }
    }
}
