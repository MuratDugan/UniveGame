import Foundation

import AppKit

/// Finds artwork for a game the user added by hand, the way media servers match titles: the Steam store first
/// (in the app's language: portrait capsule and wide hero image), then Wikipedia, whose article image is free to
/// fetch and covers games that aren't on Steam (Genshin Impact, Metin2…). Only the game's name is sent, and only
/// when the game has no cover yet or the user asks. A wrong cover is worse than none, so only exact title matches
/// count.
struct CoverSuggestion: Equatable {
    let name: String
    let cover: URL
    let hero: URL?
    /// The image is a wide logo, not a box cover: it's set on a portrait card instead of being cropped.
    var isLogo = false
}

enum CoverFinder {
    static func find(title: String, languageCode: String) async -> CoverSuggestion? {
        let queries = searchTitles(for: title)
        for query in queries {
            if let found = await steam(query, languageCode: languageCode) { return found }
        }
        for query in queries {
            if let found = await wikipedia(query) { return found }
        }
        return nil
    }

    /// The title, then without trailing words that name the program rather than the game ("Genshin Impact game",
    /// "Foo Launcher", "Bar x64").
    static func searchTitles(for title: String) -> [String] {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        var words = trimmed.split(separator: " ").map(String.init)
        let extra: Set<String> = ["game", "launcher", "client", "x64", "x86", "win64", "win32", "pc", "setup"]
        while words.count > 1, let last = words.last, extra.contains(last.lowercased()) { words.removeLast() }
        let cleaned = words.joined(separator: " ")
        return cleaned == trimmed ? [trimmed] : [trimmed, cleaned]
    }

    private static func steam(_ query: String, languageCode: String) async -> CoverSuggestion? {
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
        return CoverSuggestion(name: best.name, cover: cover, hero: hero)
    }

    // MARK: Wikipedia

    private static let userAgent = "UniveGame (https://github.com/MuratDugan/UniveGame)"   // Wikimedia asks for one

    /// The English Wikipedia article whose title is the game's (or "<game> (video game)") and that describes a
    /// game, and its lead image.
    private static func wikipedia(_ query: String) async -> CoverSuggestion? {
        var search = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        search.queryItems = [.init(name: "action", value: "query"), .init(name: "list", value: "search"),
                             .init(name: "srsearch", value: query + " video game"), .init(name: "srlimit", value: "5"),
                             .init(name: "format", value: "json")]
        guard let root = await json(search.url!) as? [String: Any],
              let results = (root["query"] as? [String: Any])?["search"] as? [[String: Any]] else { return nil }
        let titles = results.compactMap { $0["title"] as? String }
        guard let article = wikipediaMatch(for: query, in: titles),
              let encoded = article.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let summaryURL = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/" + encoded),
              let summary = await json(summaryURL) as? [String: Any],
              let description = summary["description"] as? String, description.localizedCaseInsensitiveContains("game")
        else { return nil }
        let original = summary["originalimage"] as? [String: Any]
        let thumbnail = summary["thumbnail"] as? [String: Any]
        // Very large originals (photos) are fetched at thumbnail size instead.
        let pick = ((original?["width"] as? Int) ?? 0) > 1600 ? thumbnail : (original ?? thumbnail)
        guard let source = pick?["source"] as? String, let url = URL(string: source),
              let width = pick?["width"] as? Int, let height = pick?["height"] as? Int, width > 0, height > 0 else { return nil }
        return CoverSuggestion(name: article, cover: url, hero: nil, isLogo: Double(width) / Double(height) > 1.1)
    }

    /// The search result that is the game itself: same title, maybe with Wikipedia's "(video game)" or
    /// "(2020 video game)" note.
    static func wikipediaMatch(for query: String, in titles: [String]) -> String? {
        let key = InstallScanner.normalized(query)
        guard !key.isEmpty else { return nil }
        return titles.first { title in
            let base = title.replacingOccurrences(of: #"\s*\((\d{4} )?video game\)$"#, with: "", options: .regularExpression)
            return InstallScanner.normalized(base) == key
        }
    }

    private static func json(_ url: URL) async -> Any? {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// A wide logo centred on a 600×900 card, so it reads as a cover instead of being cropped. The card is dark,
    /// or light when the logo itself is dark (Genshin Impact's is black on transparent).
    static func portraitCard(fromLogo file: URL) -> URL? {
        guard let logo = NSImage(contentsOf: file), logo.size.width > 0, logo.size.height > 0 else { return nil }
        let background = (averageLuminance(of: logo) ?? 1) < 0.35 ? NSColor(calibratedWhite: 0.92, alpha: 1)
                                                                    : NSColor(calibratedWhite: 0.11, alpha: 1)
        let size = NSSize(width: 600, height: 900)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        background.setFill()
        NSRect(origin: .zero, size: size).fill()
        let scale = min(480 / logo.size.width, 300 / logo.size.height)
        let drawn = NSSize(width: logo.size.width * scale, height: logo.size.height * scale)
        logo.draw(in: NSRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                             width: drawn.width, height: drawn.height))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let target = file.deletingPathExtension().appendingPathExtension("card.png")
        guard (try? png.write(to: target)) != nil else { return nil }
        return target
    }

    /// Mean brightness (0–1) of the image's visible pixels, from a small copy.
    static func averageLuminance(of image: NSImage) -> Double? {
        let side = 64
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        var sum = 0.0, weight = 0.0
        for x in 0..<side { for y in 0..<side {
            guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.5 else { continue }
            sum += 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
            weight += 1
        } }
        return weight > 0 ? sum / weight : nil
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
