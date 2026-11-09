import Foundation
import UniveEngineKit

/// Wine's `EmulateModeset`: games that change the screen resolution get a scaled picture instead of the Mac's
/// display actually switching modes, and they see Wine's standard list of resolutions (1280×720, 1920×1080…)
/// next to the Mac's own. Mac screens have no 16:9 modes, and some games only accept 16:9 (Anomaly Agent's start
/// screen crashes on an empty list and stays black). Proton works this way by default. The list is built when an
/// environment starts, so it's set while the environment is idle.
enum DisplayModes {
    static let key = #"HKCU\Software\Wine\X11 Driver"#
    static let value = "EmulateModeset"

    /// The bottle's current setting from its `user.reg` (what the next wineserver loads); nil when it's unset or
    /// not one Wine reads as a flag.
    static func current(inUserReg text: String) -> Bool? {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard let header = lines.firstIndex(where: { $0.lowercased().hasPrefix(#"[software\\wine\\x11 driver]"#) }) else { return nil }
        let prefix = "\"\(value.lowercased())\"=\""
        for line in lines[(header + 1)...] {
            let line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("[") { break }
            if line.lowercased().hasPrefix(prefix) { return MacDriver.flag(String(line.dropFirst(prefix.count))) }
        }
        return nil
    }

    /// `wine reg` arguments that make the setting `on`.
    static func command(on: Bool) -> [String] {
        ["reg", "add", key, "/v", value, "/t", "REG_SZ", "/d", on ? "Y" : "N", "/f"]
    }
}
