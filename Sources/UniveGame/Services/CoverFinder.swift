import Foundation

/// Finds artwork for a game the user added by hand, the way media servers match titles: search the Steam
/// store (in the app's language) and take the portrait capsule and the wide hero image of the best match.
/// Only the game's name is sent, and only when the game has no cover yet or the user asks.
struct CoverSuggestion: Equatable {
    let appID: Int
    let name: String
    let cover: URL
    let hero: URL?
}

enum CoverFinder {
    static func find(title: String, languageCode: String) async -> CoverSuggestion? {
        let query = title.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return nil }
        var c = URLComponents(string: "https://store.steampowered.com/api/storesearch/")!
        c.queryItems = [.init(name: "term", value: query),
                        .init(name: "l", value: languageCode == "tr" ? "turkish" : "english"),
                        .init(name: "cc", value: languageCode == "tr" ? "TR" : "US")]
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]], !items.isEmpty else { return nil }

        guard let best = bestMatch(for: query, in: items.compactMap { item in
            (item["id"] as? Int).map { (id: $0, name: item["name"] as? String ?? "", tiny: item["tiny_image"] as? String) }
        }) else { return nil }

        let base = "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(best.id)/"
        // Most games still serve unhashed library art; newer ones only the header next to the search thumbnail.
        var cover: URL?
        for file in ["library_600x900_2x.jpg", "library_600x900.jpg"] {
            if let url = URL(string: base + file), await exists(url) { cover = url; break }
        }
        let header = best.tiny.flatMap { URL(string: $0.replacingOccurrences(of: "capsule_231x87", with: "header")) }
        guard let cover = cover ?? header else { return nil }
        var hero: URL? = URL(string: base + "library_hero.jpg")
        if let h = hero, !(await exists(h)) { hero = header }
        return CoverSuggestion(appID: best.id, name: best.name, cover: cover, hero: hero)
    }

    /// Exact (normalized) name first, then a result that contains the whole query, else nothing:
    /// a wrong cover is worse than none.
    static func bestMatch(for query: String, in items: [(id: Int, name: String, tiny: String?)]) -> (id: Int, name: String, tiny: String?)? {
        let key = InstallScanner.normalized(query)
        guard !key.isEmpty else { return nil }
        if let exact = items.first(where: { InstallScanner.normalized($0.name) == key }) { return exact }
        return items.first { item in
            let name = InstallScanner.normalized(item.name)
            return name.hasPrefix(key) && key.count >= 4
        }
    }

    static func exists(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    /// Downloads an image into `folder` as `<name>.<ext>` and returns the file.
    static func download(_ url: URL, into folder: URL, name: String) async throws -> URL {
        let (tmp, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let target = folder.appendingPathComponent("\(name).\(ext)")
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.moveItem(at: tmp, to: target)
        return target
    }
}
