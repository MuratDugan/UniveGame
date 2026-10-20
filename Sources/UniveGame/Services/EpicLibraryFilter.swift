import Foundation

/// `legendary list` returns everything the account owns on Epic, including Unreal Engine plugins, editors and
/// soundtrack/wallpaper packs. Keeps only games, using the metadata legendary already cached (no network).
enum EpicLibraryFilter {
    /// Epic catalog categories that are never something to play.
    static let excludedCategories: Set<String> = ["plugins", "engines", "digitalextras", "addons"]

    static func isGame(appName: String, title: String, metadataFolder: URL) -> Bool {
        if title.hasSuffix(" Bonus Content") { return false } // e.g. Cyberpunk 2077's wallpapers and soundtrack
        let file = metadataFolder.appendingPathComponent("\(appName).json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metadata = json["metadata"] as? [String: Any],
              let categories = metadata["categories"] as? [[String: Any]] else { return true } // unknown: keep
        let paths = Set(categories.compactMap { $0["path"] as? String })
        return paths.contains("games") && paths.isDisjoint(with: excludedCategories)
    }
}
