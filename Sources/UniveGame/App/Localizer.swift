import AppKit
import Foundation
import Observation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system, tr, en

    var id: String { rawValue }

    /// Shown in its own language so it can be found whatever the current language is.
    var nativeName: String {
        switch self {
        case .system: "System / Sistem"
        case .tr: "Türkçe"
        case .en: "English"
        }
    }
}

/// Looks strings up in `<lang>.lproj/Localizable.strings` and lets the user switch language
/// without restarting the app.
@MainActor
@Observable
final class Localizer {
    private static let defaultsKey = "appLanguage"

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
            table = Self.loadTable(code: resolvedCode)
        }
    }

    private var table: [String: String]
    private let fallback: [String: String]

    init() {
        // Carry the language over from the app's old name (dev.arcadia.launcher).
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
            ?? UserDefaults(suiteName: "dev.arcadia.launcher")?.string(forKey: Self.defaultsKey)
        let saved = stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
        language = saved
        fallback = Self.loadTable(code: "en")
        table = Self.loadTable(code: Self.code(for: saved))
    }

    var resolvedCode: String { Self.code(for: language) }
    var locale: Locale { Locale(identifier: resolvedCode == "tr" ? "tr_TR" : "en_US") }

    func callAsFunction(_ key: String) -> String {
        table[key] ?? fallback[key] ?? key
    }

    /// `"%@ games"`-style keys.
    func callAsFunction(_ key: String, _ args: CVarArg...) -> String {
        String(format: self(key), locale: locale, arguments: args)
    }

    private static func code(for language: AppLanguage) -> String {
        switch language {
        case .tr: return "tr"
        case .en: return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("tr") ? "tr" : "en"
        }
    }

    private static func loadTable(code: String) -> [String: String] {
        guard let url = ResourceBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(code).lproj"),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else { return [:] }
        return dict
    }
}

/// Finds the SwiftPM resource bundle both under `swift run` and inside the packaged `.app`
/// (where it lives in `Contents/Resources`, so the app's signature stays valid).
enum ResourceBundle {
    static let bundle: Bundle? = {
        let name = "UniveGame_UniveGame.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(name),
            Bundle.main.bundleURL.appendingPathComponent(name),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(name),
        ]
        for case let url? in candidates {
            if let b = Bundle(url: url) { return b }
        }
        return nil
    }()

    static func url(forResource name: String, withExtension ext: String, subdirectory: String) -> URL? {
        guard let base = bundle?.resourceURL ?? bundle?.bundleURL else { return nil }
        let url = base.appendingPathComponent(subdirectory).appendingPathComponent("\(name).\(ext)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

enum AppIcon {
    /// The app icon from the resource bundle (also used as the Dock icon under `swift run`).
    static let image: NSImage? = {
        guard let base = ResourceBundle.bundle?.resourceURL ?? ResourceBundle.bundle?.bundleURL else { return nil }
        return NSImage(contentsOf: base.appendingPathComponent("AppIcon.png"))
    }()
}
