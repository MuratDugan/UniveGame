import Foundation

/// Community and store data about a game, fetched only when the user asks for an analysis.
/// Requests go to ProtonDB, Steam and GitHub (AreWeAntiCheatYet) and carry only the game's id or name.
struct CompatibilitySignals {
    let cacheFolder: URL

    struct AntiCheatEntry: Decodable {
        struct StoreIDs: Decodable {
            struct Epic: Decodable { let namespace: String?; let slug: String? }
            let steam: String?
            let epic: Epic?
        }
        let name: String
        let status: String
        let anticheats: [String]
        let storeIds: StoreIDs?
        let native: Bool?
    }

    // MARK: AreWeAntiCheatYet

    /// The anti-cheat database, cached for a day.
    func antiCheatDatabase() async -> [AntiCheatEntry] {
        let file = cacheFolder.appendingPathComponent("arewe-anticheat.json")
        let fresh = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            .map { Date().timeIntervalSince($0) < 86_400 } ?? false
        if !fresh, let url = URL(string: "https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/master/games.json"),
           let (data, response) = try? await URLSession.shared.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
        }
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([AntiCheatEntry].self, from: data)) ?? []
    }

    static func match(_ db: [AntiCheatEntry], steamAppID: String?, epicNamespace: String?, title: String) -> AntiCheatEntry? {
        if let id = steamAppID, let e = db.first(where: { $0.storeIds?.steam == id }) { return e }
        if let ns = epicNamespace, let e = db.first(where: { $0.storeIds?.epic?.namespace == ns }) { return e }
        let key = InstallScanner.normalized(title)
        guard key.count >= 4 else { return nil }
        if let e = db.first(where: { InstallScanner.normalized($0.name) == key }) { return e }
        // "Grand Theft Auto V Enhanced", "… Legacy", "… Definitive Edition": same game, same anti-cheat.
        let base = InstallScanner.normalized(baseTitle(title))
        guard base != key, base.count >= 4 else { return nil }
        return db.first { InstallScanner.normalized(baseTitle($0.name)) == base }
    }

    static let editionSuffixes = ["enhanced edition", "enhanced", "legacy", "definitive edition", "complete edition",
                                  "game of the year edition", "goty edition", "goty", "remastered", "deluxe edition",
                                  "ultimate edition", "gold edition", "director's cut", "anniversary edition"]

    /// The title without an edition suffix.
    static func baseTitle(_ title: String) -> String {
        var t = title.trimmingCharacters(in: .whitespaces)
        for suffix in editionSuffixes {
            let lower = t.lowercased()
            for sep in [" - ", " – ", ": ", " "] where lower.hasSuffix(sep + suffix) {
                t = String(t.dropLast(sep.count + suffix.count)).trimmingCharacters(in: .whitespaces)
                return t
            }
        }
        return t
    }

    /// Games that start through the Rockstar Games Launcher whichever store sold them.
    static func rockstarLauncherNeeded(_ title: String) -> Bool {
        title.range(of: #"(?i)\b(grand theft auto|red dead redemption|l\.a\. noire|max payne 3|bully)\b"#, options: .regularExpression) != nil
    }

    // MARK: ProtonDB

    struct ProtonSummary: Decodable { let tier: String?; let confidence: String?; let total: Int? }

    func protonDB(appID: String) async -> ProtonSummary? {
        guard let url = URL(string: "https://www.protondb.com/api/v1/reports/summaries/\(appID).json"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(ProtonSummary.self, from: data)
    }

    // MARK: Steam store

    /// DirectX version from the store's minimum requirements, and whether a Mac version exists.
    func steamRequirements(appID: String) async -> (directX: Int?, mac: Bool, gpuDX11: Bool)? {
        var c = URLComponents(string: "https://store.steampowered.com/api/appdetails")!
        c.queryItems = [.init(name: "appids", value: appID), .init(name: "l", value: "english")]
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = root[appID] as? [String: Any], entry["success"] as? Bool == true,
              let info = entry["data"] as? [String: Any] else { return nil }
        let mac = (info["platforms"] as? [String: Bool])?["mac"] ?? false
        let req = info["pc_requirements"] as? [String: Any]
        let text = ((req?["minimum"] as? String) ?? "") + " " + ((req?["recommended"] as? String) ?? "")
        return (Self.directXVersion(inRequirements: text), mac, Self.gpuSuggestsDX11(text))
    }

    /// GTX 400+/RTX, Radeon HD 5000+/R7/R9/RX, Intel HD 4000+/Iris/Arc: DirectX 11-class hardware.
    static func gpuSuggestsDX11(_ html: String) -> Bool {
        let text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let pattern = #"(?i)\b(gtx\s?(4|5|6|7|9)\d{2}|gtx\s?1\d{3}|rtx|radeon\s+hd\s?[5-8]\d{3}|\br[79]\s?\d{3}|\brx\s?\d{3,4}|vega|iris|intel\s+arc|hd\s+graphics\s+[45]\d{2,3})"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    /// "DirectX: Version 11", "DirectX 10+ support", "DX12" → the lowest version the game asks for.
    static func directXVersion(inRequirements html: String) -> Int? {
        let text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let patterns = [#"(?i)directx\s*:?\s*(?:version\s*)?(\d{1,2})"#, #"(?i)\bdx\s?(\d{1,2})\b"#]
        var versions: [Int] = []
        for p in patterns {
            let re = try! NSRegularExpression(pattern: p)
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(m.range(at: 1), in: text), let v = Int(text[r]), (7...12).contains(v) { versions.append(v) }
            }
        }
        return versions.min()
    }

    /// The Steam app id for a title (Epic games), by exact name match in the store search.
    func steamAppID(forTitle title: String) async -> String? {
        var c = URLComponents(string: "https://store.steampowered.com/api/storesearch/")!
        c.queryItems = [.init(name: "term", value: title), .init(name: "l", value: "english"), .init(name: "cc", value: "US")]
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]] else { return nil }
        let key = InstallScanner.normalized(title)
        return items.first { InstallScanner.normalized($0["name"] as? String ?? "") == key }
            .flatMap { ($0["id"] as? Int).map(String.init) }
    }
}
