import Foundation
import UniveEngineKit
import Observation

/// One run of a Windows installer (setup.exe) inside the custom-games environment, from start to
/// picking the game's program.
@MainActor
@Observable
final class InstallerSession: Identifiable {
    enum Phase: Equatable {
        case ready              // explain and confirm
        case preparing          // creating the Windows environment
        case installingRuntime  // Wine Mono (.NET)
        case running            // the installer window is open
        case finishing          // installer closed, waiting for its helper processes
        case extracting         // the installer didn't work; unpacking its files directly
        case choosing           // pick the game's .exe
        case failed(String)
    }

    /// One line of the progress log: a localization key and an optional argument.
    struct LogLine: Hashable {
        var key: String
        var argument: String?
    }

    let id = UUID()
    let setup: URL
    var phase: Phase = .ready {
        didSet { if phase != oldValue { record(phase) } }
    }
    /// What happened so far, shown on the progress step (lines are added as phases change).
    private(set) var log: [LogLine] = []
    private(set) var startedAt: Date?
    var installRuntime = true
    var result = InstallScanResult(candidates: [], installDirectory: nil, uninstaller: nil)
    var selected: URL?
    var title = ""
    /// What the setup file is (Inno Setup, NSIS, MSI…), for unpacking it when running it doesn't work.
    var kind: InstallerKind = .unknown
    /// Launch options the chosen program needs (e.g. `-game cstrike` for a GoldSrc game).
    var arguments: [String] = []

    /// Lets the user move on while something the installer started (say, the game) keeps running.
    var waitTask: Task<Void, Never>?

    init(setup: URL) { self.setup = setup }

    private func record(_ phase: Phase) {
        func settlePreparing() {
            if let i = log.firstIndex(of: LogLine(key: "installer.log.preparing")) { log[i] = LogLine(key: "installer.log.prepared") }
        }
        switch phase {
        case .ready, .choosing, .failed:
            break
        case .preparing:
            startedAt = Date()
            log = [LogLine(key: "installer.log.preparing")]
        case .installingRuntime:
            settlePreparing()
            log.append(LogLine(key: "installer.log.runtime"))
        case .running:
            settlePreparing()
            log.append(LogLine(key: "installer.log.started", argument: setup.lastPathComponent))
            log.append(LogLine(key: "installer.log.windowOpen"))
        case .finishing:
            log.append(LogLine(key: "installer.log.finishing"))
        case .extracting:
            log.append(LogLine(key: "installer.log.extracting", argument: kind.displayName))
        }
    }

    var isBusy: Bool {
        switch phase {
        case .preparing, .installingRuntime, .running, .finishing, .extracting: true
        default: false
        }
    }
}
