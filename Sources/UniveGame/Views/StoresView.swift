import UniveEngineKit
import SwiftUI
import WebKit

struct StoresView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @State private var signingIn: StoreKind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(title: L("stores.v2.title"), subtitle: L("stores.v2.subtitle")) {
                    ConnectionMeter()
                        .frame(width: 300)
                        .enterOnAppear(delay: 0.08)
                }
                VStack(spacing: 8) {
                    ForEach(Array(StoreKind.allCases.enumerated()), id: \.element) { i, kind in
                        StoreRow(kind: kind, isPrimary: kind == primaryStore) { signingIn = kind }
                            .enter(index: i, base: 0.14)
                    }
                }
            }
            .padding(.top, Theme.Layout.pageTitleTop)
            .padding(.horizontal, Theme.Layout.pageInsetX)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollIndicators(.automatic)
        .background(Theme.Palette.background)
        .sheet(item: $signingIn) { kind in
            StoreLoginSheet(kind: kind) { code in
                signingIn = nil
                Task { await model.completeSignIn(kind, code: code) }
            }
        }
    }

    /// The screen's one primary action: the first store waiting for sign-in, else the first not set up.
    private var primaryStore: StoreKind? {
        StoreKind.allCases.first { model.connection(for: $0) == .needsSignIn }
            ?? StoreKind.allCases.first { model.connection(for: $0) == .notSetUp }
    }
}

extension StoreKind: @retroactive Identifiable {
    public var id: String { rawValue }
}

/// "2 / 5 stores connected · 243 games" over five segments.
private struct ConnectionMeter: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L

    var body: some View {
        let kinds = StoreKind.allCases
        let connected = kinds.filter { model.connection(for: $0) == .ready }
        let games = model.items.filter { if case .store = $0.backing { return true }; return false }.count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                meterText(connected.count, kinds.count)
                Spacer()
                Text(L("stores.gameCount", games)).monospacedDigit()
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            HStack(spacing: 4) {
                ForEach(kinds, id: \.self) { kind in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(model.connection(for: kind) == .ready ? Theme.Palette.success : Theme.Palette.elevated)
                        .frame(height: 6)
                        .animation(Theme.Motion.valueChange, value: model.connection(for: kind))
                }
            }
            .growOnAppear(delay: 0.3)
        }
        .accessibilityElement(children: .combine)
    }

    /// The count in primary text, the rest secondary.
    private func meterText(_ n: Int, _ total: Int) -> Text {
        let count = "\(n) / \(total)"
        let full = L("stores.meter.connected", "\(n)", "\(total)")
        guard let range = full.range(of: count) else { return Text(full) }
        return Text(full[..<range.lowerBound])
            + Text(count).foregroundColor(Theme.Palette.textPrimary).fontWeight(.semibold)
            + Text(full[range.upperBound...])
    }
}

private struct StoreRow: View {
    let kind: StoreKind
    let isPrimary: Bool
    let onSignIn: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var L
    @Environment(\.locale) private var locale

    var body: some View {
        let connection = model.connection(for: kind)
        HStack(spacing: 16) {
            Image(systemName: GameSource.store(kind).symbol)
                .font(.system(size: 19))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.Palette.elevated, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName).font(Theme.Font.statSmall).foregroundStyle(Theme.Palette.textPrimary)
                Text(L("stores.\(kind.rawValue).about"))
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 360, alignment: .leading)
            status(connection)
                .frame(maxWidth: .infinity, alignment: .leading)
            actions(connection)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .hoverFill(Theme.Palette.card, hover: Theme.Palette.cardHover, cornerRadius: Theme.Radius.lg)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Palette.border))
        .accessibilityElement(children: .contain)
    }

    private var syncing: Bool { model.refreshing && model.connection(for: kind) == .ready }

    private func status(_ c: StoreConnection) -> some View {
        let (text, dot, fg): (String, Color, Color) = if syncing {
            (L("stores.status.syncing"), Theme.Palette.accent, Theme.Palette.accent)
        } else {
            switch c {
            case .ready where model.syncErrors[kind] != nil:
                (L("stores.status.syncFailed"), Theme.Palette.warning, Theme.Palette.warning)
            case .ready: (L("stores.status.ready"), Theme.Palette.success, Theme.Palette.success)
            case .needsSignIn: (L("stores.status.signIn"), Theme.Palette.warning, Theme.Palette.warning)
            case .notSetUp: (L("stores.status.notSetUp"), Theme.Palette.segmentSelected, Theme.Palette.textSecondary)
            }
        }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Group {
                    if syncing { Circle().fill(dot).frame(width: 8, height: 8).pulsing() }
                    else { Circle().fill(dot).frame(width: 8, height: 8) }
                }
                Text(text).contentTransition(.opacity)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(fg)
            .animation(Theme.Motion.quick, value: text)
            if let meta = meta(c) {
                Text(meta).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).monospacedDigit()
                    .lineLimit(1)
                    .help(model.syncErrors[kind] ?? (kind == .steam ? (model.steamAccount.map { L("stores.signedInAs", $0.personaName) } ?? "") : ""))
            }
            if syncing || model.isBusy(kind) {
                IndeterminateBar(height: 3).frame(width: 160)
            }
        }
    }

    private func meta(_ c: StoreConnection) -> String? {
        let count = model.count(for: .source(.store(kind)))
        switch c {
        case .ready:
            let games = "\(count)"
            if syncing {
                let found = model.newGamesFound[kind] ?? 0
                return found > 0 ? "\(L("stores.gameCount", count)) · \(L("stores.meta.found", "\(found)"))" : L("stores.gameCount", count)
            }
            if let error = model.syncErrors[kind] {
                return "\(L("stores.gameCount", count)) · \(error)"
            }
            if let last = model.lastSynced[kind] {
                return L("stores.meta.synced", games, last.formatted(.relative(presentation: .named).locale(locale)))
            }
            return L("stores.gameCount", count)
        case .needsSignIn:
            return count > 0 ? L("stores.gameCount", count) : nil
        case .notSetUp:
            return Self.approximateSize[kind].map { L("stores.meta.size", $0) }
        }
    }

    /// Rough download sizes of each store's helper or launcher.
    private static let approximateSize: [StoreKind: String] = [.gog: "40 MB", .ubisoft: "300 MB", .ea: "250 MB", .epic: "15 MB"]

    @ViewBuilder private func actions(_ c: StoreConnection) -> some View {
        HStack(spacing: 8) {
            if model.isBusy(kind) {
                EmptyView()
            } else {
                switch (c, kind) {
                case (.notSetUp, _):
                    button(L(kind.usesLauncher ? "stores.installLauncher" : "stores.setUp"), primary: isPrimary) {
                        Task { await model.setUp(kind) }
                    }
                case (.needsSignIn, .steam):
                    button(L("stores.steam.signIn"), primary: isPrimary) { model.openLauncher(.steam) }
                    button(L("steam.repair")) { model.confirmingSteamRepair = true }
                case (.needsSignIn, _):
                    button(L("stores.signIn"), primary: isPrimary, action: onSignIn)
                case (.ready, .steam), (.ready, .ubisoft), (.ready, .ea):
                    button(L("stores.openLauncher", kind.displayName)) { model.openLauncher(kind) }
                    if !syncing { button(L("action.refresh")) { Task { await model.refreshStores() } } }
                    if kind == .steam { button(L("steam.repair")) { model.confirmingSteamRepair = true } }
                case (.ready, _):
                    if !syncing { button(L("action.refresh")) { Task { await model.refreshStores() } } }
                    button(L("stores.signOut")) { Task { await model.signOut(kind) } }
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder private func button(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        if primary {
            Button(title, action: action).buttonStyle(PrimaryButtonStyle(height: 34, horizontalPadding: 16))
        } else {
            Button(title, action: action).buttonStyle(SecondaryButtonStyle(height: 34, horizontalPadding: 16))
        }
    }
}

/// The store's own sign-in page. We only read the one-time code it hands back at the end;
/// the password is typed into the store's page and never seen by the app.
struct StoreLoginSheet: View {
    let kind: StoreKind
    let onCode: (String) -> Void
    @Environment(Localizer.self) private var L
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("stores.signInTo", kind.displayName), systemImage: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(L("common.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(Theme.Spacing.md)
            Divider()
            StoreLoginWebView(kind: kind, onCode: onCode)
        }
        .frame(width: 520, height: 720)
    }

    static func loginURL(for kind: StoreKind) -> URL? {
        switch kind {
        case .epic:
            URL(string: "https://www.epicgames.com/id/login?redirectUrl=https%3A//www.epicgames.com/id/api/redirect%3FclientId%3D34a02cf8f4414e29b15921876da36f9a%26responseType%3Dcode")
        case .gog:
            URL(string: "https://auth.gog.com/auth?client_id=46899977096215655&redirect_uri=https%3A%2F%2Fembed.gog.com%2Fon_login_success%3Forigin%3Dclient&response_type=code&layout=client2")
        default: nil
        }
    }
}

private struct StoreLoginWebView: NSViewRepresentable {
    let kind: StoreKind
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(kind: kind, onCode: onCode) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // no cookies left behind
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        if let url = StoreLoginSheet.loginURL(for: kind) { view.load(URLRequest(url: url)) }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let kind: StoreKind
        let onCode: (String) -> Void
        private var delivered = false

        init(kind: StoreKind, onCode: @escaping (String) -> Void) {
            self.kind = kind
            self.onCode = onCode
        }

        private func deliver(_ code: String) {
            guard !delivered, !code.isEmpty else { return }
            delivered = true
            onCode(code)
        }

        // GOG redirects to embed.gog.com/on_login_success?code=…
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if kind == .gog, let url = navigationAction.request.url, url.scheme == "https", url.host == "embed.gog.com",
               url.path.contains("on_login_success"),
               let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value {
                decisionHandler(.cancel)
                deliver(code)
                return
            }
            decisionHandler(.allow)
        }

        // Epic ends on /id/api/redirect, a JSON page carrying "authorizationCode".
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Only Epic's own redirect page may hand over a code; a look-alike path on another site is ignored.
            guard kind == .epic, let url = webView.url, url.scheme == "https", url.host == "www.epicgames.com",
                  url.path == "/id/api/redirect" else { return }
            webView.evaluateJavaScript("document.body.innerText") { [weak self] result, _ in
                guard let text = result as? String, let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let code = json["authorizationCode"] as? String else { return }
                self?.deliver(code)
            }
        }
    }
}
