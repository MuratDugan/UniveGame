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
                    await model.refreshStores()
                    await model.loadKnownIssues()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await model.refreshIfStale() }
                }
        }
        .defaultSize(width: 1280, height: 800)
        .windowToolbarStyle(.unified(showsTitle: false))
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
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
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
