import CryptoKit
import Foundation
import MacadeKit

/// What kind of package a setup file is, read from its bytes (not its name).
enum InstallerKind: String, Equatable {
    case inno, nsis, msi, installShield, wixBurn, sevenZip, zip, rar, cab, unknown

    /// Display name for the progress log.
    var displayName: String {
        switch self {
        case .inno: "Inno Setup"
        case .nsis: "NSIS"
        case .msi: "Windows Installer (.msi)"
        case .installShield: "InstallShield"
        case .wixBurn: "WiX"
        case .sevenZip: "7-Zip"
        case .zip: "ZIP"
        case .rar: "RAR"
        case .cab: "CAB"
        case .unknown: "?"
        }
    }

    /// Recognizes the installer from markers its builder leaves in the file.
    static func detect(_ url: URL) -> InstallerKind {
        switch url.pathExtension.lowercased() {
        case "msi": return .msi
        case "zip": return .zip
        case "7z": return .sevenZip
        case "rar": return .rar
        case "cab": return .cab
        default: break
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? handle.close() }
        let markers: [(InstallerKind, [UInt8])] = [
            (.inno, Array("Inno Setup Setup Data".utf8)),
            (.nsis, Array("NullsoftInst".utf8)),
            (.installShield, Array("InstallShield".utf8)),
            (.wixBurn, Array(".wixburn".utf8)),
            (.sevenZip, [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]),
            (.rar, [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]),
            (.cab, Array("MSCF".utf8) + [0, 0, 0, 0]),
            (.zip, [0x50, 0x4B, 0x03, 0x04]),
        ]
        var found = Set<InstallerKind>()
        var tail = Data()
        var read = 0
        // Installer markers sit in the stub or at the start of the payload: the first 64 MB is plenty.
        while read < 64 << 20, let chunk = try? handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            let window = tail + chunk
            for (kind, bytes) in markers where !found.contains(kind) && window.range(of: Data(bytes)) != nil {
                found.insert(kind)
            }
            tail = window.suffix(32)
            read += chunk.count
        }
        // The builder's own marker wins over archive signatures that may be embedded in it.
        for kind in [InstallerKind.inno, .nsis, .wixBurn, .installShield, .sevenZip, .rar, .cab, .zip] where found.contains(kind) {
            return kind
        }
        return .unknown
    }
}

/// Command-line unpackers UniveGame downloads on first use, pinned by SHA-256.
struct ExtractionTool: Sendable {
    let id: String
    let url: URL
    let sha256: String
    /// Path of the program inside the unpacked download.
    let binary: String

    /// 7-Zip for macOS (Igor Pavlov, LGPL with the unRAR restriction): NSIS, 7z, ZIP, RAR, CAB and many SFX.
    static let sevenZip = ExtractionTool(
        id: "7zip-26.05", url: URL(string: "https://github.com/ip7z/7zip/releases/download/26.05/7z2605-mac.tar.xz")!,
        sha256: "12ef6830317743cfd3f0ab1724bde43fcc270d8b6d8564f8c12c2a2b7f993570", binary: "7zz")
    /// innoextract (Daniel Scharrer, zlib licence), the Windows build: runs in the environment's Wine.
    static let innoextract = ExtractionTool(
        id: "innoextract-1.9", url: URL(string: "https://constexpr.org/innoextract/files/innoextract-1.9-windows.zip")!,
        sha256: "6989342c9b026a00a72a38f23b62a8e6a22cc5de69805cf47d68ac2fec993065", binary: "innoextract.exe")
}

enum InstallerExtractorError: LocalizedError {
    case download(String), unsupported, failed(String)
    var errorDescription: String? {
        switch self {
        case .download(let m): "Couldn't get the unpacker: \(m)"
        case .unsupported: "This installer can't be unpacked."
        case .failed(let m): m
        }
    }
}

/// Unpacks a setup file straight into a folder when running it doesn't work (it crashes under Wine,
/// or installs nothing UniveGame can see). Registry entries and post-install steps are skipped, which most
/// games don't need.
struct InstallerExtractor {
    let paths: Paths
    let engine: Engine
    let bottle: Bottle

    private var fm: FileManager { .default }

    /// Where a tool lives once downloaded: `Custom/Tools/<id>/`.
    private func folder(for tool: ExtractionTool) -> URL {
        paths.tools.appendingPathComponent(tool.id, isDirectory: true)
    }

    func ensure(_ tool: ExtractionTool) async throws -> URL {
        let dir = folder(for: tool)
        let binary = dir.appendingPathComponent(tool.binary)
        if fm.fileExists(atPath: binary.path) { return binary }

        let (tmp, response) = try await URLSession.shared.download(from: tool.url)
        defer { try? fm.removeItem(at: tmp) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw InstallerExtractorError.download(tool.url.absoluteString) }
        let digest = SHA256.hash(data: try Data(contentsOf: tmp, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
        guard digest == tool.sha256 else { throw InstallerExtractorError.download("checksum mismatch") }

        try? fm.removeItem(at: dir)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let unpack = tool.url.pathExtension == "zip"
            ? try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), ["-x", "-k", tmp.path, dir.path])
            : try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"), ["-xJf", tmp.path, "-C", dir.path])
        guard unpack.succeeded, fm.fileExists(atPath: binary.path) else { throw InstallerExtractorError.download("unpack failed") }
        if tool.binary.hasSuffix(".exe") == false {
            // A native tool needs an (ad-hoc) signature to run on Apple Silicon.
            try await ProcessRunner.run(URL(fileURLWithPath: "/bin/chmod"), ["+x", binary.path])
            try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/codesign"), ["--force", "--sign", "-", binary.path])
        }
        return binary
    }

    static func windowsPath(_ url: URL) -> String { "Z:" + url.path.replacingOccurrences(of: "/", with: "\\") }

    /// Unpacks `setup` into `destination`. Returns the name the installer gives the program, when it has one.
    @discardableResult
    func extract(_ setup: URL, kind: InstallerKind, into destination: URL) async throws -> String? {
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        switch kind {
        case .inno:
            return try await extractInno(setup, into: destination)
        case .msi:
            // An administrative install copies the files without running the package's custom actions.
            let env = WineRunner.environment(bottle: bottle, profile: LaunchProfile())
            let result = try await ProcessRunner.run(engine.wine, ["msiexec", "/a", Self.windowsPath(setup), "/qn",
                                                                   "TARGETDIR=\(Self.windowsPath(destination))"], environment: env)
            guard result.succeeded else { throw InstallerExtractorError.failed("msiexec /a exited with \(result.status)") }
            return nil
        case .nsis, .sevenZip, .zip, .rar, .cab, .installShield, .wixBurn, .unknown:
            let sevenZip = try await ensure(.sevenZip)
            let result = try await ProcessRunner.run(sevenZip, ["x", "-y", "-o\(destination.path)", setup.path])
            guard result.succeeded else { throw InstallerExtractorError.failed("7-Zip couldn't open this installer") }
            // NSIS keeps its own helpers in $PLUGINSDIR and temporary files in $TEMP; the game doesn't need them.
            for junk in ["$PLUGINSDIR", "$TEMP", "[NSIS].nsi"] {
                try? fm.removeItem(at: destination.appendingPathComponent(junk))
            }
            return nil
        }
    }

    /// The program's name as the installer states it (Inno Setup only), for naming its folder.
    func productName(of setup: URL, kind: InstallerKind) async -> String? {
        guard kind == .inno, let innoextract = try? await ensure(.innoextract) else { return nil }
        var env = WineRunner.environment(bottle: bottle, profile: LaunchProfile())
        env["WINEDEBUG"] = "-all"
        guard let output = try? await ProcessRunner.run(engine.wine, [innoextract.path, "--info", Self.windowsPath(setup)],
                                                        environment: env).output,
              let start = output.range(of: "Inspecting \""),
              let end = output[start.upperBound...].firstIndex(of: "\"") else { return nil }
        let name = String(output[start.upperBound..<end]).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private func extractInno(_ setup: URL, into destination: URL) async throws -> String? {
        let innoextract = try await ensure(.innoextract)
        var env = WineRunner.environment(bottle: bottle, profile: LaunchProfile())
        env["WINEDEBUG"] = "-all"
        let staging = destination.appendingPathComponent(".unpack", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        let result = try await ProcessRunner.run(engine.wine, [innoextract.path, "--extract", "--silent", "--exclude-temp",
                                                               "--output-dir", Self.windowsPath(staging), Self.windowsPath(setup)],
                                                 environment: env)
        let app = staging.appendingPathComponent("app", isDirectory: true)
        guard result.succeeded, fm.fileExists(atPath: app.path) else { throw InstallerExtractorError.failed("innoextract failed") }
        // `app` is the setup's {app}: the game's own folder. Other targets ({sys}, {commonappdata}…) are left out.
        for item in try fm.contentsOfDirectory(at: app, includingPropertiesForKeys: nil) {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            try? fm.removeItem(at: target)
            try fm.moveItem(at: item, to: target)
        }
        return nil
    }
}
