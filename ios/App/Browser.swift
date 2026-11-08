import SwiftUI
import WebKit

enum SearchEngine: String, CaseIterable, Identifiable {
    case duckDuckGo, brave, ecosia, startpage, google
    var id: String { rawValue }

    var name: String {
        switch self {
        case .duckDuckGo: "DuckDuckGo"
        case .brave: "Brave Search"
        case .ecosia: "Ecosia"
        case .startpage: "Startpage"
        case .google: "Google"
        }
    }

    private var base: String {
        switch self {
        case .duckDuckGo: "https://duckduckgo.com/"
        case .brave: "https://search.brave.com/search"
        case .ecosia: "https://www.ecosia.org/search"
        case .startpage: "https://www.startpage.com/do/search"
        case .google: "https://www.google.com/search"
        }
    }

    func searchURL(_ query: String) -> URL? {
        var c = URLComponents(string: base)!
        c.queryItems = [URLQueryItem(name: "q", value: query)]
        return c.url
    }
}

/// Turns what the user typed into a URL: a scheme-less host gets https, anything else becomes a search.
func resolve(_ input: String, engine: SearchEngine = .google) -> URL? {
    let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }
    if s.contains("://"), let u = URL(string: s) { return u }
    if !s.contains(" "), s.contains("."), let u = URL(string: "https://" + s) { return u }
    return engine.searchURL(s)
}

/// Hands a non-web link (mailto:, tel:, an app's own scheme) to the system.
func openExternally(_ url: URL) {
    #if os(macOS)
    NSWorkspace.shared.open(url)
    #else
    UIApplication.shared.open(url)
    #endif
}

@MainActor
final class Page: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    let web: WKWebView
    let isPrivate: Bool
    private let services: Services
    @Published var address = ""
    @Published var title = ""
    @Published var loading = false
    @Published var errorMessage: String?
    @Published var canBack = false
    @Published var canForward = false
    @Published var secure = false
    /// A link asked for a new window (target=_blank). The tab list opens it as a tab.
    var onNewTab: ((URL) -> Void)?
    /// Something worth saving changed (a page finished loading).
    var onChange: (() -> Void)?
    /// Callers waiting for the current load to end (the automation server). Resumed by didFinish, didFail or a timeout.
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    /// `start` nil opens the homepage, "" opens nothing.
    init(_ start: String? = nil, services: Services = .shared, isPrivate: Bool = false) {
        self.services = services
        self.isPrivate = isPrivate
        let config = WKWebViewConfiguration()
        config.websiteDataStore = isPrivate ? .nonPersistent() : services.dataStore
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        services.blocker.register(web)
        services.siteBlocker.register(web)
        go(start ?? services.settings.homepage)
    }

    /// Applies the zoom from this site's rule to the page on screen.
    func applyZoom() { web.pageZoom = services.sites.rule(for: web.url).pageZoom }

    /// Command-plus, minus and zero. The zoom is kept as this site's rule, like Safari remembers it per site;
    /// a private tab only zooms the page in front of you.
    func zoom(by step: Double?) {
        let next = step.map { (((web.pageZoom + $0) * 10).rounded() / 10) } ?? 1
        web.pageZoom = min(max(next, SiteRule.zoomRange.lowerBound), SiteRule.zoomRange.upperBound)
        guard !isPrivate, let key = SiteKey.key(for: web.url) else { return }
        var rule = services.sites.rule(for: web.url)
        rule.zoom = web.pageZoom
        services.sites.set(rule, forKey: key)
    }

    func go(_ input: String) {
        guard let u = resolve(input, engine: services.settings.engine) else { return }
        web.load(URLRequest(url: u))
    }

    /// Runs `action` (a load, back, forward or reload) and returns once the page finishes or fails, or after `timeout`.
    func perform(timeout: TimeInterval = 20, _ action: () -> Void) async {
        let id = UUID()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            waiters[id] = c
            action()
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.waiters.removeValue(forKey: id)?.resume()
            }
        }
    }

    /// Loads what the user would have typed and waits for it.
    func load(_ input: String, timeout: TimeInterval = 20) async {
        guard resolve(input, engine: services.settings.engine) != nil else { return }
        await perform(timeout: timeout) { go(input) }
    }

    private func flushWaiters() {
        let all = waiters
        waiters = [:]
        for c in all.values { c.resume() }
    }

    private func sync() {
        address = web.url?.absoluteString ?? address
        title = web.title.flatMap { $0.isEmpty ? nil : $0 } ?? web.url?.host() ?? "New Tab"
        loading = web.isLoading
        canBack = web.canGoBack
        canForward = web.canGoForward
        secure = web.url?.scheme == "https" && web.hasOnlySecureContent
    }

    func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { errorMessage = nil; sync() }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        sync()
        if !isPrivate, let url = w.url, url.scheme == "https" || url.scheme == "http" {
            services.library.record(title: title, url: url.absoluteString)
            Task { await services.icons.learn(from: w) }
        }
        onChange?()
        flushWaiters()
    }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) {
        sync()
        if (e as NSError).code != NSURLErrorCancelled { errorMessage = e.localizedDescription }
        flushWaiters()
    }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) {
        webView(w, didFail: n, withError: e)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loading = false
        errorMessage = "This page stopped responding. Reload to try again."
        flushWaiters()
    }

    /// Web links stay in the tab; mailto:, tel: and other schemes go to the system.
    /// Page loads also pick up the site's rules: scripts on or off, a dark look, zoom.
    func webView(_ w: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        if action.shouldPerformDownload { return (.download, preferences) }
        return await decide(request: action.request, mainFrame: action.targetFrame?.isMainFrame ?? true, preferences: preferences)
    }

    /// What the page cannot show, or what the server marks as an attachment, is saved as a download.
    func webView(_ w: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        let disposition = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        if response.isForMainFrame, disposition.lowercased().hasPrefix("attachment") { return .download }
        return response.canShowMIMEType ? .allow : .download
    }

    func webView(_ w: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        services.downloads.adopt(download)
    }

    func webView(_ w: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        services.downloads.adopt(download)
    }

    /// The decision behind the delegate call, kept apart so tests can run it without a real navigation.
    func decide(request: URLRequest, mainFrame: Bool = true,
                preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        guard let url = request.url, let scheme = url.scheme?.lowercased() else { return (.allow, preferences) }
        if ["http", "https"].contains(scheme) {
            if mainFrame { applyRules(for: url, to: preferences) }
            return (.allow, preferences)
        }
        if ["about", "blob", "data", "file"].contains(scheme) { return (.allow, preferences) }
        openExternally(url)
        return (.cancel, preferences)
    }

    private func applyRules(for url: URL, to preferences: WKWebpagePreferences) {
        let rule = services.sites.rule(for: url)
        // HTTPS first: an http:// address is tried over https, falling back to http only if that fails.
        preferences.preferredHTTPSNavigationPolicy = .automaticFallbackToHTTP
        preferences.allowsContentJavaScript = !rule.blockScripts
        let controller = web.configuration.userContentController
        controller.removeAllUserScripts()
        if rule.forceDark {
            controller.addUserScript(WKUserScript(source: SiteRule.darkScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        web.pageZoom = rule.pageZoom
    }

    func webView(_ w: WKWebView, createWebViewWith config: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let rule = services.sites.rule(for: w.url)
        guard rule.allowsNewWindow(userTappedLink: action.navigationType == .linkActivated) else { return nil }
        if let url = action.request.url { onNewTab?(url) }
        return nil
    }
}

/// The open tabs. Normal tabs are restored on the next launch; private tabs never are.
@MainActor
final class Tabs: ObservableObject {
    @Published var pages: [Page]
    @Published var current: UUID
    /// Two pages in one window (iPhone and iPad). Nil when not pairing.
    @Published var pair: PairModel?
    private let services: Services
    private let defaults: UserDefaults?
    static let restoreKey = "tabs.urls"
    /// Addresses of recently closed tabs, newest last, for Reopen Closed Tab. Private tabs are never kept.
    @Published private(set) var closed: [String] = []

    init(services: Services = .shared, restore: Bool = false, defaults: UserDefaults = .standard) {
        self.services = services
        self.defaults = restore ? defaults : nil
        var start: [Page] = []
        if restore, let saved = defaults.stringArray(forKey: Tabs.restoreKey), !saved.isEmpty {
            start = saved.map { Page($0, services: services) }
        }
        if start.isEmpty { start = [Page(services: services)] }
        pages = start
        current = start[0].id
        for p in start { wire(p) }
    }

    var page: Page { pages.first { $0.id == current } ?? pages[0] }

    private func wire(_ p: Page) {
        p.onNewTab = { [weak self] url in self?.add(url.absoluteString) }
        p.onChange = { [weak self] in self?.save() }
    }

    func add(_ start: String? = nil, isPrivate: Bool = false) {
        let p = Page(start, services: services, isPrivate: isPrivate)
        wire(p)
        pages.append(p)
        current = p.id
        save()
    }

    func close(_ p: Page) {
        guard pages.count > 1, let i = pages.firstIndex(where: { $0.id == p.id }) else { return }
        if !p.isPrivate, let url = p.web.url?.absoluteString {
            closed.append(url)
            if closed.count > 20 { closed.removeFirst() }
        }
        pages.remove(at: i)
        if current == p.id { current = pages[min(i, pages.count - 1)].id }
        save()
    }

    /// The fire button: every tab closes, history, cookies and site data go, and one fresh tab is left.
    /// Bookmarks, the reading list and site rules stay.
    func burn() async {
        closed = []
        pair = nil
        let fresh = Page(services: services)
        wire(fresh)
        pages = [fresh]
        current = fresh.id
        save()
        services.library.clearHistory()
        services.icons.removeAll()
        await services.dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }

    func reopenClosed() {
        guard let url = closed.popLast() else { return }
        add(url)
    }

    /// Command-1 to 8 pick that tab; Command-9 is always the last one, like Safari.
    func select(number n: Int) {
        let i = n == 9 ? pages.count - 1 : n - 1
        if pages.indices.contains(i) { current = pages[i].id }
    }

    /// Control-Tab and Control-Shift-Tab, wrapping around.
    func cycle(_ step: Int) {
        guard let i = pages.firstIndex(where: { $0.id == current }) else { return }
        current = pages[(i + step + pages.count) % pages.count].id
    }

    /// Opens a link that arrived from outside the window. Float is handled by the Mac window code.
    func open(_ link: IncomingLink) {
        switch link.destination {
        case .tab, .float: add(link.url.absoluteString)
        case .pair: startPair(second: link.url.absoluteString)
        }
    }

    /// Splits the window: the current tab on one side, `second` (or the homepage) on the other.
    func startPair(second: String? = nil) {
        if let pair {
            if let second { pair.second.go(second) }
            return
        }
        let p = Page(second, services: services)
        p.onNewTab = { [weak p] url in p?.go(url.absoluteString) }
        pair = PairModel(first: page, second: p)
    }

    func endPair() { pair = nil }

    private func save() {
        guard let defaults else { return }
        let urls = pages.filter { !$0.isPrivate }.compactMap { $0.web.url?.absoluteString }
        defaults.set(urls, forKey: Tabs.restoreKey)
    }
}

#if os(macOS)
struct WebView: NSViewRepresentable {
    let web: WKWebView
    func makeNSView(context: Context) -> WKWebView { web }
    func updateNSView(_ v: WKWebView, context: Context) {}
}
#else
struct WebView: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> WKWebView { web }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
#endif
