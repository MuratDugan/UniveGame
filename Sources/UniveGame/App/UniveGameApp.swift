import AppKit
import SwiftUI

@main
struct UniveGameApp: App {
    @State private var model = AppModel()
    @State private var localizer = Localizer()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("UniveGame", id: "main") {
            ContentView()
                .environment(model)
                .environment(localizer)
                .environment(\.locale, localizer.locale)
                .preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 620)
                .task {
                    appDelegate.onOpenURL = { url in model.open(url) }
                    await model.refreshStores()
                    await model.loadKnownIssues()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await model.refreshIfStale() }
                }
        }
        .defaultSize(width: 1280, height: 800)
        // No toolbar: an (even empty) window toolbar takes every click in the top 52 pt, where the back button,
        // the filters and the search field are. The title bar stays, transparent, for the traffic lights.
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button(localizer("menu.import")) { model.selection = .addGame }
                    .keyboardShortcut("i", modifiers: .command)
                Button(localizer("menu.runInstaller")) { model.chooseInstaller(message: localizer("menu.runInstaller")) }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button(localizer("menu.refresh")) { Task { await model.refreshStores() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button(localizer("menu.settings")) { model.selection = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        MenuBarExtra("UniveGame", systemImage: "gamecontroller", isInserted: $model.showsMenuBarItem) {
            ForEach(model.recentGames.prefix(8)) { item in
                Button(item.title) { Task { await model.play(item) } }
                    .disabled(model.isRunning(item))
            }
            if model.recentGames.isEmpty { Text(localizer("menubar.empty")) }
            Divider()
            Button(localizer("menubar.open")) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set once the window exists; links that arrive earlier (a shortcut that started the app) wait for it.
    var onOpenURL: ((URL) -> Void)? {
        didSet { if let onOpenURL { pendingURLs.forEach(onOpenURL); pendingURLs = [] } }
    }
    private var pendingURLs: [URL] = []

    /// `univegame://play?game=…` from a game shortcut. Handled here so SwiftUI doesn't open a second window for it.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let onOpenURL { onOpenURL(url) } else { pendingURLs.append(url) }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when started with `swift run` (no .app bundle around the executable).
        NSApp.setActivationPolicy(.regular)
        // A packaged .app gets its icon from Info.plist; a bare `swift run` binary doesn't.
        if Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") == nil, let icon = AppIcon.image {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
