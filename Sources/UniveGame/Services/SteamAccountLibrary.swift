import Foundation
import UniveEngineKit

/// The signed-in user's whole Steam library, read from the Steam client's own files inside the bottle.
/// UniveEngine's `SteamLibrary.scan` only sees installed games; this adds everything the account owns,
/// with the artwork and play time Steam already cached. Nothing is sent anywhere.
enum SteamAccountLibrary {
    struct Account: Equatable {
        let steamID64: String
        let personaName: String
        /// The folder name under `userdata` (the 32-bit account id).
        var accountID: String {
            guard let id = UInt64(steamID64), id > 76_561_197_960_265_728 else { return steamID64 }
            return String(id - 76_561_197_960_265_728)
        }
    }

    struct Activity: Equatable {
        var lastPlayed: Date?
        var playTime: TimeInterval
    }

    // MARK: Account

    /// The account Steam signed in with last (`config/loginusers.vdf`).
    static func currentAccount(steamDirectory: URL) -> Account? {
        guard let text = try? String(contentsOf: steamDirectory.appendingPathComponent("config/loginusers.vdf"), encoding: .utf8),
              let users = (try? VDFParser.parse(text))?.child("users")?.entries, !users.isEmpty else { return nil }
        let best = users.first { $0.value.child("MostRecent")?.string == "1" } ?? users[0]
        return Account(steamID64: best.key, personaName: best.value.child("PersonaName")?.string ?? best.key)
    }

    // MARK: Owned games

    /// Games in the library: apps Steam keeps library artwork for, that `appinfo.vdf` says are games.
    static func ownedGames(steamDirectory: URL) -> [Game] {
        let cache = steamDirectory.appendingPathComponent("appcache/librarycache", isDirectory: true)
        let libraryIDs = ((try? FileManager.default.contentsOfDirectory(atPath: cache.path)) ?? []).compactMap(UInt32.init)
        guard !libraryIDs.isEmpty,
              let data = try? Data(contentsOf: steamDirectory.appendingPathComponent("appcache/appinfo.vdf"), options: .mappedIfSafe)
        else { return [] }
        let info = AppInfoReader.read(data, only: Set(libraryIDs))

        return libraryIDs.compactMap { id -> Game? in
            guard let app = info[id], app.type == "game", let name = app.name, !name.isEmpty else { return nil }
            let art = artwork(in: cache.appendingPathComponent(String(id), isDirectory: true))
            let appID = String(id)
            return Game(store: .steam, storeID: appID, title: name, isInstalled: false,
                        coverURL: art.cover ?? SteamLibrary.artworkURL(appID: appID, "library_600x900.jpg"),
                        heroURL: art.hero ?? SteamLibrary.artworkURL(appID: appID, "library_hero.jpg"))
        }
    }

    /// Steam stores artwork under hashed sub-folders; pick the portrait capsule and the wide hero.
    static func artwork(in folder: URL) -> (cover: URL?, hero: URL?) {
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return (nil, nil) }
        var files: [String: URL] = [:]
        for case let url as URL in walker where url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "png" {
            files[url.deletingPathExtension().lastPathComponent.lowercased()] = url
        }
        let cover = files["library_600x900_2x"] ?? files["library_600x900"] ?? files["library_capsule"]
        let hero = files["library_hero"] ?? files["library_header"] ?? files["header"]
        return (cover, hero)
    }

    // MARK: Play time

    /// Last played and play time per app id, from `userdata/<account>/config/localconfig.vdf`.
    static func activity(steamDirectory: URL, account: Account) -> [String: Activity] {
        let file = steamDirectory.appendingPathComponent("userdata/\(account.accountID)/config/localconfig.vdf")
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let apps = (try? VDFParser.parse(text))?
                .child("UserLocalConfigStore")?.child("Software")?.child("Valve")?.child("Steam")?.child("apps")?.entries
        else { return [:] }
        var result: [String: Activity] = [:]
        for (id, app) in apps {
            let last = app.child("LastPlayed")?.string.flatMap(TimeInterval.init).flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
            let minutes = app.child("Playtime")?.string.flatMap(Double.init) ?? 0
            if last != nil || minutes > 0 { result[id] = Activity(lastPlayed: last, playTime: minutes * 60) }
        }
        return result
    }
}

extension VDFValue {
    /// Steam isn't consistent about key case ("apps" / "Apps"), so match without it.
    func child(_ key: String) -> VDFValue? {
        entries?.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }
}

/// Reads Steam's binary `appcache/appinfo.vdf` (formats 27, 28 and 29) for each app's name and type.
enum AppInfoReader {
    struct App: Equatable {
        var name: String?
        var type: String?
        var oslist: String?
        /// Steam Deck verdict: 1 unsupported, 2 playable, 3 verified.
        var deckCategory: Int?
        var deckTokens: [String] = []
        var releaseDate: Int?
    }

    static func read(_ data: Data, only wanted: Set<UInt32>? = nil) -> [UInt32: App] {
        var r = ByteReader(data)
        guard let magic = r.u32(), r.u32() != nil else { return [:] }
        let version = magic & 0xFF // 0x27, 0x28 or 0x29 (the magic's last byte reads like the format number)
        guard magic >> 8 == 0x075644, (0x27...0x29).contains(version) else { return [:] }

        var strings: [String]?
        if version >= 0x29 {
            guard let tableOffset = r.i64(), let table = stringTable(data, at: Int(tableOffset)) else { return [:] }
            strings = table
        }

        var apps: [UInt32: App] = [:]
        while let appID = r.u32(), appID != 0, let size = r.u32() {
            let end = r.offset + Int(size)
            defer { r.offset = end }
            guard end <= data.count, wanted?.contains(appID) ?? true else { continue }
            // infoState, lastUpdated, picsToken, sha1, changeNumber, (v28+) binary sha1
            r.offset += 4 + 4 + 8 + 20 + 4 + (version >= 0x28 ? 20 : 0)
            var kv = KeyValueReader(reader: r, strings: strings, end: end)
            if let app = kv.readApp() { apps[appID] = app }
        }
        return apps
    }

    private static func stringTable(_ data: Data, at offset: Int) -> [String]? {
        var r = ByteReader(data)
        r.offset = offset
        guard let count = r.u32() else { return nil }
        var table: [String] = []
        table.reserveCapacity(Int(count))
        for _ in 0..<count {
            guard let s = r.cString() else { return nil }
            table.append(s)
        }
        return table
    }

    /// Walks the binary key-values and keeps `appinfo/common/name` and `/type`.
    private struct KeyValueReader {
        var reader: ByteReader
        let strings: [String]?
        let end: Int

        mutating func key() -> String? {
            if let strings {
                guard let i = reader.u32(), Int(i) < strings.count else { return nil }
                return strings[Int(i)]
            }
            return reader.cString()
        }

        mutating func readApp() -> App? {
            var app = App()
            return walk(path: [], app: &app) ? app : nil
        }

        /// Returns false on malformed data.
        mutating func walk(path: [String], app: inout App) -> Bool {
            while reader.offset < end {
                guard let type = reader.u8() else { return false }
                if type == 0x08 || type == 0x0B { return true }
                guard let k = key() else { return false }
                switch type {
                case 0x00:
                    if !walk(path: path + [k], app: &app) { return false }
                case 0x01:
                    guard let value = reader.cString() else { return false }
                    if path.count == 2, path[0] == "appinfo", path[1] == "common" {
                        switch k {
                        case "name": app.name = value
                        case "type": app.type = value.lowercased()
                        case "oslist": app.oslist = value.lowercased()
                        case "original_release_date", "steam_release_date": app.releaseDate = app.releaseDate ?? Int(value)
                        default: break
                        }
                    }
                    if path.count == 5, path[2] == "steam_deck_compatibility", path[3] == "tests", k == "token" {
                        app.deckTokens.append(value)
                    }
                case 0x02:
                    guard let raw = reader.u32() else { return false }
                    let value = Int(Int32(bitPattern: raw))
                    if path.count == 3, path[1] == "common", path[2] == "steam_deck_compatibility", k == "category" {
                        app.deckCategory = value
                    }
                    if path.count == 2, path[1] == "common", k == "original_release_date" || k == "steam_release_date" {
                        app.releaseDate = app.releaseDate ?? value
                    }
                case 0x03, 0x04, 0x06: reader.offset += 4
                case 0x07, 0x0A: reader.offset += 8
                case 0x05: // UTF-16 string, null-terminated
                    while let unit = reader.u16(), unit != 0 {}
                default: return false
                }
            }
            return true
        }
    }
}

struct ByteReader {
    let data: Data
    var offset = 0
    init(_ data: Data) { self.data = data }

    private mutating func take<T: FixedWidthInteger>(_: T.Type) -> T? {
        let n = MemoryLayout<T>.size
        guard offset >= 0, offset + n <= data.count else { return nil }
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { dst in
            data.copyBytes(to: dst.bindMemory(to: UInt8.self), from: data.startIndex + offset ..< data.startIndex + offset + n)
        }
        offset += n
        return T(littleEndian: value)
    }

    mutating func u8() -> UInt8? { take(UInt8.self) }
    mutating func u16() -> UInt16? { take(UInt16.self) }
    mutating func u32() -> UInt32? { take(UInt32.self) }
    mutating func i64() -> Int64? { take(Int64.self) }

    mutating func cString() -> String? {
        guard offset < data.count,
              let zero = data[(data.startIndex + offset)...].firstIndex(of: 0) else { return nil }
        let s = String(decoding: data[(data.startIndex + offset)..<zero], as: UTF8.self)
        offset = zero - data.startIndex + 1
        return s
    }
}

/// Reads `appinfo.vdf` once per analysis run.
enum AppInfoReaderCache {
    static func load(steamDirectory: URL) -> [UInt32: AppInfoReader.App] {
        guard let data = try? Data(contentsOf: steamDirectory.appendingPathComponent("appcache/appinfo.vdf"), options: .mappedIfSafe)
        else { return [:] }
        return AppInfoReader.read(data)
    }
}
