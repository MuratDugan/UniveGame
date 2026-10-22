import Foundation

/// Steam's public storefront API (no account needed), for the Discover page.
struct StoreListing: Identifiable, Hashable {
    let id: Int
    let name: String
    let imageURL: URL?
    let finalPrice: Int?        // in cents
    let originalPrice: Int?
    let discountPercent: Int
    let currency: String?
    let isFree: Bool
    /// Listed under Steam's "New releases".
    var isNew = false

    var storeURL: URL { URL(string: "https://store.steampowered.com/app/\(id)/")! }
    /// Newer apps keep artwork under a hashed folder, so the API's own image path is used.
    var artworkURL: URL? {
        imageURL ?? URL(string: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(id)/header.jpg")
    }

    /// The 616×353 capsule next to the API's image, sharper on large tiles (falls back to `artworkURL`).
    var largeArtworkURL: URL? {
        guard let url = imageURL?.absoluteString, url.contains("capsule_467x181") else { return nil }
        return URL(string: url.replacingOccurrences(of: "capsule_467x181", with: "capsule_616x353"))
    }

    func formattedPrice(locale: Locale) -> String? {
        guard let finalPrice, let currency else { return nil }
        return (Double(finalPrice) / 100).formatted(.currency(code: currency).locale(locale))
    }

    func formattedOriginalPrice(locale: Locale) -> String? {
        guard let originalPrice, let currency, discountPercent > 0 else { return nil }
        return (Double(originalPrice) / 100).formatted(.currency(code: currency).locale(locale))
    }
}

struct SteamStoreAPI {
    var languageCode: String   // "turkish" / "english"
    var countryCode: String    // "TR" / "US"

    init(appLanguage code: String) {
        languageCode = code == "tr" ? "turkish" : "english"
        countryCode = code == "tr" ? "TR" : "US"
    }

    func featured() async throws -> [StoreListing] {
        var c = URLComponents(string: "https://store.steampowered.com/api/featuredcategories/")!
        c.queryItems = [.init(name: "cc", value: countryCode), .init(name: "l", value: languageCode)]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        let decoded = try JSONDecoder().decode(FeaturedCategories.self, from: data)
        var seen = Set<Int>()
        let newIDs = Set((decoded.new_releases?.items ?? []).map(\.id))
        let items = (decoded.specials?.items ?? []) + (decoded.top_sellers?.items ?? []) + (decoded.new_releases?.items ?? [])
        return items.compactMap { item in
            guard item.type == nil || item.type == 0, seen.insert(item.id).inserted else { return nil }
            return StoreListing(id: item.id, name: item.name,
                                imageURL: item.large_capsule_image.flatMap(URL.init(string:)),
                                finalPrice: item.final_price, originalPrice: item.original_price,
                                discountPercent: item.discount_percent ?? 0, currency: item.currency,
                                isFree: (item.final_price ?? 1) == 0, isNew: newIDs.contains(item.id))
        }
    }

    func search(_ term: String) async throws -> [StoreListing] {
        var c = URLComponents(string: "https://store.steampowered.com/api/storesearch/")!
        c.queryItems = [.init(name: "term", value: term), .init(name: "cc", value: countryCode), .init(name: "l", value: languageCode)]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.items.map { item in
            // tiny_image is 231×87; the header in the same folder is 460×215.
            StoreListing(id: item.id, name: item.name,
                         imageURL: item.tiny_image.flatMap { URL(string: $0.replacingOccurrences(of: "capsule_231x87", with: "header")) },
                         finalPrice: item.price?.final, originalPrice: item.price?.initial,
                         discountPercent: item.price.map { $0.initial > 0 ? Int((100 - Double($0.final) * 100 / Double($0.initial)).rounded()) : 0 } ?? 0,
                         // Search results carry no price both for free games and for unreleased ones, so a missing
                         // price shows as unknown rather than "Free".
                         currency: item.price?.currency, isFree: false)
        }
    }

    // MARK: Wire formats

    private struct FeaturedCategories: Decodable {
        struct Category: Decodable { let items: [Item]? }
        struct Item: Decodable {
            let id: Int
            let type: Int?
            let name: String
            let discount_percent: Int?
            let original_price: Int?
            let final_price: Int?
            let currency: String?
            let large_capsule_image: String?
        }
        let specials: Category?
        let top_sellers: Category?
        let new_releases: Category?
    }

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            struct Price: Decodable { let currency: String; let initial: Int; let final: Int }
            let id: Int
            let name: String
            let tiny_image: String?
            let price: Price?
        }
        let items: [Item]
    }
}
