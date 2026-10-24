import AppKit
import CryptoKit
import Foundation
import Security
import UniveEngineKit

/// A newer UniveGame published on GitHub.
struct AppUpdate: Equatable, Sendable {
    let version: String
    let notes: String
    let page: URL
    let download: URL
    let size: Int64
    /// The SHA-256 GitHub computed when the file was uploaded (the asset's `digest`), when it lists one.
    let sha256: String?
}

enum AppUpdatePhase: Equatable, Sendable {
    case downloading(Double), verifying, installing
}

enum AppUpdateError: Error, Equatable, LocalizedError {
    /// The release list couldn't be read (offline, rate limit, unexpected answer).
    case server(String)
    /// The download doesn't match the release (size, SHA-256, version or bundle).
    case damaged(String)
    /// The app inside isn't signed with UniveGame's Developer ID or isn't notarized by Apple.
    case untrusted(String)
    /// This copy can't replace itself (read-only folder, or macOS runs it from a translocated copy).
    case notWritable
    case failed(String)

    /// Localization key of the explanation (`update.error.<key>`).
    var key: String {
        switch self {
        case .server: "server"
        case .damaged: "damaged"
        case .untrusted: "untrusted"
        case .notWritable: "notWritable"
        case .failed: "failed"
        }
    }

    var detail: String {
        switch self {
        case .server(let m), .damaged(let m), .untrusted(let m), .failed(let m): m
        case .notWritable: ""
        }
    }

    var errorDescription: String? { detail.isEmpty ? key : "\(key): \(detail)" }
}

/// Updates UniveGame from its GitHub releases.
///
/// GitHub is only where the file comes from, not what makes it trusted. Before anything is replaced the download
/// must match the release (size and the SHA-256 GitHub lists for the asset), and the app inside must be this app
/// (same bundle identifier, the release's version, newer than the running one), signed with UniveGame's Developer
/// ID certificate (team T23H2VU6YK, issued by Apple) and notarized by Apple. Someone who could publish a release
/// still couldn't get an app installed without the Developer ID private key, and an older release can't be
/// pushed back (no downgrades). Only HTTPS, and only GitHub's own hosts, are followed.
struct AppUpdater: Sendable {
    static let latestRelease = URL(string: "https://api.github.com/repos/MuratDugan/UniveGame/releases/latest")!
    static let downloadPrefix = "https://github.com/MuratDugan/UniveGame/releases/download/"
    /// Where GitHub sends release downloads.
    static let downloadHosts: Set<String> = ["github.com", "objects.githubusercontent.com", "release-assets.githubusercontent.com"]
    static let bundleID = "dev.univegame.launcher"
    static let teamID = "T23H2VU6YK"
    /// This app, signed with a Developer ID Application certificate Apple issued to UniveGame's team.
    static let requirement = #"identifier "dev.univegame.launcher" and anchor apple generic"#
        + #" and certificate 1[field.1.2.840.113635.100.6.2.6] and certificate leaf[field.1.2.840.113635.100.6.1.13]"#
        + #" and certificate leaf[subject.OU] = "T23H2VU6YK""#
    /// Larger than any UniveGame disk image will be; a bigger answer isn't ours.
    static let maximumSize: Int64 = 200 << 20

    // MARK: Checking

    /// The latest release, when it's newer than `current`.
    func check(current: String) async throws -> AppUpdate? {
        var request = URLRequest(url: Self.latestRelease, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("UniveGame/\(current)", forHTTPHeaderField: "User-Agent")
        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw AppUpdateError.server(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppUpdateError.server("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        return try Self.parse(data, current: current)
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let size: Int64
            let browser_download_url: URL
            let digest: String?
        }
        let tag_name: String
        let body: String?
        let html_url: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    /// Reads GitHub's answer. Nil when the release isn't newer than `current`. Only a final release whose tag is
    /// `v<version>` with the disk image `UniveGame-<version>.dmg` from this repository's release downloads counts.
    static func parse(_ data: Data, current: String) throws -> AppUpdate? {
        guard let release = try? JSONDecoder().decode(Release.self, from: data) else { throw AppUpdateError.server("unreadable release") }
        guard !release.draft, !release.prerelease else { return nil }
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        guard isVersion(version) else { throw AppUpdateError.server("unexpected tag \(release.tag_name)") }
        guard isNewer(version, than: current) else { return nil }
        let name = "UniveGame-\(version).dmg"
        guard let asset = release.assets.first(where: { $0.name == name }),
              asset.browser_download_url.absoluteString == "\(downloadPrefix)\(release.tag_name)/\(name)",
              asset.size > 0, asset.size <= maximumSize else { throw AppUpdateError.server("no disk image in release \(version)") }
        return AppUpdate(version: version, notes: release.body ?? "", page: release.html_url,
                         download: asset.browser_download_url, size: asset.size, sha256: sha256(fromDigest: asset.digest))
    }

    static func isVersion(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        return (2...4).contains(parts.count) && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }
    }

    /// Numeric, part by part: 1.0.10 is newer than 1.0.9.
    static func isNewer(_ a: String, than b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }

    /// `sha256:<64 hex>` → the hex digest.
    static func sha256(fromDigest digest: String?) -> String? {
        guard let digest, digest.hasPrefix("sha256:") else { return nil }
        let hex = digest.dropFirst(7).lowercased()
        return hex.count == 64 && hex.allSatisfy(\.isHexDigit) ? String(hex) : nil
    }

    // MARK: Downloading and verifying

    /// Downloads `update` into `work` and checks it. Returns the disk image and the verified app inside it (mounted
    /// read-only at `work/mnt`, so detach it when done).
    func fetch(_ update: AppUpdate, current: String, into work: URL,
               progress: @escaping @Sendable (AppUpdatePhase) -> Void) async throws -> (dmg: URL, app: URL) {
        guard update.download.absoluteString.hasPrefix(Self.downloadPrefix) else { throw AppUpdateError.untrusted("download address") }
        let dmg = work.appendingPathComponent("UniveGame-\(update.version).dmg")
        progress(.downloading(0))
        try await UpdateDownload.run(update.download, to: dmg, maximum: Self.maximumSize) { progress(.downloading($0)) }
        progress(.verifying)
        let app = try await Self.verify(dmg: dmg, update: update, current: current, mountAt: work.appendingPathComponent("mnt"))
        return (dmg, app)
    }

    static func verify(dmg: URL, update: AppUpdate, current: String, mountAt mount: URL) async throws -> URL {
        let fm = FileManager.default
        let size = (try? fm.attributesOfItem(atPath: dmg.path)[.size] as? Int64) ?? -1
        guard size == update.size else { throw AppUpdateError.damaged("size \(size), expected \(update.size)") }
        if let expected = update.sha256 {
            guard try FileDigest.sha256(of: dmg) == expected else { throw AppUpdateError.damaged("SHA-256 doesn't match the release") }
        }
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)
        let attach = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/hdiutil"),
                                                 ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path, dmg.path])
        guard attach.succeeded else { throw AppUpdateError.damaged("the disk image doesn't open") }
        let app = mount.appendingPathComponent("UniveGame.app", isDirectory: true)
        guard let values = try? app.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true,
              let info = Bundle(url: app)?.infoDictionary else { throw AppUpdateError.damaged("no UniveGame.app inside") }
        guard info["CFBundleIdentifier"] as? String == bundleID else { throw AppUpdateError.damaged("another app's identifier") }
        guard let version = info["CFBundleShortVersionString"] as? String, version == update.version,
              isNewer(version, than: current) else { throw AppUpdateError.damaged("version doesn't match the release") }
        try checkSignature(of: app)
        try await checkNotarized(app)
        return app
    }

    /// Valid on disk, every architecture and nested binary, and meeting `requirement`.
    static func checkSignature(of app: URL) throws {
        var code: SecStaticCode?
        var req: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(requirement as CFString, [], &req) == errSecSuccess, let req else {
            throw AppUpdateError.untrusted("unreadable signature")
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        var error: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(code, flags, req, &error)
        guard status == errSecSuccess else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "OSStatus \(status)"
            throw AppUpdateError.untrusted(reason)
        }
    }

    /// Gatekeeper's verdict: accepted, as notarized Developer ID software.
    static func checkNotarized(_ app: URL) async throws {
        let r = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/sbin/spctl"), ["--assess", "--type", "execute", "-vv", app.path])
        guard r.succeeded, r.output.contains("source=Notarized Developer ID"), r.output.contains("(\(teamID))") else {
            throw AppUpdateError.untrusted("not notarized by Apple")
        }
    }

    // MARK: Installing

    /// Can this copy replace itself? Not when macOS runs it translocated (straight from a download, never moved)
    /// or its folder isn't writable; the update then opens the verified disk image instead.
    static func canReplace(_ bundle: URL) -> Bool {
        let parent = bundle.deletingLastPathComponent()
        return !bundle.path.contains("/AppTranslocation/") && bundle.pathExtension == "app"
            && FileManager.default.isWritableFile(atPath: parent.path)
            && FileManager.default.isWritableFile(atPath: bundle.path)
    }

    /// Puts `app` where `bundle` is: a copy next to it (same volume) is checked again, then swapped in with two
    /// renames, putting the old copy back if the second fails. The running app keeps its open files until it quits.
    static func replace(_ bundle: URL, with app: URL) async throws {
        guard canReplace(bundle) else { throw AppUpdateError.notWritable }
        let fm = FileManager.default
        let parent = bundle.deletingLastPathComponent()
        let staged = parent.appendingPathComponent(".UniveGame-update-\(UUID().uuidString).app")
        let old = parent.appendingPathComponent(".UniveGame-old-\(UUID().uuidString).app")
        defer { try? fm.removeItem(at: staged) }
        let copy = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), [app.path, staged.path])
        guard copy.succeeded else { throw AppUpdateError.failed("copy failed") }
        try checkSignature(of: staged)
        do { try fm.moveItem(at: bundle, to: old) } catch { throw AppUpdateError.failed(error.localizedDescription) }
        do { try fm.moveItem(at: staged, to: bundle) } catch {
            try? fm.moveItem(at: old, to: bundle)
            throw AppUpdateError.failed(error.localizedDescription)
        }
        try? fm.removeItem(at: old)
    }

    /// Opens `bundle` once this process has quit, then quits.
    @MainActor static func relaunch(_ bundle: URL) {
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", #"while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open "$2""#,
                            "sh", "\(ProcessInfo.processInfo.processIdentifier)", bundle.path]
        try? helper.run()
        NSApp.terminate(nil)
    }
}

/// SHA-256 of a file, read in chunks.
enum FileDigest {
    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

enum UpdateDownloadHosts {
    /// HTTPS to one of GitHub's release hosts, nothing else.
    static func allowed(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return AppUpdater.downloadHosts.contains(host)
    }
}

/// One HTTPS download with progress that only follows redirects to `AppUpdater.downloadHosts`.
private final class UpdateDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let destination: URL
    let maximum: Int64
    let onProgress: @Sendable (Double) -> Void
    var continuation: CheckedContinuation<Void, Error>?
    private var failure: Error?

    init(destination: URL, maximum: Int64, onProgress: @escaping @Sendable (Double) -> Void) {
        self.destination = destination
        self.maximum = maximum
        self.onProgress = onProgress
    }

    static func run(_ url: URL, to destination: URL, maximum: Int64, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        let delegate = UpdateDownload(destination: destination, maximum: maximum, onProgress: onProgress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.downloadTask(with: url)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                delegate.continuation = c
                task.resume()
            }
        } onCancel: { task.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if UpdateDownloadHosts.allowed(request.url) { completionHandler(request) } else {
            failure = AppUpdateError.untrusted("redirect to \(request.url?.host ?? "?")")
            completionHandler(nil)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
                    totalBytesWritten written: Int64, totalBytesExpectedToWrite total: Int64) {
        if written > maximum || total > maximum {
            failure = AppUpdateError.damaged("larger than expected")
            downloadTask.cancel()
            return
        }
        if total > 0 { onProgress(Double(written) / Double(total)) }
    }

    // The temporary file is deleted when this returns, so it's moved into place here.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard failure == nil else { return }
        guard let http = downloadTask.response as? HTTPURLResponse, http.statusCode == 200, UpdateDownloadHosts.allowed(http.url) else {
            failure = AppUpdateError.server("HTTP \((downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0)")
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch { failure = AppUpdateError.failed(error.localizedDescription) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let result: Error?
        if let failure { result = failure }
        else if let error = error as? URLError, error.code == .cancelled { result = CancellationError() }
        else { result = error.map { AppUpdateError.server($0.localizedDescription) } }
        if let result { continuation?.resume(throwing: result) } else { continuation?.resume() }
        continuation = nil
    }
}
