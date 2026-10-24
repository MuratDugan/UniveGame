import AppKit
import SwiftUI
import UniveEngineKit

/// The game page's saves panel: which folders hold the saves, a backup now, and the backups to restore.
struct SavesPanel: View {
    let item: LibraryItem
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale
    @State private var candidates: [SaveCandidate]?
    @State private var searching = false
    @State private var restoring: SaveBackupInfo?

    var body: some View {
        let sources = model.saveSources(for: item)
        let backups = model.saveBackups(for: item)
        let busy = model.savesBusy.contains(item.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("saves.title")).font(Theme.Font.section).foregroundStyle(Theme.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if busy { ProgressView().controlSize(.small) }
            }
            if sources.isEmpty {
                Text(L("saves.unknown")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources) { source in
                        HStack(spacing: 8) {
                            Image(systemName: "folder").foregroundStyle(Theme.Palette.textSecondary)
                            Text(source.displayPath).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textPrimary)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 0)
                            Button { model.setSaveSources(sources.filter { $0 != source }, for: item) } label: {
                                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(.plain).foregroundStyle(Theme.Palette.textTertiary)
                            .help(L("saves.removeFolder")).accessibilityLabel(L("saves.removeFolder"))
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                if !sources.isEmpty {
                    Button(L("saves.backUpNow")) { Task { await model.backUpSaves(item) } }
                        .buttonStyle(PrimaryButtonStyle(height: 32, horizontalPadding: 14))
                        .disabled(busy)
                }
                Button(L("saves.find")) { Task { await find() } }
                    .buttonStyle(SecondaryButtonStyle(height: 32, horizontalPadding: 14))
                    .disabled(searching || busy)
                Button(L("saves.addFolder")) { chooseFolder() }
                    .buttonStyle(SecondaryButtonStyle(height: 32, horizontalPadding: 14))
                if searching { ProgressView().controlSize(.small) }
            }
            if let error = model.saveErrors[item.id] {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.warning)
            }
            if !backups.isEmpty {
                Rectangle().fill(Theme.Palette.border).frame(height: 1)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(backups.prefix(5)) { backup in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(backup.created.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)))
                                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
                                Text("\(L("saves.kind.\(backup.kind.rawValue)")) · \(ByteCountFormatter.string(fromByteCount: backup.bytes, countStyle: .file))")
                                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Button(L("action.showInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([backup.folder]) }
                                .buttonStyle(SecondaryButtonStyle(height: 28, horizontalPadding: 10))
                            Button(L("saves.restore")) { restoring = backup }
                                .buttonStyle(SecondaryButtonStyle(height: 28, horizontalPadding: 10))
                                .disabled(busy || model.isRunning(item))
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
        .sheet(item: Binding(get: { candidates.map { CandidateList(items: $0) } }, set: { if $0 == nil { candidates = nil } })) { list in
            SaveCandidatesSheet(item: item, candidates: list.items) { candidates = nil }
        }
        .confirmationDialog(L("saves.restore.title"), isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }),
                            titleVisibility: .visible) {
            Button(L("saves.restore")) {
                if let backup = restoring { Task { await model.restoreSaves(backup, for: item) } }
                restoring = nil
            }
            Button(L("common.cancel"), role: .cancel) { restoring = nil }
        } message: {
            Text(L("saves.restore.message"))
        }
    }

    private func find() async {
        searching = true
        defer { searching = false }
        let found = await model.saveCandidates(for: item)
        candidates = found
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = L("saves.addFolder.panel")
        if let roots = model.saveRoots(for: item) { panel.directoryURL = roots.profile }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let source = model.saveSource(for: url, item: item) else {
            model.alert = AppAlert(titleKey: "saves.outside", message: "")
            return
        }
        let sources = model.saveSources(for: item)
        if !sources.contains(source) { model.setSaveSources(sources + [source], for: item) }
    }
}

private struct CandidateList: Identifiable {
    let id = UUID()
    let items: [SaveCandidate]
}

/// Found save folders, for the player to tick the right ones.
private struct SaveCandidatesSheet: View {
    let item: LibraryItem
    let candidates: [SaveCandidate]
    let done: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale
    @State private var chosen: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L("saves.candidates.title", item.title)).font(Theme.Font.title).foregroundStyle(Theme.Palette.textPrimary)
            Text(L(candidates.isEmpty ? "saves.candidates.none" : "saves.candidates.help"))
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(candidates) { c in
                        Toggle(isOn: Binding(get: { chosen.contains(c.id) },
                                             set: { if $0 { chosen.insert(c.id) } else { chosen.remove(c.id) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.source.displayPath).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textPrimary)
                                Text(detail(c)).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)
            HStack {
                Spacer()
                Button(L("common.cancel"), action: done).buttonStyle(SecondaryButtonStyle())
                Button(L("saves.candidates.save")) {
                    let picked = candidates.filter { chosen.contains($0.id) }.map(\.source)
                    let existing = model.saveSources(for: item)
                    model.setSaveSources(existing + picked.filter { !existing.contains($0) }, for: item)
                    done()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(chosen.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 600)
        .background(Theme.Palette.surface)
        .onAppear { chosen = Set(candidates.filter { $0.reason == .steamCloud || $0.reason == .nameMatch }.map(\.id)) }
    }

    private func detail(_ c: SaveCandidate) -> String {
        var parts = [L("saves.reason.\(c.reason.rawValue)"), L("saves.files", "\(c.files)"),
                     ByteCountFormatter.string(fromByteCount: c.bytes, countStyle: .file)]
        if let modified = c.modified { parts.append(modified.formatted(.relative(presentation: .named).locale(locale))) }
        return parts.joined(separator: " · ")
    }
}

/// Settings › General: where backups go and whether they happen after each session.
struct SaveBackupSettingsCard: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 10) {
            Text(L("saves.settings.title")).font(Theme.Font.section).foregroundStyle(Theme.Palette.textPrimary)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: Theme.Spacing.md) {
                    Text(model.saveBackupFolder.appendingPathComponent(SaveBackupStore.folderName).path)
                        .font(Theme.Font.mono).foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    Spacer(minLength: 0)
                    if let iCloud = SaveBackupStore.iCloudDrive, model.saveBackupFolder != iCloud {
                        Button(L("saves.settings.iCloud")) { model.saveBackupFolder = iCloud }
                            .buttonStyle(SecondaryButtonStyle(height: 32, horizontalPadding: 12))
                    }
                    Button(L("saves.settings.change")) { choose() }
                        .buttonStyle(SecondaryButtonStyle(height: 32, horizontalPadding: 12))
                }
                Rectangle().fill(Theme.Palette.border).frame(height: 1)
                SettingToggle(title: L("saves.settings.auto"), detail: L("saves.settings.auto.help"), isOn: $model.autoBackupSaves)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = L("saves.settings.panel")
        if panel.runModal() == .OK, let url = panel.url { model.saveBackupFolder = url }
    }
}
