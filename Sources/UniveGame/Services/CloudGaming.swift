import AppKit
import Foundation

/// Playing a game that can't run on a Mac in the cloud instead: its own PC runs it on NVIDIA's servers, so
/// anti-cheat is no obstacle and the account is safe. GeForce NOW lists games bought on Steam, Epic, Ubisoft and
/// HoYoverse's own launcher.
enum CloudGaming {
    /// Games NVIDIA has announced on GeForce NOW (normalized titles). Only ones known for sure: a game shown as
    /// "on GeForce NOW" that isn't would send the player somewhere useless.
    static let onGeForceNow: Set<String> = Set([
        "Genshin Impact", "Honkai: Star Rail", "Zenless Zone Zero", "Fortnite", "Apex Legends", "Destiny 2",
        "Counter-Strike 2", "Tom Clancy's Rainbow Six Siege", "Rust", "Marvel Rivals",
    ].map(InstallScanner.normalized))

    static func isOnGeForceNow(_ title: String) -> Bool {
        CoverFinder.searchTitles(for: title).contains { title in
            let key = InstallScanner.normalized(title)
            return onGeForceNow.contains(key) || onGeForceNow.contains(InstallScanner.normalized(CompatibilitySignals.baseTitle(title)))
        }
    }

    static let geForceNowWeb = URL(string: "https://play.geforcenow.com")!
    /// NVIDIA's Mac app, when it's installed.
    static let geForceNowAppID = "com.nvidia.gfnpc.mall"

    /// Opens GeForce NOW: the Mac app if it's installed, the web player otherwise.
    static func openGeForceNow() {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: geForceNowAppID) {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(geForceNowWeb)
        }
    }
}
