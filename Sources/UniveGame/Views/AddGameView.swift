import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// v2 Add Game page: three ways in, and the form for a game that's already installed.
struct AddGameView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale
    @Environment(\.windowDropTargeted) private var dropTargeted

    @State private var executable: URL?
    @State private var title = ""
    @State private var arguments = ""
    @State private var cover: URL?
    @State private var suggestion: CoverSuggestion?
    @State private var searching = false
    @State private var firstLook: (report: CompatReport, files: FileFindings)?
    @State private var looking = false
    @State private var error: String?

    private static let exeType = UTType(filenameExtension: "exe") ?? .item

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                PageHeader(title: L("add.title"), subtitle: L("add.subtitle"))
                methods
                form.enterOnAppear(delay: 0.24)
            }
            .padding(.top, Theme.Layout.pageTitleTop)
            .padding(.horizontal, Theme.Layout.pageInsetX)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollIndicators(.automatic)
        .background(Theme.Palette.background)
        .onAppear(perform: takeDroppedFile)
        .onChange(of: model.pendingImportExecutable) { _, _ in takeDroppedFile() }
        .task(id: title) {
            // Like a media server: look the title up once the user stops typing, unless they picked a cover.
            guard executable != nil, cover == nil else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            searching = true
            let found = await CoverFinder.find(title: title, languageCode: L.resolvedCode)
            guard !Task.isCancelled else { return }
            suggestion = found
            searching = false
        }
        .task(id: executable) {
            guard let executable else { firstLook = nil; return }
            looking = true
            firstLook = await model.firstLook(executable: executable)
            looking = false
        }
    }

    // MARK: Methods

    private var methods: some View {
        HStack(spacing: Theme.Spacing.md) {
            MethodTile(title: L("add.method.installed"), detail: L("add.method.installed.detail"),
                       symbol: "doc.text", isSelected: true) { if executable == nil { chooseExecutable() } }
                .enter(index: 0, base: 0.06)
            MethodTile(title: L("add.method.setup"), detail: L("add.method.setup.detail"),
                       symbol: "shippingbox", isSelected: false) { model.chooseInstaller(message: L("menu.runInstaller")) }
                .enter(index: 1, base: 0.06)
            MethodTile(title: L("add.method.store"), detail: L("add.method.store.detail"),
                       symbol: "link", isSelected: false) { model.selection = .stores }
                .enter(index: 2, base: 0.06)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Form

    private var form: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xl) {
            coverColumn.frame(width: 180)
            VStack(alignment: .leading, spacing: 18) {
                fileRow
                if executable != nil {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        field(L("import.name"), help: L("import.name.help")) {
                            InputField(text: $title, placeholder: L("import.name"))
                        }
                        field(L("import.arguments"), help: L("import.arguments.help")) {
                            InputField(text: $arguments, placeholder: "-windowed -dx11", mono: true)
                        }
                    }
                    if let executable, AppModel.looksLikeInstaller(executable) {
                        NoticeBanner(kind: .warning, title: L("import.installerDetected"), message: L("import.installerWarning"),
                                     action: .primary(L("import.runInstaller")) { model.beginInstaller(executable) })
                    } else {
                        firstLookRow
                    }
                }
                if let error {
                    Label(error, systemImage: "xmark.octagon.fill")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.destructive)
                }
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
    }

    private var shownCover: URL? { cover ?? suggestion?.cover }

    private var coverColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                if let url = shownCover {
                    CoverArt(url: url, title: title, symbol: "photo")
                        .frame(width: 180, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.borderStrong))
                        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
                        .id(url)
                        .popOnAppear()
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Palette.elevated)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo").font(.system(size: 22)).foregroundStyle(Theme.Palette.textTertiary)
                                Text(L("add.cover.placeholder")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.border))
                        .frame(width: 180, height: 270)
                    if searching {
                        IndeterminateBar(height: 6).padding(10)
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadDroppedURL(providers) { url in
                    if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true { cover = url }
                }
            }
            .accessibilityLabel(L("import.cover"))

            if cover == nil, suggestion != nil {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Palette.success)
                    Text(L.resolvedCode == "tr" ? L("add.cover.found.steam") : L("add.cover.found", "Steam"))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Theme.Palette.elevated, in: Capsule())
                .help(suggestion?.name ?? "")
                .popOnAppear(delay: 0.2)
                linkButton(L("add.cover.other"), action: chooseCover)
            } else if cover != nil {
                linkButton(L("add.cover.other"), action: chooseCover)
            } else if executable != nil, !searching {
                Button(L("import.cover.add") + "…", action: chooseCover)
                    .buttonStyle(SecondaryButtonStyle(height: 30, horizontalPadding: 12))
            }
        }
    }

    @ViewBuilder private var fileRow: some View {
        if let executable {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.Palette.success)
                    .frame(width: 36, height: 36)
                    .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                VStack(alignment: .leading, spacing: 2) {
                    Text(executable.lastPathComponent).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Text(fileDetail(executable)).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                linkButton(L("import.change") + "…", size: 13, action: chooseExecutable)
            }
            .padding(14)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.Palette.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        } else {
            Button(action: chooseExecutable) {
                DropZone(isTargeted: dropTargeted) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.to.line").font(.system(size: 17)).foregroundStyle(Theme.Palette.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                        Text(L("add.drop")).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                        Spacer(minLength: 8)
                        Text(L("import.choose")).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Palette.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("import.exe"))
            .accessibilityHint(L("import.drop.help"))
        }
    }

    private func fileDetail(_ exe: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var folder = exe.deletingLastPathComponent().path
        if folder.hasPrefix(home) { folder = "~" + folder.dropFirst(home.count) }
        var parts = [folder + "/"]
        if let files = firstLook?.files {
            if files.has64Bit || files.has32Bit { parts.append(files.has64Bit ? "64-bit" : "32-bit") }
            if let api = files.graphics.max() { parts.append(api.displayName) }
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var firstLookRow: some View {
        if looking || firstLook != nil {
            HStack(spacing: 10) {
                if let look = firstLook, !looking {
                    Image(systemName: look.report.tier.symbol).font(.system(size: 15)).foregroundStyle(look.report.tier.color)
                    firstLookText(look.report)
                        .font(Theme.Font.caption)
                        .lineLimit(2)
                } else {
                    ProgressView().controlSize(.small)
                    Text(L("compat.analyzing")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .transition(.opacity)
        }
    }

    private func firstLookText(_ r: CompatReport) -> Text {
        let reasons = r.factors.filter { $0.kind == .positive || $0.kind == .blocker }.prefix(2)
            .map { CompatibilityPanel.trimmed($0.text(L, locale: locale)) }
        var text = Text(L("add.firstLook") + " ").foregroundColor(Theme.Palette.textSecondary)
            + Text(r.tier == .unknown ? L("compat.tier.unknown") : "\(r.score) · \(L("compat.tier.\(r.tier.rawValue)"))")
                .foregroundColor(Theme.Palette.textPrimary).fontWeight(.semibold)
        if !reasons.isEmpty {
            text = text + Text(" · " + reasons.joined(separator: ", ") + ".").foregroundColor(Theme.Palette.textSecondary)
        }
        return text
    }

    private var actions: some View {
        let installer = executable.map(AppModel.looksLikeInstaller) ?? false
        return HStack(spacing: 8) {
            Spacer()
            Button(L("common.cancel")) { reset(); model.selection = .library(.all) }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            if installer {
                Button(L("import.add"), action: save).buttonStyle(SecondaryButtonStyle()).disabled(!isValid)
            } else {
                Button(L("import.add"), action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Pieces

    private func field<Content: View>(_ label: String, help: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            content()
            Text(help).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkButton(_ title: String, size: CGFloat = 12, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(Theme.Palette.accent)
    }

    // MARK: Logic

    private var isValid: Bool {
        executable != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func takeDroppedFile() {
        guard let url = model.pendingImportExecutable else { return }
        model.pendingImportExecutable = nil
        setExecutable(url)
    }

    private func setExecutable(_ url: URL) {
        error = nil
        if executable != url { suggestion = nil }
        executable = url
        if title.isEmpty { title = AppModel.suggestedTitle(for: url) }
    }

    private func reset() {
        executable = nil; title = ""; arguments = ""; cover = nil; suggestion = nil; firstLook = nil; error = nil
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
        do {
            try model.addCustomGame(title: name, executable: executable, arguments: arguments.split(separator: " ").map(String.init),
                                    cover: cover, suggestion: cover == nil ? suggestion : nil)
            reset()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 32 pt text field on the elevated fill.
struct InputField: View {
    @Binding var text: String
    let placeholder: String
    var mono = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.Palette.textTertiary))
            .textFieldStyle(.plain)
            .font(mono ? Theme.Font.mono : .system(size: 13))
            .foregroundStyle(Theme.Palette.textPrimary)
            .focused($focused)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(focused ? Theme.Palette.accent.opacity(0.6) : Theme.Palette.border))
            .animation(Theme.Motion.quick, value: focused)
            .accessibilityLabel(placeholder)
    }
}

/// Large dashed drop area whose edge breathes until a file is over the window.
private struct DropZone<Content: View>: View {
    let isTargeted: Bool
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(isTargeted ? Theme.Palette.card : Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(isTargeted ? Theme.Palette.accent : (lit ? Theme.Palette.accent.opacity(0.6) : Theme.Palette.borderStrong),
                              style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .animation(Theme.Motion.quick, value: isTargeted)
            .contentShape(Rectangle())
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Theme.Motion.edgePulse) { lit = true }
            }
    }
}
