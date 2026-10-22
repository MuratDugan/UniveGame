import AppKit
import UniveEngineKit
import SwiftUI
import UniformTypeIdentifiers

/// v2 installer flow, full window: confirm → the installer's own window → pick the game's program.
struct InstallerFlowView: View {
    @Bindable var session: InstallerSession
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @State private var cover: URL?
    @State private var suggestion: CoverSuggestion?
    @State private var confirmClose = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                stepPanel
                ScrollView {
                    content
                        .frame(width: 620, alignment: .leading)
                        .padding(.top, 64)
                        .padding(.horizontal, Theme.Layout.pageInsetX)
                        .padding(.bottom, Theme.Spacing.xl)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
            }
        }
        .background(Theme.Palette.background)
        .confirmationDialog(L("installer.stop"), isPresented: $confirmClose, titleVisibility: .visible) {
            Button(L("installer.stop"), role: .destructive) { model.cancelInstaller() }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("installer.hint.running"))
        }
        .task(id: session.title) {
            guard session.phase == .choosing, cover == nil else { return }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            suggestion = await CoverFinder.find(title: session.title, languageCode: L.resolvedCode)
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 200, height: 1)
            Text(L("installer.title")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity)
            HStack {
                Spacer()
                Button(L("installer.close")) { close() }
                    .buttonStyle(SecondaryButtonStyle(height: 30, horizontalPadding: 12))
                    .keyboardShortcut(.cancelAction)
            }
            .frame(width: 200)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .frame(height: Theme.Layout.toolbarHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.border).frame(height: 1) }
    }

    private func close() {
        if session.isBusy { confirmClose = true } else { model.cancelInstaller() }
    }

    private var step: Int {
        switch session.phase {
        case .ready: 0
        case .preparing, .installingRuntime, .running, .finishing, .extracting, .failed: 1
        case .choosing: 2
        }
    }

    private var isFailed: Bool {
        if case .failed = session.phase { return true }
        return false
    }

    private var stepPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            StepRail(steps: [
                .init(title: L("installer.step.file"), detail: L("installer.step.file.detail")),
                .init(title: L("installer.step.install"), detail: L("installer.step.run.detail")),
                .init(title: L("installer.step.pick"), detail: L("installer.step.pick.detail")),
            ], current: step, failed: isFailed)
            Spacer(minLength: 0)
            fileCard
        }
        .padding(.vertical, 40)
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(width: 320)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.Palette.border).frame(width: 1) }
    }

    private var fileCard: some View {
        let size = (try? session.setup.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        }
        let folder = FileManager.default.displayName(atPath: session.setup.deletingLastPathComponent().path)
        return HStack(spacing: 12) {
            Image(systemName: "shippingbox").font(.system(size: 16)).foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 36, height: 36)
                .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.setup.lastPathComponent).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Text([size, folder].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.border))
        .help(session.setup.path)
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        Group {
            switch session.phase {
            case .ready: intro
            case .preparing, .installingRuntime, .running, .finishing, .extracting: progress
            case .choosing: chooser
            case .failed(let reason): failure(reason)
            }
        }
        .id(step * 10 + (isFailed ? 1 : 0))
    }

    private func heading(_ title: String, _ body: Text) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.Font.display).foregroundStyle(Theme.Palette.textPrimary).accessibilityAddTraits(.isHeader)
            body.font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .enterOnAppear()
    }

    // 1. Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            heading(L("installer.ready.title"), Text(L("installer.ready.body")))
            VStack(spacing: 0) {
                infoRow(L("installer.info.location")) {
                    Text(verbatim: "C:\\").font(Theme.Font.mono).foregroundStyle(Theme.Palette.textPrimary)
                        .help(L("installer.driveTip"))
                    Spacer(minLength: 8)
                    Button(L("installer.info.show")) { model.revealDriveC() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Palette.accent)
                }
                divider
                infoRow(L("installer.info.engine")) {
                    Text(engineText).font(.system(size: 13)).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                }
                divider
                infoRow(L("installer.info.space")) {
                    Text(freeSpace.map { L("installer.info.spaceValue", $0) } ?? "—")
                        .font(.system(size: 13)).foregroundStyle(Theme.Palette.textPrimary).monospacedDigit()
                }
                divider
                infoRow(L("installer.info.runtime")) {
                    Text(L("installer.runtime.short")).font(.system(size: 13)).foregroundStyle(Theme.Palette.textPrimary)
                        .help(L("installer.runtime.help"))
                    Spacer(minLength: 8)
                    Toggle("", isOn: $session.installRuntime)
                        .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                        .tint(Theme.Palette.accent)
                        .accessibilityLabel(L("installer.runtime"))
                }
            }
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
            .enterOnAppear(delay: 0.08)
            HStack(spacing: 8) {
                Button(L("installer.browse")) { model.chooseInstaller(message: L("menu.runInstaller")) }
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button(L("installer.start")) { Task { await model.runInstaller(session) } }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .enterOnAppear(delay: 0.16)
        }
    }

    private var divider: some View { Rectangle().fill(Theme.Palette.border).frame(height: 1) }

    private func infoRow<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.Palette.textSecondary).frame(width: 130, alignment: .leading)
            HStack(spacing: 0) { value() }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private var engineText: String {
        guard let engine = model.engines.first else { return L("engine.missing") }
        let wine = engine.info.wineDescription
        return "\(L("settings.engineVersion", engine.version)) · \(wine.lowercased().hasPrefix("wine") ? wine : "Wine " + wine)"
    }

    private var freeSpace: String? {
        let values = try? AppPaths.home.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    }

    // 2. Progress

    private var progress: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            heading(L("installer.running.title"), Text(L("installer.running.body")))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.Palette.accent).frame(width: 8, height: 8).pulsing()
                        Text(L("installer.running.state")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                    }
                    Spacer()
                    if let start = session.startedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(Duration.seconds(context.date.timeIntervalSince(start))
                                .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))
                                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).monospacedDigit()
                        }
                    }
                }
                IndeterminateBar(height: 6)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(session.log.enumerated()), id: \.element) { i, line in
                        let last = i == session.log.count - 1
                        Group {
                            if last {
                                logText(line).foregroundStyle(Theme.Palette.textPrimary).pulsing()
                            } else {
                                logText(line).foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    }
                }
                .font(Theme.Font.mono)
                .padding(.top, 8)
                .animation(Theme.Motion.enter, value: session.log)
            }
            .padding(20)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
            .enterOnAppear(delay: 0.08)
            HStack(spacing: 8) {
                Button(L("installer.stop")) { model.cancelInstaller() }
                    .buttonStyle(SecondaryButtonStyle(foreground: Theme.Palette.destructive, weight: .semibold))
                Spacer()
                if session.phase == .finishing {
                    Button(L("installer.skipWait")) { session.waitTask?.cancel() }
                        .buttonStyle(SecondaryButtonStyle())
                        .help(L("installer.hint.finishing"))
                }
                Button(L("installer.showWindow")) { Self.showInstallerWindow() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(session.phase != .running)
            }
            .enterOnAppear(delay: 0.16)
        }
    }

    private func logText(_ line: InstallerSession.LogLine) -> Text {
        Text(line.argument.map { L(line.key, $0) } ?? L(line.key))
    }

    /// Wine draws the installer in its own app; bring it forward.
    static func showInstallerWindow() {
        for app in NSWorkspace.shared.runningApplications {
            let path = app.executableURL?.path.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            if path.contains("wine") || name.hasSuffix(".exe") || name.contains("wine") {
                app.activate()
            }
        }
    }

    // 3. Choose the program

    private var chooser: some View {
        let folder = session.result.installDirectory.map { InstallScanner.windowsPath(of: $0, driveC: model.customDriveC) } ?? "C:\\"
        return VStack(alignment: .leading, spacing: 20) {
            heading(L("installer.done.title"), doneText(folder))
            VStack(spacing: 8) {
                ForEach(Array(session.result.candidates.prefix(12).enumerated()), id: \.element.id) { i, c in
                    ProgramChoiceRow(name: c.name, path: c.windowsPath,
                                     size: ByteCountFormatter.string(fromByteCount: c.size, countStyle: .file),
                                     recommended: i == 0, isSelected: session.selected == c.url) { session.selected = c.url }
                        .enter(index: i, base: 0.08)
                }
            }
            .accessibilityElement(children: .contain)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("import.name")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                    InputField(text: $session.title, placeholder: L("import.name"))
                }
                Button(cover == nil ? L("import.cover.add") : L("import.change"), action: chooseCover)
                    .buttonStyle(SecondaryButtonStyle(height: 32, horizontalPadding: 12))
                    .help(cover == nil ? (suggestion.map { L("cover.found", $0.name) } ?? "") : "")
            }
            .enterOnAppear(delay: 0.2)
            HStack(spacing: 8) {
                Button(L("installer.browse"), action: browse).buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button(L("import.add")) { model.finishInstaller(session, cover: cover, suggestion: cover == nil ? suggestion : nil) }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(session.selected == nil || session.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
            .enterOnAppear(delay: 0.26)
        }
    }

    /// "<C:\Games\…> klasörüne kuruldu…" with the path in mono.
    private func doneText(_ folder: String) -> Text {
        let full = L("installer.done.body", folder)
        guard let range = full.range(of: folder) else { return Text(full) }
        return Text(full[..<range.lowerBound])
            + Text(folder).font(Theme.Font.mono).foregroundColor(Theme.Palette.textPrimary)
            + Text(full[range.upperBound...])
    }

    // Failure

    private func failure(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            NoticeBanner(kind: .destructive, title: reason == L10nKey.installerCrashed ? L("installer.crashed.title") : L("installer.failed"), message: L(reason))
                .enterOnAppear()
            HStack(spacing: 8) {
                Button(L("installer.browse"), action: browse).buttonStyle(SecondaryButtonStyle())
                Button(L("installer.openDrive")) { model.revealDriveC() }.buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button(L("common.retry")) { Task { await model.runInstaller(session) } }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .enterOnAppear(delay: 0.08)
        }
    }

    // MARK: Pickers

    /// Pick the game's .exe by hand, starting in the environment's C: drive.
    private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .item]
        panel.directoryURL = session.result.installDirectory ?? model.customDriveC
        panel.message = L("import.panel.exe")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let candidate = ExeCandidate(url: url, windowsPath: InstallScanner.windowsPath(of: url, driveC: model.customDriveC),
                                     size: Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0), score: 1000)
        session.result.candidates.removeAll { $0.url == url }
        session.result.candidates.insert(candidate, at: 0)
        session.selected = url
        if session.title.isEmpty { session.title = AppModel.suggestedTitle(for: url) }
        session.phase = .choosing
    }

    private func chooseCover() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .webP, .heic]
        panel.message = L("import.panel.cover")
        if panel.runModal() == .OK { cover = panel.url }
    }
}
