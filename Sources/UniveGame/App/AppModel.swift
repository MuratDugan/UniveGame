import AppKit
import UniformTypeIdentifiers
import Foundation
import MacadeKit
import Observation

enum SidebarItem: Hashable {
    case library(LibraryFilter)
    case discover
    case stores
    case addGame
    case settings
}

enum SettingsSection: String, CaseIterable, Hashable {
    case general, engine, dx12, about
}

/// Status of a store connection, as shown on the Stores page.
enum StoreConnection: Equatable {
    case notSetUp       // helper/launcher missing
    case needsSignIn
    case ready
}

struct AppAlert: Identifiable {
    let id = UUID()
    let titleKey: String
    let message: String
}

struct EngineInstallProgress: Equatable {
    var phase: EnginePhase
    var fraction: Double
    /// Download size from the engine list (0 until known).
    var totalBytes: Int64 = 0
    var startedAt = Date()

    /// Seconds left in the download, estimated from the average speed so far.
    var secondsLeft: Double? {
        guard phase == .downloading, fraction > 0.02 else { return nil }
        let elapsed = Date().timeIntervalSince(startedAt)
        return elapsed / fraction * (1 - fraction)
    }
}

@MainActor
@Observable
final class AppModel {
    // MARK: State

    private(set) var state: LibraryState
    var selection: SidebarItem? = .library(.all)
    var searchText = ""
    var sort: LibrarySort = .title
    var alert: AppAlert?
    var showImport = false
    /// Bumped when the rail's Library item is clicked again: the library pops back to its shelves.
    var libraryReset = 0
    var settingsSection: SettingsSection = .dx12
    /// An .exe dropped on the window, picked up by the Add Game page.
    var pendingImportExecutable: URL?

    // MARK: Disclaimer

    /// Bump when the disclaimer text changes materially: everyone is asked to accept it again.
    static let disclaimerVersion = 1
    private(set) var disclaimerAcceptedAt: Date?
    /// Settings → About → "Read Again".
    var reviewingDisclaimer = false
    /// The first-launch disclaimer is waiting for an answer.
    var needsDisclaimer: Bool { disclaimerAcceptedAt == nil }

    func acceptDisclaimer() {
        let now = Date()
        disclaimerAcceptedAt = now
        guard !isDemo else { return }
        UserDefaults.standard.set(Self.disclaimerVersion, forKey: "disclaimerAcceptedVersion")
        UserDefaults.standard.set(now, forKey: "disclaimerAcceptedAt")
    }
    var editingCustomGame: CustomGame?
    var installer: InstallerSession?
    var pendingUninstall: CustomGame?

    private(set) var engines: [Engine] = []
    private(set) var running: [String: RunningProcess] = [:]
    private(set) var launching: Set<String> = []
    private(set) var refreshing = false
    private(set) var busyStores: Set<StoreKind> = []
    private(set) var engineInstall: EngineInstallProgress?
    private var engineInstallTask: Task<Void, Never>?
    private(set) var isDemo: Bool

    private let store = LibraryStateStore()
    private let paths = AppPaths.paths
    private let customPaths = Paths(home: AppPaths.home.appendingPathComponent("Custom", isDirectory: true))
    private var playStarts: [String: Date] = [:]

    static let engineManifestURL = URL(string: "https://mapc.games/engine-manifest.json")!

    /// Game page to open on launch (`--open <id>`, for development and screenshots).
    var pendingDetailID: String?

    init(demo: Bool = CommandLine.arguments.contains("--demo")) {
        isDemo = demo
        state = demo ? DemoData.state : LibraryStateStore().load()
        if demo {
            // The demo shows its shelves already scored; the hand-added game stays unanalyzed.
            var compat: [String: CompatReport] = [:]
            for item in items where item.customGame == nil { compat[item.id] = DemoData.compat(for: item) }
            state.compat = compat
        }
        let defaults = UserDefaults.standard
        if demo {
            disclaimerAcceptedAt = CommandLine.arguments.contains("--show-disclaimer") ? nil : Date()
        } else if defaults.integer(forKey: "disclaimerAcceptedVersion") >= Self.disclaimerVersion {
            disclaimerAcceptedAt = defaults.object(forKey: "disclaimerAcceptedAt") as? Date ?? Date()
        }
        reloadEngines()
        rescoreOutdatedReports()
        applyLaunchArguments()
    }

    /// `--section discover|stores|settings|import`, `--open <game id>`.
    private func applyLaunchArguments() {
        let args = CommandLine.arguments
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
            return args[i + 1]
        }
        switch value(after: "--section") {
        case "discover": selection = .discover
        case "stores": selection = .stores
        case "settings": selection = .settings
        case "import", "add": selection = .addGame
        case "dx12", "general", "engine", "about":
            selection = .settings
            settingsSection = SettingsSection(rawValue: value(after: "--section")!) ?? .dx12
        case let name? where StoreKind(rawValue: name) != nil: selection = .library(.source(.store(StoreKind(rawValue: name)!)))
        default: break
        }
        if let setup = value(after: "--install") {
            beginInstaller(URL(fileURLWithPath: setup))
            if args.contains("--no-runtime") { installer?.installRuntime = false }
            if args.contains("--start"), let session = installer { Task { await runInstaller(session) } }
        }
        pendingDetailID = value(after: "--open")
        if args.contains("--review-disclaimer") { reviewingDisclaimer = true }
        if args.contains("--analyze-all") { Task { await analyzeAll() } }
    }

    // MARK: Library

    var items: [LibraryItem] {
        let custom = state.customGames.map { LibraryItem(backing: .custom($0)) }
        let stores = state.storeGames.map { LibraryItem(backing: .store($0)) }
        return (stores + custom).map { item in
            var item = item
            item.isFavorite = state.favorites.contains(item.id)
            item.lastPlayed = state.lastPlayed[item.id]
            item.playTime = state.playTime[item.id] ?? 0
            return item
        }
    }

    func item(id: String) -> LibraryItem? { items.first { $0.id == id } }

    func visibleItems(for filter: LibraryFilter, locale: Locale) -> [LibraryItem] {
        var list = items.filter { matches($0, filter) }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            list = list.filter { $0.title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) != nil }
        }
        switch sort {
        case .title:
            list.sort { $0.title.compare($1.title, options: [.caseInsensitive, .numeric], locale: locale) == .orderedAscending }
        case .lastPlayed:
            list.sort { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .playTime:
            list.sort { $0.playTime > $1.playTime }
        case .compatibility:
            let compat = state.compat ?? [:]
            func key(_ id: String) -> Int { compat[id].map { $0.tier == .unknown ? -1 : $0.score } ?? -2 }
            list.sort { key($0.id) > key($1.id) }
        }
        if filter == .recent { list = Array(list.prefix(24)) }
        return list
    }

    func count(for filter: LibraryFilter) -> Int { items.filter { matches($0, filter) }.count }

    private func matches(_ item: LibraryItem, _ filter: LibraryFilter) -> Bool {
        switch filter {
        case .all: true
        case .installed: item.isInstalled
        case .favorites: item.isFavorite
        case .recent: item.lastPlayed != nil
        case .source(let s): item.source == s
        }
    }

    /// Sources that have at least one game, in a stable order, for the sidebar.
    var populatedSources: [GameSource] {
        let present = Set(items.map(\.source))
        return (StoreKind.allCases.map { GameSource.store($0) } + [.custom]).filter(present.contains)
    }

    func toggleFavorite(_ item: LibraryItem) {
        if state.favorites.contains(item.id) { state.favorites.remove(item.id) } else { state.favorites.insert(item.id) }
        persist()
    }

    // MARK: Custom games

    func addCustomGame(title: String, executable: URL, arguments: [String], cover: URL?,
                       installDirectory: URL? = nil, uninstaller: URL? = nil, suggestion: CoverSuggestion? = nil) throws {
        var game = CustomGame(title: title, executable: executable, arguments: arguments)
        game.installDirectory = installDirectory
        game.uninstaller = uninstaller
        if let cover { game.coverImage = try store.importCover(from: cover, for: game.id) }
        state.customGames.append(game)
        persist()
        selection = .library(.source(.custom))
        // Artwork found online is fetched after the game is in the library, so adding never waits on the network.
        if cover == nil, let suggestion { Task { await applyCover(suggestion, to: game.id) } }
        // The first look on the Add Game page was local only; the saved report also asks online sources.
        if !isDemo, let item = item(id: "custom:\(game.id.uuidString)") { Task { await analyze(item) } }
    }

    /// Downloads a found cover (and hero image) into the library's artwork folder.
    func applyCover(_ suggestion: CoverSuggestion, to id: UUID) async {
        let folder = AppPaths.customArtwork
        guard let cover = try? await CoverFinder.download(suggestion.cover, into: folder, name: id.uuidString) else { return }
        let hero = await { () -> URL? in
            guard let h = suggestion.hero else { return nil }
            return try? await CoverFinder.download(h, into: folder, name: id.uuidString + "-hero")
        }()
        guard let i = state.customGames.firstIndex(where: { $0.id == id }) else { return }
        ImageCache.shared.removeObject(forKey: cover as NSURL)
        state.customGames[i].coverImage = cover
        state.customGames[i].heroImage = hero
        persist()
    }

    private(set) var findingCover: Set<UUID> = []

    /// "Find Cover Online" for a game already in the library.
    func findCover(for game: CustomGame, languageCode: String) async {
        findingCover.insert(game.id)
        defer { findingCover.remove(game.id) }
        guard let suggestion = await CoverFinder.find(title: game.title, languageCode: languageCode) else {
            alert = AppAlert(titleKey: "cover.notFound", message: game.title)
            return
        }
        await applyCover(suggestion, to: game.id)
    }

    func updateCustomGame(_ game: CustomGame, newCover: URL?) throws {
        var game = game
        if let newCover, newCover != game.coverImage { game.coverImage = try store.importCover(from: newCover, for: game.id) }
        guard let index = state.customGames.firstIndex(where: { $0.id == game.id }) else { return }
        state.customGames[index] = game
        persist()
    }

    func removeCustomGame(_ game: CustomGame) {
        store.removeCover(of: game)
        state.customGames.removeAll { $0.id == game.id }
        let id = "custom:\(game.id.uuidString)"
        state.favorites.remove(id)
        state.lastPlayed[id] = nil
        state.playTime[id] = nil
        persist()
    }

    /// Windows executables that are clearly installers, not games.
    static func looksLikeInstaller(_ url: URL) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        return ["setup", "install", "unins", "redist", "vcredist", "dxsetup"].contains { name.contains($0) }
    }

    static func suggestedTitle(for exe: URL) -> String {
        // Prefer the folder name ("Hollow Knight/hollow_knight.exe" → "Hollow Knight").
        let folder = exe.deletingLastPathComponent().lastPathComponent
        let generic = ["bin", "binaries", "win64", "x64", "game", "release", "shipping"]
        let raw = generic.contains(folder.lowercased()) || folder.isEmpty ? exe.deletingPathExtension().lastPathComponent : folder
        return raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
    }

    // MARK: Installers

    /// The custom-games environment's C: drive (`drive_c`), where installers put games.
    var customDriveC: URL { Bottle(kind: .gog, paths: customPaths).driveC }

    /// Asks for a setup.exe / .msi and starts the installer flow.
    func chooseInstaller(message: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "exe") ?? .item, .init(filenameExtension: "msi") ?? .item]
        panel.allowsMultipleSelection = false
        panel.message = message
        if panel.runModal() == .OK, let url = panel.url { beginInstaller(url) }
    }

    /// A file dropped on the window: setup programs start the installer flow, other .exe files open Add Game.
    func handleDroppedFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ext == "exe" || ext == "msi" else { return }
        if ext == "msi" || Self.looksLikeInstaller(url) {
            beginInstaller(url)
        } else {
            pendingImportExecutable = url
            selection = .addGame
        }
    }

    func openSettings(_ section: SettingsSection) {
        settingsSection = section
        selection = .settings
    }

    func beginInstaller(_ setup: URL) {
        guard installer?.isBusy != true else { return }
        showImport = false
        installer = InstallerSession(setup: setup)
    }

    func cancelInstaller() {
        guard let session = installer else { return }
        session.waitTask?.cancel()
        if session.isBusy, let engine = engine(for: LaunchProfile()) {
            let bottle = Bottle(kind: .gog, paths: customPaths)
            Task { await WineRunner(paths: customPaths).killAll(engine: engine, bottle: bottle) }
        }
        installer = nil
    }

    /// Runs the installer like on Windows, waits for it (and anything it started) to finish, then
    /// looks for the programs it added.
    func runInstaller(_ session: InstallerSession) async {
        guard !isDemo else { alert = AppAlert(titleKey: "alert.demoTitle", message: ""); return }
        guard let engine = engine(for: LaunchProfile()) else {
            session.phase = .failed(L10nKey.noEngine)
            return
        }
        do {
            session.phase = .preparing
            let bottle = try await BottleManager(paths: customPaths).ensure(.gog, engine: engine)
            if session.installRuntime {
                session.phase = .installingRuntime
                try await WineMono(paths: customPaths).ensureInstalled(in: bottle, engine: engine)
            }
            let before = await Task.detached { InstallScanner.snapshot(driveC: bottle.driveC) }.value

            session.phase = .running
            let runStarted = Date()
            let status: Int32 = try await withCheckedThrowingContinuation { continuation in
                do {
                    // .msi packages go through Windows Installer; everything else runs directly.
                    let isMSI = session.setup.pathExtension.lowercased() == "msi"
                    let windowsPath = "Z:" + session.setup.path.replacingOccurrences(of: "/", with: "\\")
                    try WineRunner(paths: customPaths).run(
                        engine: engine, bottle: bottle, executable: isMSI ? "msiexec" : session.setup.path,
                        arguments: isMSI ? ["/i", windowsPath] : [],
                        workingDirectory: session.setup.deletingLastPathComponent(),
                        logID: "installer") { continuation.resume(returning: $0) }
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Many installers hand off to a helper and exit at once; wait for the whole environment
            // to go quiet. The user can skip this (e.g. when the installer started the game).
            session.phase = .finishing
            let env = WineRunner.environment(bottle: bottle, profile: LaunchProfile())
            let wait = Task { _ = try? await ProcessRunner.run(engine.wineserver, ["-w"], environment: env) }
            session.waitTask = wait
            await wait.value
            guard installer === session else { return } // cancelled meanwhile

            let after = await Task.detached { InstallScanner.snapshot(driveC: bottle.driveC) }.value
            let result = InstallScanner.scan(before: before, after: after, driveC: bottle.driveC)
            if result.candidates.isEmpty {
                // An error exit within seconds means the installer never showed its window: it crashed under Wine.
                let crashed = status != 0 && Date().timeIntervalSince(runStarted) < 20
                session.phase = .failed(crashed ? L10nKey.installerCrashed
                                        : (status == 0 ? L10nKey.nothingFound : L10nKey.installerFailed))
                return
            }
            session.result = result
            session.selected = result.candidates.first?.url
            session.title = result.installDirectory.map { InstallScanner.displayTitle(fromFolder: $0.lastPathComponent) }
                ?? AppModel.suggestedTitle(for: result.candidates[0].url)
            session.phase = .choosing
        } catch {
            session.phase = .failed(error.localizedDescription)
        }
    }

    func finishInstaller(_ session: InstallerSession, cover: URL?, suggestion: CoverSuggestion? = nil) {
        guard let exe = session.selected else { return }
        do {
            try addCustomGame(title: session.title.trimmingCharacters(in: .whitespaces), executable: exe, arguments: [],
                              cover: cover, installDirectory: session.result.installDirectory,
                              uninstaller: session.result.uninstaller, suggestion: suggestion)
            installer = nil
        } catch {
            session.phase = .failed(error.localizedDescription)
        }
    }

    /// Runs the game's own uninstaller when there is one; otherwise moves its folder to the Trash.
    func uninstall(_ game: CustomGame) async {
        pendingUninstall = nil
        do {
            if let uninstaller = game.uninstaller, FileManager.default.fileExists(atPath: uninstaller.path),
               let engine = engine(for: LaunchProfile()) {
                let bottle = Bottle(kind: .gog, paths: customPaths)
                let _: Int32 = try await withCheckedThrowingContinuation { continuation in
                    do {
                        try WineRunner(paths: customPaths).run(engine: engine, bottle: bottle, executable: uninstaller.path,
                                                               workingDirectory: uninstaller.deletingLastPathComponent(),
                                                               logID: "uninstaller") { continuation.resume(returning: $0) }
                    } catch { continuation.resume(throwing: error) }
                }
                let env = WineRunner.environment(bottle: bottle, profile: LaunchProfile())
                _ = try? await ProcessRunner.run(engine.wineserver, ["-w"], environment: env)
            } else if let folder = game.installDirectory, FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
            }
            removeCustomGame(game)
        } catch {
            alert = AppAlert(titleKey: "alert.uninstallFailed", message: error.localizedDescription)
        }
    }

    func revealDriveC() {
        try? FileManager.default.createDirectory(at: customDriveC, withIntermediateDirectories: true)
        NSWorkspace.shared.open(customDriveC)
    }

    // MARK: Compatibility analysis

    private(set) var analyzing: Set<String> = []
    private(set) var bulkAnalysis: (done: Int, total: Int)?
    private var bulkCancelled = false

    func compatReport(for item: LibraryItem) -> CompatReport? { state.compat?[item.id] }

    /// A Discover listing's score, when the same Steam game is in the library and was analyzed.
    func compatReport(steamAppID: Int) -> CompatReport? {
        let id = String(steamAppID)
        guard let game = state.storeGames.first(where: { $0.store == .steam && $0.storeID == id }) else { return nil }
        return state.compat?[game.id]
    }
    func isAnalyzing(_ item: LibraryItem) -> Bool { analyzing.contains(item.id) }

    private var compatSignals: CompatibilitySignals {
        CompatibilitySignals(cacheFolder: AppPaths.home.appendingPathComponent("Compatibility", isDirectory: true))
    }

    /// Reads the game's files (when installed) and asks Steam, ProtonDB and AreWeAntiCheatYet about it.
    func analyze(_ item: LibraryItem, antiCheatDB: [CompatibilitySignals.AntiCheatEntry]? = nil,
                 steamInfo: [UInt32: AppInfoReader.App]? = nil, useStoreAPI: Bool = true) async {
        guard !analyzing.contains(item.id) else { return }
        analyzing.insert(item.id)
        defer { analyzing.remove(item.id) }

        if isDemo {
            state.compat = (state.compat ?? [:]).merging([item.id: DemoData.compat(for: item)]) { $1 }
            return
        }

        // Local evidence
        var folders: [URL] = []
        if let custom = item.customGame { folders = [custom.installDirectory ?? custom.workingDirectory] }
        else if item.isInstalled, let path = item.installPath { folders = [path] }
        let files: FileFindings? = folders.isEmpty ? nil
            : await Task.detached(priority: .userInitiated) { GameFileAnalyzer.analyze(folders: folders) }.value

        // Store and community evidence
        let signals = compatSignals
        let db: [CompatibilitySignals.AntiCheatEntry]
        if let antiCheatDB { db = antiCheatDB } else { db = await signals.antiCheatDatabase() }
        var online = OnlineFindings()
        var steamID: String?
        var epicNamespace: String?
        if case .store(let game) = item.backing {
            switch game.store {
            case .steam:
                steamID = game.storeID
                let info = steamInfo ?? AppInfoReaderCache.load(steamDirectory: steamDirectory)
                if let id = UInt32(game.storeID), let app = info[id] {
                    online.steamDeckCategory = app.deckCategory
                    online.steamDeckAntiCheatIssue = app.deckTokens.contains { $0.contains("AntiCheat") }
                    online.hasMacVersion = app.oslist?.contains("macos") ?? false
                    online.releaseYear = app.releaseDate.map { Calendar(identifier: .gregorian).component(.year, from: Date(timeIntervalSince1970: TimeInterval($0))) }
                }
            case .epic:
                let meta = Self.epicMetadata(appName: game.storeID, metadata: paths.legendaryConfig.appendingPathComponent("metadata"))
                epicNamespace = meta.namespace
                online.thirdPartyLauncher = meta.launcher
            default: break
            }
        }
        if let entry = CompatibilitySignals.match(db, steamAppID: steamID, epicNamespace: epicNamespace, title: item.title) {
            online.antiCheatStatus = entry.status
            online.antiCheats = entry.anticheats
            if steamID == nil { steamID = entry.storeIds?.steam }
        }
        if steamID == nil, case .store = item.backing, useStoreAPI {
            steamID = await signals.steamAppID(forTitle: item.title)
        }
        online.steamAppID = steamID
        if let id = steamID {
            if let p = await signals.protonDB(appID: id) {
                online.protonTier = p.tier; online.protonConfidence = p.confidence; online.protonReports = p.total
            }
            // The store's requirements give the DirectX version when the files can't (game not installed).
            if useStoreAPI, files?.graphics.isEmpty ?? true, let req = await signals.steamRequirements(appID: id) {
                online.directXVersion = req.directX
                online.hasMacVersion = online.hasMacVersion || req.mac
                online.gpuSuggestsDX11 = req.gpuDX11
            }
        }

        enrichLocally(&online, item: item, antiCheatDB: db, steamInfo: steamInfo)
        let report = CompatibilityScorer.score(files: files, online: online, context: scoringContext(for: item))
        var all = state.compat ?? [:]
        all[item.id] = report
        state.compat = all
        persist()
    }

    /// Analyzes every game that has no recent result. Steam's store API is rate-limited, so it goes slowly.
    func analyzeAll() async {
        guard bulkAnalysis == nil else { return }
        let pending = items.filter { item in
            guard let r = state.compat?[item.id], r.version == CompatibilityScorer.version else { return true }
            return Date().timeIntervalSince(r.analyzedAt) > 7 * 86_400
        }
        guard !pending.isEmpty else { return }
        bulkCancelled = false
        bulkAnalysis = (0, pending.count)
        defer { bulkAnalysis = nil }
        let db = await compatSignals.antiCheatDatabase()
        let info = isDemo ? [:] : AppInfoReaderCache.load(steamDirectory: steamDirectory)
        for (i, item) in pending.enumerated() {
            if bulkCancelled { break }
            await analyze(item, antiCheatDB: db, steamInfo: info)
            bulkAnalysis = (i + 1, pending.count)
            if !isDemo { try? await Task.sleep(for: .milliseconds(900)) }
        }
    }

    func cancelBulkAnalysis() { bulkCancelled = true }

    /// Evidence that needs no network: Epic's metadata, the cached anti-cheat list (with edition-suffix
    /// fallback), Rockstar titles, and Steam's Deck verdict for Epic games the user also has on Steam.
    private func enrichLocally(_ online: inout OnlineFindings, item: LibraryItem,
                               antiCheatDB: [CompatibilitySignals.AntiCheatEntry]?, steamInfo: [UInt32: AppInfoReader.App]?) {
        var namespace: String?
        if case .store(let game) = item.backing, game.store == .epic {
            let meta = Self.epicMetadata(appName: game.storeID, metadata: paths.legendaryConfig.appendingPathComponent("metadata"))
            namespace = meta.namespace
            online.thirdPartyLauncher = online.thirdPartyLauncher ?? meta.launcher
        }
        if online.antiCheatStatus == nil, let db = antiCheatDB,
           let entry = CompatibilitySignals.match(db, steamAppID: online.steamAppID, epicNamespace: namespace, title: item.title) {
            online.antiCheatStatus = entry.status
            online.antiCheats = entry.anticheats
            online.steamAppID = online.steamAppID ?? entry.storeIds?.steam
        }
        if CompatibilitySignals.rockstarLauncherNeeded(item.title) { online.thirdPartyLauncher = "Rockstar Games Launcher" }
        if case .store(let game) = item.backing, game.store != .steam, online.steamDeckCategory == nil,
           let id = online.steamAppID.flatMap(UInt32.init) {
            let info = steamInfo ?? AppInfoReaderCache.load(steamDirectory: steamDirectory)
            if let app = info[id] {
                online.steamDeckCategory = app.deckCategory
                online.steamDeckAntiCheatIssue = app.deckTokens.contains { $0.contains("AntiCheat") }
                online.hasMacVersion = online.hasMacVersion || (app.oslist?.contains("macos") ?? false)
            }
        }
    }

    /// The anti-cheat list from the last analysis (no download).
    private var cachedAntiCheatDB: [CompatibilitySignals.AntiCheatEntry] {
        let file = AppPaths.home.appendingPathComponent("Compatibility/arewe-anticheat.json")
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([CompatibilitySignals.AntiCheatEntry].self, from: data)) ?? []
    }

    private func scoringContext(for item: LibraryItem) -> CompatibilityScorer.Context {
        CompatibilityScorer.Context(
            d3dMetalAvailable: engines.contains { $0.supports(.d3dMetal) },
            storeLauncher: { if case .store(let g) = item.backing, g.store.usesLauncher, g.store != .steam { return g.store.displayName }; return nil }(),
            knownIssue: knownIssue(for: item))
    }

    /// Add Game's "first look": a quick local scan of the chosen .exe's folder, scored without online sources.
    func firstLook(executable: URL) async -> (report: CompatReport, files: FileFindings) {
        let folder = executable.deletingLastPathComponent()
        let files = await Task.detached(priority: .userInitiated) { GameFileAnalyzer.analyze(folders: [folder]) }.value
        let context = CompatibilityScorer.Context(d3dMetalAvailable: d3dMetalReady)
        return (CompatibilityScorer.score(files: files, online: nil, context: context), files)
    }

    /// Reports from older rules are recomputed from their saved evidence (no network needed).
    private func rescoreOutdatedReports() {
        guard var all = state.compat, !isDemo else { return }
        var changed = false
        let outdated = items.filter { all[$0.id].map { $0.version != CompatibilityScorer.version } ?? false }
        guard !outdated.isEmpty else { return }
        let db = cachedAntiCheatDB
        let info = AppInfoReaderCache.load(steamDirectory: steamDirectory)
        for item in outdated {
            guard let old = all[item.id], old.files != nil || old.online != nil else { continue }
            var online = old.online ?? OnlineFindings()
            enrichLocally(&online, item: item, antiCheatDB: db, steamInfo: info)
            var fresh = CompatibilityScorer.score(files: old.files, online: online, context: scoringContext(for: item), now: old.analyzedAt)
            fresh.analyzedAt = old.analyzedAt
            all[item.id] = fresh
            changed = true
        }
        if changed { state.compat = all; persist() }
    }

    /// Epic's namespace (to match AreWeAntiCheatYet) and the third-party launcher it declares, if any.
    static func epicMetadata(appName: String, metadata: URL) -> (namespace: String?, launcher: String?) {
        guard let data = try? Data(contentsOf: metadata.appendingPathComponent("\(appName).json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = json["metadata"] as? [String: Any] else { return (nil, nil) }
        let attrs = meta["customAttributes"] as? [String: [String: Any]]
        let provider = (attrs?["ThirdPartyManagedProvider"]?["value"] as? String)?.lowercased() ?? ""
        let launcher: String? = provider.contains("ubisoft") || provider.contains("uplay") ? "Ubisoft Connect"
            : (provider.contains("origin") || provider.contains("ea") ? "EA app" : nil)
        return (meta["namespace"] as? String, launcher)
    }

    // MARK: Compatibility notes

    /// Notes from the engine list (`knownIssues`), fetched once per launch.
    private(set) var remoteKnownIssues: [String: String] = [:]

    func loadKnownIssues() async {
        guard !isDemo, remoteKnownIssues.isEmpty,
              let (data, _) = try? await URLSession.shared.data(from: Self.engineManifestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let issues = json["knownIssues"] as? [String: String] else { return }
        remoteKnownIssues = issues
    }

    /// A plain-language warning for games known not to work (e.g. kernel anti-cheat).
    func knownIssue(for item: LibraryItem) -> String? {
        guard case .store(let game) = item.backing else { return nil }
        return KnownIssues.note(for: game, remote: remoteKnownIssues)
    }

    // MARK: Profiles

    func profile(for item: LibraryItem) -> LaunchProfile {
        if let custom = item.customGame { return custom.profile }
        return state.profiles[item.id] ?? LaunchProfile()
    }

    func setProfile(_ profile: LaunchProfile, for item: LibraryItem) {
        if var custom = item.customGame, let i = state.customGames.firstIndex(where: { $0.id == custom.id }) {
            custom.profile = profile
            state.customGames[i] = custom
        } else {
            state.profiles[item.id] = profile
        }
        persist()
    }

    // MARK: Engines

    func reloadEngines() {
        var seen = Set<String>()
        engines = (EngineLocator(paths: paths).installed() + EngineLocator(paths: AppPaths.mapcPaths).installed())
            .filter { seen.insert($0.version).inserted }
    }

    var hasEngine: Bool { !engines.isEmpty }

    /// D3DMetal games get the CrossOver-based engine; everything else keeps the DXVK engine it was set up
    /// with, so installing the D3DMetal engine doesn't move existing games (and their environments) onto it.
    private func engine(for profile: LaunchProfile) -> Engine? {
        if profile.backend == .d3dMetal { return engines.first { $0.supports(.d3dMetal) } }
        if profile.backend != .auto && profile.backend != .wined3d,
           let match = engines.first(where: { $0.info.backends.contains(profile.backend.rawValue) && $0.supports(profile.backend) }) {
            return match
        }
        return engines.first { $0.info.backends.contains(GraphicsBackend.dxvk.rawValue) } ?? engines.first
    }

    func installEngine() async {
        guard engineInstall == nil else { return }
        engineInstall = EngineInstallProgress(phase: .downloading, fraction: 0)
        defer { engineInstall = nil }
        do {
            let manager = EngineManager(paths: paths)
            let manifest = try await manager.fetchManifest(from: Self.engineManifestURL)
            guard let entry = manifest.engines.max(by: { $0.version.compare($1.version, options: .numeric) == .orderedAscending }) else {
                throw EngineError.downloadFailed("empty engine list")
            }
            let total = entry.size
            let started = Date()
            engineInstall = EngineInstallProgress(phase: .downloading, fraction: 0, totalBytes: total, startedAt: started)
            try await manager.install(entry) { phase, fraction in
                Task { @MainActor [weak self] in
                    guard self?.engineInstall != nil else { return }
                    self?.engineInstall = EngineInstallProgress(phase: phase, fraction: fraction, totalBytes: total, startedAt: started)
                }
            }
            reloadEngines()
        } catch {
            alert = AppAlert(titleKey: "alert.engineFailed", message: error.localizedDescription)
        }
    }

    // MARK: DirectX 12 (D3DMetal)

    /// An engine built for D3DMetal (CrossOver-based) is installed.
    var hasD3DMetalEngine: Bool { engines.contains { D3DMetalStore.canUse($0) } }
    /// Apple's D3DMetal was imported from the user's Game Porting Toolkit download.
    var d3dMetalImported: Bool { D3DMetalStore(paths: paths).installed != nil }
    /// Both pieces are there: DirectX 12 games can run.
    var d3dMetalReady: Bool { engines.contains { $0.supports(.d3dMetal) } }

    /// Waiting for the user to accept Apple's license.
    var stagedD3DMetal: StagedD3DMetal?
    var stagedD3DMetalLicense: String = ""
    private(set) var importingD3DMetal = false

    /// Downloads the D3DMetal-ready engine from the engine list (checked with SHA-256 by MacadeKit).
    func startD3DMetalEngineInstall() {
        guard engineInstall == nil else { return }
        engineInstallTask = Task { await installD3DMetalEngine() }
    }

    /// Stops a running engine download (Settings → "Cancel").
    func cancelEngineInstall() {
        engineInstallTask?.cancel()
        engineInstallTask = nil
    }

    func installD3DMetalEngine() async {
        guard engineInstall == nil else { return }
        engineInstall = EngineInstallProgress(phase: .downloading, fraction: 0)
        defer { engineInstall = nil; engineInstallTask = nil }
        do {
            let manager = EngineManager(paths: paths)
            let manifest = try await manager.fetchManifest(from: Self.engineManifestURL)
            guard let entry = manifest.engines
                .filter({ ($0.backends ?? []).contains(GraphicsBackend.d3dMetal.rawValue) })
                .max(by: { $0.version.compare($1.version, options: .numeric) == .orderedAscending }) else {
                throw EngineError.downloadFailed("no D3DMetal engine in the list")
            }
            let total = entry.size
            let started = Date()
            engineInstall = EngineInstallProgress(phase: .downloading, fraction: 0, totalBytes: total, startedAt: started)
            try await manager.install(entry) { phase, fraction in
                Task { @MainActor [weak self] in
                    guard self?.engineInstall != nil else { return }
                    self?.engineInstall = EngineInstallProgress(phase: phase, fraction: fraction, totalBytes: total, startedAt: started)
                }
            }
            reloadEngines()
            // Link an already imported D3DMetal into the new engine.
            let store = D3DMetalStore(paths: paths)
            for engine in engines where D3DMetalStore.canUse(engine) { try? store.link(into: engine) }
            reloadEngines()
            rescoreAll()
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            alert = AppAlert(titleKey: "alert.engineFailed", message: error.localizedDescription)
        }
    }

    /// Checks Apple's signature and copies D3DMetal out of the Game Porting Toolkit; then asks for the license.
    func importD3DMetal(from source: URL) async {
        importingD3DMetal = true
        defer { importingD3DMetal = false }
        do {
            let staged = try await D3DMetalStore(paths: paths).stage(from: source)
            stagedD3DMetalLicense = staged.license.flatMap(Self.readLicense) ?? ""
            stagedD3DMetal = staged
        } catch {
            alert = AppAlert(titleKey: "d3dmetal.importFailed", message: error.localizedDescription)
        }
    }

    func acceptD3DMetalLicense() {
        guard let staged = stagedD3DMetal else { return }
        stagedD3DMetal = nil
        do {
            try D3DMetalStore(paths: paths).commit(staged, engines: engines.filter(D3DMetalStore.canUse))
            reloadEngines()
            rescoreAll()
        } catch {
            alert = AppAlert(titleKey: "d3dmetal.importFailed", message: error.localizedDescription)
        }
    }

    func declineD3DMetalLicense() {
        if let staged = stagedD3DMetal { D3DMetalStore(paths: paths).discard(staged) }
        stagedD3DMetal = nil
    }

    private static func readLicense(_ url: URL) -> String? {
        if url.pathExtension.lowercased() == "rtf",
           let text = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            return text.string
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Engines changed (e.g. D3DMetal installed): recompute every score from its saved evidence.
    func rescoreAll() {
        guard var all = state.compat else { return }
        for item in items {
            guard let old = all[item.id], old.files != nil || old.online != nil else { continue }
            var fresh = CompatibilityScorer.score(files: old.files, online: old.online, context: scoringContext(for: item), now: old.analyzedAt)
            fresh.analyzedAt = old.analyzedAt
            all[item.id] = fresh
        }
        state.compat = all
        persist()
    }

    /// "Automatic" picks D3DMetal for DirectX 12 games when it's ready, otherwise DXVK (MacadeKit's rule).
    private func resolvedProfile(_ profile: LaunchProfile, for item: LibraryItem) -> LaunchProfile {
        guard profile.backend == .auto else { return profile }
        var folder: URL?
        if let custom = item.customGame { folder = custom.installDirectory ?? custom.workingDirectory }
        else if item.isInstalled { folder = item.installPath }
        let probe = folder.map { GraphicsProbe.scan($0) }
        var resolved = profile
        resolved.backend = profile.backend.resolved(for: probe, d3dMetalAvailable: d3dMetalReady)
        return resolved
    }

    // MARK: Playing

    /// Custom games count as running until every process in their Windows environment has ended:
    /// a launcher often starts the game and hides or exits, and the game outlives it.
    func isRunning(_ item: LibraryItem) -> Bool { running[item.id] != nil }

    /// Engines of running custom games, for stopping their environment.
    private var customEngines: [String: Engine] = [:]
    private var customBottle: Bottle { Bottle(kind: .gog, paths: customPaths) }
    func isLaunching(_ item: LibraryItem) -> Bool { launching.contains(item.id) }

    func play(_ item: LibraryItem) async {
        guard !isRunning(item), !isLaunching(item) else { return }
        if isDemo {
            alert = AppAlert(titleKey: "alert.demoTitle", message: "")
            return
        }
        let profile = resolvedProfile(profile(for: item), for: item)
        guard let engine = engine(for: profile) else {
            alert = AppAlert(titleKey: "alert.noEngine", message: "")
            return
        }
        launching.insert(item.id)
        defer { launching.remove(item.id) }

        do {
            let id = item.id
            let onExit: @Sendable (Int32) -> Void = { _ in
                Task { @MainActor [weak self] in self?.didExit(id) }
            }
            let process: RunningProcess
            switch item.backing {
            case .custom(let game):
                guard game.executableExists else { throw UniveGameError.missingExecutable(game.executable.path) }
                let bottle = try await BottleManager(paths: customPaths).ensure(.gog, engine: engine)
                let runner = WineRunner(paths: customPaths)
                // Leftovers from an earlier run (a hidden game, a crashed client) hold single-instance
                // locks, so the next start silently does nothing. Clear them unless another game of ours runs.
                let otherCustomRunning = running.keys.contains { $0.hasPrefix("custom:") && $0 != id }
                if !otherCustomRunning, await runner.isBottleActive(engine: engine, bottle: bottle) {
                    await runner.killAll(engine: engine, bottle: bottle)
                }
                await applyRetina(profile.retina, runner: runner, engine: engine, bottle: bottle)
                // Programs the launcher starts inherit these, so the game itself gets them too.
                let folders = [game.workingDirectory, game.installDirectory].compactMap { $0 }
                process = try runner.run(
                    engine: engine, bottle: bottle, executable: game.executable.path, arguments: game.arguments,
                    workingDirectory: game.workingDirectory, profile: profile,
                    extraOverrides: NativeDLLPolicy.overrides(for: folders) + (game.dllOverrides ?? []), logID: id, onExit: nil)
                customEngines[id] = engine
                // Done when the environment goes quiet, not when the launcher process exits.
                let env = WineRunner.environment(bottle: bottle, profile: LaunchProfile())
                let wineserver = engine.wineserver
                Task.detached { [weak self] in
                    // Wine brings its server up a moment after the launch; `-w` before that returns at once.
                    for _ in 0..<40 {
                        if await runner.isBottleActive(engine: engine, bottle: bottle) { break }
                        try? await Task.sleep(for: .milliseconds(250))
                    }
                    // A server can stop and start again between programs (launcher → game), so check again.
                    repeat {
                        _ = try? await ProcessRunner.run(wineserver, ["-w"], environment: env)
                        try? await Task.sleep(for: .seconds(2))
                    } while await runner.isBottleActive(engine: engine, bottle: bottle)
                    await self?.didExit(id)
                }
            case .store(let game):
                try await BottleManager(paths: paths).prepareForPlay(game.store, engine: engine)
                await applyRetina(profile.retina, runner: WineRunner(paths: paths), engine: engine,
                                  bottle: Bottle(kind: game.store.bottleKind, paths: paths))
                switch game.store {
                case .steam: process = try SteamProvider(paths: paths).play(game, engine: engine, profile: profile, onExit: onExit)
                case .epic: process = try EpicProvider(paths: paths).play(game, engine: engine, profile: profile, onExit: onExit)
                case .gog: process = try GOGProvider(paths: paths).play(game, engine: engine, profile: profile, onExit: onExit)
                case .ubisoft, .ea: process = try LauncherStore(kind: game.store, paths: paths).play(game, engine: engine, profile: profile, onExit: onExit)
                }
            }
            state.lastPlayed[id] = Date()
            // Launcher stores hand the game to their own client, so the process we get isn't the game.
            if case .store(let game) = item.backing, game.store.usesLauncher {
                persist()
                return
            }
            running[id] = process
            playStarts[id] = Date()
            persist()
        } catch {
            alert = AppAlert(titleKey: "alert.launchFailed", message: error.localizedDescription)
        }
    }

    // MARK: Installing store games

    private(set) var installProgress: [String: Double] = [:]

    func install(_ item: LibraryItem) async {
        guard case .store(let game) = item.backing, installProgress[item.id] == nil else { return }
        guard !isDemo else { alert = AppAlert(titleKey: "alert.demoTitle", message: ""); return }
        let id = item.id
        do {
            switch game.store {
            case .steam:
                guard let engine = engine(for: LaunchProfile()) else { throw UniveGameError.noEngine }
                try SteamProvider(paths: paths).install(appID: game.storeID, engine: engine)
            case .ubisoft, .ea:
                openLauncher(game.store)
            case .epic, .gog:
                installProgress[id] = 0
                defer { installProgress[id] = nil }
                let report: @Sendable (Double) -> Void = { p in
                    Task { @MainActor [weak self] in self?.installProgress[id] = p }
                }
                if game.store == .epic { try await EpicProvider(paths: paths).install(game, onProgress: report) }
                else { try await GOGProvider(paths: paths).install(game, onProgress: report) }
                await refreshStores()
            }
        } catch {
            alert = AppAlert(titleKey: "alert.installFailed", message: error.localizedDescription)
        }
    }

    /// Wine reads Retina mode when its server starts, so it's written only while the environment is idle
    /// (a running Steam keeps its current mode until it restarts) and only when it changed.
    private func applyRetina(_ retina: Bool, runner: WineRunner, engine: Engine, bottle: Bottle) async {
        let key = bottle.url.path
        guard state.appliedMacDriver?[key]?["RetinaMode"] != retina, bottle.exists,
              !(await runner.isBottleActive(engine: engine, bottle: bottle)) else { return }
        await runner.applyMacDriver(["RetinaMode": retina], engine: engine, bottle: bottle)
        var applied = state.appliedMacDriver ?? [:]
        applied[key, default: [:]]["RetinaMode"] = retina
        state.appliedMacDriver = applied
        persist()
    }

    func stop(_ item: LibraryItem) {
        if item.customGame != nil, let engine = customEngines[item.id] {
            // Ends the launcher and everything it started (the game, helpers, anti-cheat).
            let bottle = customBottle
            Task { await WineRunner(paths: customPaths).killAll(engine: engine, bottle: bottle) }
        } else {
            running[item.id]?.terminate()
        }
    }

    private func didExit(_ id: String) {
        running[id] = nil
        customEngines[id] = nil
        if let start = playStarts.removeValue(forKey: id) {
            state.playTime[id, default: 0] += Date().timeIntervalSince(start)
            persist()
        }
    }

    func revealInFinder(_ item: LibraryItem) {
        guard let path = item.installPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([path])
    }

    func openLogs(_ item: LibraryItem) {
        let folder = (item.customGame != nil ? customPaths : paths).gameLogs(item.id)
        NSWorkspace.shared.open(FileManager.default.fileExists(atPath: folder.path) ? folder : paths.logs)
    }

    // MARK: Stores

    func connection(for kind: StoreKind) -> StoreConnection {
        if isDemo { return kind == .steam || kind == .gog ? .ready : .notSetUp }
        switch kind {
        case .steam:
            guard SteamProvider(paths: paths).isSteamInstalled else { return .notSetUp }
            return steamAccount == nil ? .needsSignIn : .ready
        case .epic:
            let epic = EpicProvider(paths: paths)
            return !epic.isLegendaryInstalled ? .notSetUp : (epic.isSignedIn ? .ready : .needsSignIn)
        case .gog:
            let gog = GOGProvider(paths: paths)
            return !gog.isHelperInstalled ? .notSetUp : (gog.isSignedIn ? .ready : .needsSignIn)
        case .ubisoft, .ea:
            return LauncherStore(kind: kind, paths: paths).isLauncherInstalled ? .ready : .notSetUp
        }
    }

    func isBusy(_ kind: StoreKind) -> Bool { busyStores.contains(kind) }

    private var steamDirectory: URL { SteamProvider(paths: paths).bottle.steamDirectory }

    /// The account signed in to UniveGame's Steam (nil before the first sign-in).
    var steamAccount: SteamAccountLibrary.Account? {
        if isDemo { return SteamAccountLibrary.Account(steamID64: "0", personaName: "Demo") }
        return SteamAccountLibrary.currentAccount(steamDirectory: steamDirectory)
    }

    /// Downloads the store's helper or launcher. Needs an engine for launcher stores.
    func setUp(_ kind: StoreKind) async {
        guard !isDemo else { alert = AppAlert(titleKey: "alert.demoTitle", message: ""); return }
        busyStores.insert(kind)
        defer { busyStores.remove(kind) }
        do {
            switch kind {
            case .epic: try await EpicProvider(paths: paths).installLegendary()
            case .gog: try await GOGProvider(paths: paths).installHelper()
            case .steam, .ubisoft, .ea:
                guard let engine = engine(for: LaunchProfile()) else { throw UniveGameError.noEngine }
                if kind == .steam { try await SteamProvider(paths: paths).installSteam(engine: engine) }
                else { try await LauncherStore(kind: kind, paths: paths).installLauncher(engine: engine) }
            }
            await refreshStores()
        } catch {
            alert = AppAlert(titleKey: "alert.storeFailed", message: error.localizedDescription)
        }
    }

    func openLauncher(_ kind: StoreKind) {
        guard let engine = engine(for: LaunchProfile()) else {
            alert = AppAlert(titleKey: "alert.noEngine", message: "")
            return
        }
        do {
            if kind == .steam {
                try SteamProvider(paths: paths).launchSteam(engine: engine) { _ in
                    Task { @MainActor [weak self] in await self?.refreshStores() }
                }
            }
            else { try LauncherStore(kind: kind, paths: paths).launchLauncher(engine: engine) }
        } catch {
            alert = AppAlert(titleKey: "alert.launchFailed", message: error.localizedDescription)
        }
    }

    func completeSignIn(_ kind: StoreKind, code: String) async {
        busyStores.insert(kind)
        defer { busyStores.remove(kind) }
        do {
            if kind == .epic { try await EpicProvider(paths: paths).signIn(authorizationCode: code) }
            else if kind == .gog { try await GOGProvider(paths: paths).signIn(code: code) }
            await refreshStores()
        } catch {
            alert = AppAlert(titleKey: "alert.signInFailed", message: error.localizedDescription)
        }
    }

    func signOut(_ kind: StoreKind) async {
        if kind == .epic { try? await EpicProvider(paths: paths).signOut() }
        if kind == .gog { GOGProvider(paths: paths).signOut() }
        state.storeGames.removeAll { $0.store == kind }
        persist()
    }

    /// Installed Steam games (with their folders and sizes) plus everything else the account owns,
    /// and Steam's own play time for each.
    private func steamLibrary() async -> [Game] {
        let directory = steamDirectory
        let installed = (try? await SteamProvider(paths: paths).refresh()) ?? []
        let (owned, activity) = await Task.detached { () -> ([Game], [String: SteamAccountLibrary.Activity]) in
            let owned = SteamAccountLibrary.ownedGames(steamDirectory: directory)
            let activity = SteamAccountLibrary.currentAccount(steamDirectory: directory)
                .map { SteamAccountLibrary.activity(steamDirectory: directory, account: $0) } ?? [:]
            return (owned, activity)
        }.value

        let ownedByID = Dictionary(owned.map { ($0.storeID, $0) }, uniquingKeysWith: { a, _ in a })
        var result = installed.map { game -> Game in
            var game = game
            if let local = ownedByID[game.storeID] { // Steam's cached artwork beats a CDN guess
                game.coverURL = local.coverURL ?? game.coverURL
                game.heroURL = local.heroURL ?? game.heroURL
            }
            return game
        }
        let installedIDs = Set(installed.map(\.storeID))
        result += owned.filter { !installedIDs.contains($0.storeID) }

        for (appID, a) in activity {
            let id = "steam:\(appID)"
            if let last = a.lastPlayed, last > (state.lastPlayed[id] ?? .distantPast) { state.lastPlayed[id] = last }
            if a.playTime > (state.playTime[id] ?? 0) { state.playTime[id] = a.playTime }
        }
        return result
    }

    private(set) var lastRefresh: Date?
    /// Games that appeared in the last refresh, per store ("3 new found").
    private(set) var newGamesFound: [StoreKind: Int] = [:]

    /// Refresh on returning to the app, but not more than every two minutes: Epic and GOG ask their servers.
    func refreshIfStale() async {
        if let last = lastRefresh, Date().timeIntervalSince(last) < 120 { return }
        await refreshStores()
    }

    /// Re-reads every connected store's library.
    func refreshStores() async {
        guard !isDemo, !refreshing else { return }
        lastRefresh = Date()
        refreshing = true
        defer { refreshing = false }
        var games = state.storeGames
        let before = Set(games.map(\.id))
        for kind in StoreKind.allCases where connection(for: kind) == .ready {
            if kind == .steam {
                games = LibraryStore.merged(cached: games, replacing: .steam, with: await steamLibrary())
                continue
            }
            let provider: any StoreProvider = switch kind {
            case .steam: SteamProvider(paths: paths)
            case .epic: EpicProvider(paths: paths)
            case .gog: GOGProvider(paths: paths)
            case .ubisoft, .ea: LauncherStore(kind: kind, paths: paths)
            }
            if var fresh = try? await provider.refresh() {
                if kind == .epic {
                    let metadata = paths.legendaryConfig.appendingPathComponent("metadata", isDirectory: true)
                    fresh = fresh.filter { EpicLibraryFilter.isGame(appName: $0.storeID, title: $0.title, metadataFolder: metadata) }
                }
                games = LibraryStore.merged(cached: games, replacing: kind, with: fresh)
            }
        }
        var found: [StoreKind: Int] = [:]
        for game in games where !before.contains(game.id) { found[game.store, default: 0] += 1 }
        if !before.isEmpty { newGamesFound = found }
        state.storeGames = games
        persist()
    }

    // MARK: Persistence

    private func persist() {
        guard !isDemo else { return }
        store.save(state)
    }
}

/// Failure reasons shown by the installer sheet; the sheet localizes them.
enum L10nKey {
    static let noEngine = "installer.error.noEngine"
    static let nothingFound = "installer.error.nothingFound"
    static let installerFailed = "installer.error.failed"
    static let installerCrashed = "installer.error.crashed"
}

enum UniveGameError: LocalizedError {
    case missingExecutable(String)
    case noEngine

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let path): path
        case .noEngine: "No Wine engine is installed."
        }
    }
}
