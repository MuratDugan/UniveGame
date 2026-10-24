import AppKit
import Foundation

/// How players said a game runs: the reports UniveEngine's repository counts from its "Compatibility report" form
/// (`engine/compat-reports.json`). Sending one opens that form in the browser, filled in, for the player to submit
/// with their own GitHub account; UniveGame holds no key and sends nothing itself.
struct CommunityReports: Codable, Equatable {
    struct Report: Codable, Equatable {
        var result: String
        var backend: String?
        var engine: String?
        var mac: String?
        var macos: String?
        var date: String?
    }
    struct Entry: Codable, Equatable {
        var title: String
        var counts: [String: Int]
        var recent: [Report]
    }
    var games: [String: Entry]

    static let url = URL(string: "https://raw.githubusercontent.com/MuratDugan/UniveEngine/main/engine/compat-reports.json")!
    static let formURL = URL(string: "https://github.com/MuratDugan/UniveEngine/issues/new")!

    /// Results in the order the form lists them.
    static let results = ["great", "playable", "unplayable", "broken"]
    static let formLabels = ["great": "Works great", "playable": "Playable with issues",
                             "unplayable": "Starts but isn't playable", "broken": "Doesn't start"]

    /// The filled-in form for one report.
    static func form(gameID: String, title: String, result: String, backend: String, engine: String,
                     mac: String, macOS: String, app: String) -> URL? {
        var c = URLComponents(url: formURL, resolvingAgainstBaseURL: false)
        c?.queryItems = [
            URLQueryItem(name: "template", value: "compat-report.yml"),
            URLQueryItem(name: "title", value: "Compatibility: \(title)"),
            URLQueryItem(name: "game_id", value: gameID),
            URLQueryItem(name: "game_title", value: title),
            URLQueryItem(name: "result", value: formLabels[result]),
            URLQueryItem(name: "backend", value: backend),
            URLQueryItem(name: "engine", value: engine),
            URLQueryItem(name: "mac", value: mac),
            URLQueryItem(name: "macos", value: macOS),
            URLQueryItem(name: "app_version", value: app),
        ]
        return c?.url
    }
}
