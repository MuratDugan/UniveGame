import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Adds (or edits) a Windows game the user already has as an .exe file.
struct ImportGameSheet: View {
    let editing: CustomGame?
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.dismiss) private var dismiss

    @State private var executable: URL?
    @State private var title = ""
    @State private var arguments = ""
    @State private var cover: URL?
    @State private var dropTargeted = false
    @State private var error: String?
    @State private var suggestion: CoverSuggestion?
    @State private var searching = false

    private static let exeType = UTType(filenameExtension: "exe") ?? .item

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text(editing == nil ? L("import.title") : L("import.editTitle")).font(Theme.Font.title)
                Text(L("import.subtitle")).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
            }

            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                coverPicker
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    exePicker
                    field(L("import.name"), help: L("import.name.help")) {
                        TextField(L("import.name"), text: $title)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                    }
                    field(L("import.arguments"), help: L("import.arguments.help")) {
                        TextField("-windowed -dx11", text: $arguments)
                            .textFieldStyle(.roundedBorder)
                            .font(Theme.Font.mono)
                            .labelsHidden()
                    }
                }
            }

            if let executable, AppModel.looksLikeInstaller(executable), editing == nil {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    Image(systemName: "shippingbox.fill").font(.system(size: 20)).foregroundStyle(Theme.Palette.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("import.installerDetected")).font(.system(size: 13, weight: .semibold))
                        Text(L("import.installerWarning")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(L("import.runInstaller")) { model.beginInstaller(executable) }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.border))
            }
            if let error {
                Label(error, systemImage: "xmark.octagon.fill")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.destructive)
            }

            HStack {
                Spacer()
                Button(L("common.cancel")) { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(editing == nil ? L("import.add") : L("common.save")) { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 640)
        .background(Theme.Palette.surface)
        .onAppear(perform: loadEditing)
        .task(id: title) {
            // Like a media server: look the title up once the user stops typing, unless they picked a cover.
            guard cover == nil, editing?.coverImage == nil else { return }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            searching = true
            suggestion = await CoverFinder.find(title: title, languageCode: L.resolvedCode)
            searching = false
        }
    }

    // MARK: Pieces

    private var exePicker: some View {
        field(L("import.exe"), help: nil) {
            Button(action: chooseExecutable) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: executable == nil ? "square.and.arrow.down" : "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(executable == nil ? Theme.Palette.accent : Theme.Palette.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(executable?.lastPathComponent ?? L("import.drop"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(executable?.deletingLastPathComponent().path ?? L("import.drop.help"))
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(executable == nil ? L("import.choose") : L("import.change"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(dropTargeted ? Theme.Palette.accent.opacity(0.12) : Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(dropTargeted ? Theme.Palette.accent : Theme.Palette.border, style: StrokeStyle(lineWidth: 1.5, dash: executable == nil ? [6, 4] : [])))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                loadDroppedURL(providers) { url in
                    if url.pathExtension.lowercased() == "exe" { setExecutable(url) }
                    else { error = L("import.error.notExe") }
                }
            }
            .accessibilityLabel(L("import.exe"))
            .accessibilityHint(L("import.drop.help"))
        }
    }

    private var coverPicker: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(action: chooseCover) {
                CoverArt(url: cover ?? suggestion?.cover, title: title, symbol: "photo")
                    .frame(width: 140, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.border))
                    .overlay(alignment: .bottom) {
                        Text(cover == nil ? L("import.cover.add") : L("import.change"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(.black.opacity(0.55))
                            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Theme.Radius.md, bottomTrailingRadius: Theme.Radius.md))
                    }
            }
            .buttonStyle(.plain)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadDroppedURL(providers) { url in
                    if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true { cover = url }
                }
            }
            .accessibilityLabel(L("import.cover"))
            if cover == nil, let suggestion {
                HStack(spacing: 4) {
                    Text(L("cover.found", suggestion.name)).lineLimit(2)
                    Button { self.suggestion = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .help(L("cover.dismiss"))
                        .accessibilityLabel(L("cover.dismiss"))
                }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 140)
            } else if searching {
                HStack(spacing: 4) { ProgressView().controlSize(.mini); Text(L("cover.searching")) }
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            } else {
                Text(L("import.cover.help"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 140)
            }
        }
    }

    private func field<Content: View>(_ label: String, help: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            content()
            if let help {
                Text(help).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    // MARK: Logic

    private var isValid: Bool {
        executable != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadEditing() {
        guard let editing, executable == nil else { return }
        executable = editing.executable
        title = editing.title
        arguments = editing.arguments.joined(separator: " ")
        cover = editing.coverImage
    }

    private func setExecutable(_ url: URL) {
        error = nil
        executable = url
        if title.isEmpty { title = AppModel.suggestedTitle(for: url) }
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.exeType]
        panel.allowsMultipleSelection = false
        panel.message = L("import.panel.exe")
        if panel.runModal() == .OK, let url = panel.url { setExecutable(url) }
    }

    private func chooseCover() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .webP, .heic]
        panel.allowsMultipleSelection = false
        panel.message = L("import.panel.cover")
        if panel.runModal() == .OK, let url = panel.url { cover = url }
    }

    private func loadDroppedURL(_ providers: [NSItemProvider], _ handle: @escaping (URL) -> Void) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async { handle(url) }
        }
        return true
    }

    private func save() {
        guard let executable else { return }
        let name = title.trimmingCharacters(in: .whitespaces)
        let args = arguments.split(separator: " ").map(String.init)
        do {
            if var game = editing {
                game.title = name
                game.executable = executable
                game.arguments = args
                try model.updateCustomGame(game, newCover: cover)
                if cover == nil, let suggestion { Task { await model.applyCover(suggestion, to: game.id) } }
            } else {
                try model.addCustomGame(title: name, executable: executable, arguments: args, cover: cover,
                                        suggestion: cover == nil ? suggestion : nil)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
