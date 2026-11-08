import SwiftUI
import WebKit

struct BrowserView: View {
    @ObservedObject var tabs: Tabs
    @ObservedObject var services: Services
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            if let pair = tabs.pair {
                PairView(tabs: tabs, pair: pair)
            } else {
                NavigationStack { PageView(tabs: tabs, page: tabs.page, services: services).id(tabs.current) }
            }
            #else
            // The chrome row shares the title bar with the window buttons (hiddenTitleBar in BlackcombApp).
            PageView(tabs: tabs, page: tabs.page, services: services).id(tabs.current)
                .ignoresSafeArea(.container, edges: .top)
            #endif
        }
        .onAppear { drain() }
        .onChange(of: services.incoming) { _, _ in drain() }
        #if os(iOS)
        .sheet(item: $services.sheet) { PanelView(sheet: $0, tabs: tabs, services: services) }
        #else
        // On the Mac a panel is a real window, so Command-W closes it and not the tab behind it.
        .background(WindowReader { services.browserWindow = $0 })
        .onChange(of: services.sheet) { _, sheet in
            guard let sheet else { return }
            openWindow(id: "panel", value: sheet)
            services.sheet = nil
        }
        #endif
    }

    /// Opens links that arrived from Shortcuts or the Share extension.
    private func drain() {
        let links = services.incoming
        guard !links.isEmpty else { return }
        services.incoming = []
        for link in links {
            #if os(macOS)
            if link.destination == .float { FloatController.shared.open(link.url.absoluteString, services: services); continue }
            #endif
            tabs.open(link)
        }
    }
}

/// Bookmarks, History, Settings and the rest: a sheet on iPhone, its own window on the Mac.
struct PanelView: View {
    let sheet: Services.Sheet
    @ObservedObject var tabs: Tabs
    @ObservedObject var services: Services

    var body: some View {
        switch sheet {
        case .bookmarks: BookmarksView(tabs: tabs, library: services.library)
        case .history: HistoryView(tabs: tabs, library: services.library)
        case .settings: SettingsView(settings: services.settings, library: services.library)
        case .siteRules: SiteRulesView(page: tabs.page, sites: services.sites)
        case .reading: ReadingListView(tabs: tabs, services: services)
        case .downloads: DownloadsView(downloads: services.downloads)
        case .tabs: TabGrid(tabs: tabs)
        }
    }
}

#if os(macOS)
/// Hands back the NSWindow a view lives in.
struct WindowReader: NSViewRepresentable {
    let found: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { if let window = view.window { found(window) } }
    }
}
#endif

struct PageView: View {
    @ObservedObject var tabs: Tabs
    @ObservedObject var page: Page
    @ObservedObject var services: Services
    @ObservedObject private var library: Library
    @ObservedObject private var settings: Settings
    @FocusState private var editing: Bool

    init(tabs: Tabs, page: Page, services: Services) {
        self.tabs = tabs
        self.page = page
        self.services = services
        _library = ObservedObject(wrappedValue: services.library)
        _settings = ObservedObject(wrappedValue: services.settings)
    }

    private var bookmarked: Bool { library.isBookmarked(page.address) }

    var body: some View {
        VStack(spacing: 0) {
            chrome
            if tabs.pages.count > 1 { TabStrip(tabs: tabs) }
            if services.finding { FindBar(page: page, isShowing: $services.finding) }
            if editing, !page.address.isEmpty, page.address != page.web.url?.absoluteString {
                Suggestions(query: page.address, library: library, engine: settings.engine) { url in
                    page.go(url)
                    editing = false
                }
            }
            if let error = page.errorMessage {
                Text(error).font(.callout).padding().accessibilityLabel("Page error: " + error)
            }
            // A tab that has not loaded anything shows the start page instead of an empty web view.
            if page.web.url == nil, page.errorMessage == nil {
                StartView(page: page, services: services)
            } else {
                WebView(web: page.web).ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle(page.title)
        .confirmationDialog("Close every tab and clear history, cookies and site data?", isPresented: $services.confirmBurn,
                            titleVisibility: .visible) {
            Button("Close Tabs and Clear Data", role: .destructive) { Task { await tabs.burn() } }
        } message: {
            Text("Bookmarks, the reading list and site rules stay.")
        }
        .onChange(of: services.addressFocusTick) { _, _ in editing = true }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // Like every browser: tapping the address selects all of it, so typing replaces it.
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
            guard let field = note.object as? UITextField else { return }
            DispatchQueue.main.async { field.selectAll(nil) }
        }
        #endif
    }

    private var chrome: some View {
        HStack(spacing: 8) {
            Button { page.web.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!page.canBack).keyboardShortcut("[", modifiers: .command)
                .accessibilityLabel("Back")
            Button { page.web.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!page.canForward).keyboardShortcut("]", modifiers: .command)
                .accessibilityLabel("Forward")
            addressField
            Button { if page.loading { page.web.stopLoading() } else { page.web.reload() } } label: {
                Image(systemName: page.loading ? "xmark" : "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityLabel(page.loading ? "Stop" : "Reload")
            Button {
                library.toggleBookmark(title: page.title, url: page.address)
            } label: {
                Image(systemName: bookmarked ? "star.fill" : "star").foregroundStyle(bookmarked ? .yellow : .primary)
            }
            .disabled(page.address.isEmpty)
            .accessibilityLabel(bookmarked ? "Remove bookmark" : "Add bookmark")
            DownloadsButton(downloads: services.downloads) { services.sheet = .downloads }
            #if os(iOS)
            Button { services.sheet = .tabs } label: { Image(systemName: "square.on.square") }
                .accessibilityLabel("Show all tabs, \(tabs.pages.count) open")
            #endif
            menu
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10).padding(.vertical, 6)
        #if os(macOS)
        .padding(.leading, 70).frame(height: 40)
        #endif
        .background(page.isPrivate ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.bar))
    }

    private var addressField: some View {
        HStack(spacing: 6) {
            Image(systemName: addressIcon).foregroundStyle(.secondary).font(.footnote)
                .accessibilityLabel(page.secure ? "Secure connection" : "Address")
            TextField(page.isPrivate ? "Private tab: search or enter address" : "Search \(settings.engine.name) or enter address",
                      text: $page.address)
                .textFieldStyle(.plain)
                .focused($editing)
                .onSubmit { page.go(page.address); editing = false }
                #if os(iOS)
                .keyboardType(.webSearch).textInputAutocapitalization(.never).autocorrectionDisabled()
                #endif
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(services.agentActive && !page.isPrivate ? AnyShapeStyle(Color.accentColor.opacity(0.22)) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var addressIcon: String {
        if page.isPrivate { return "eyeglasses" }
        if services.agentActive { return "sparkles" }
        if page.secure { return "lock.fill" }
        if page.address.hasPrefix("http://") { return "exclamationmark.triangle" }
        return "magnifyingglass"
    }

    private var menu: some View {
        Menu {
            Button { tabs.add() } label: { Label("New Tab", systemImage: "plus") }
            Button { tabs.add(isPrivate: true) } label: { Label("New Private Tab", systemImage: "eyeglasses") }
            Button { tabs.close(page) } label: { Label("Close Tab", systemImage: "xmark.square") }
                .disabled(tabs.pages.count == 1)
            Divider()
            Button { services.finding = true } label: { Label("Find in Page", systemImage: "magnifyingglass") }
            Button { services.saveForLater(page) } label: {
                Label(library.isSaved(page.address) ? "Saved for Later" : "Save for Later", systemImage: "text.book.closed")
            }
            .disabled(page.web.url == nil)
            Toggle(isOn: $settings.blockTrackers) { Label("Block Trackers and Ads", systemImage: "shield") }
            Button { services.sheet = .siteRules } label: { Label("Site Rules", systemImage: "slider.horizontal.3") }
                .disabled(SiteKey.key(for: page.web.url) == nil)
            #if os(iOS)
            Button { tabs.startPair() } label: { Label("Pair: Two Pages at Once", systemImage: "rectangle.split.2x1") }
            #else
            Button { FloatController.shared.open(page.address, services: services) } label: {
                Label("Float This Page", systemImage: "pip")
            }
            .disabled(page.address.isEmpty)
            #endif
            if let url = page.web.url {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                Button { openExternally(url) } label: { Label("Open in Default Browser", systemImage: "safari") }
            }
            Divider()
            Button { services.sheet = .reading } label: { Label("Reading List", systemImage: "text.book.closed") }
            Button { services.sheet = .bookmarks } label: { Label("Bookmarks", systemImage: "star") }
            Button { services.sheet = .history } label: { Label("History", systemImage: "clock") }
            Button(role: .destructive) { services.confirmBurn = true } label: { Label("Close Tabs and Clear Data", systemImage: "flame") }
            Button { services.sheet = .downloads } label: { Label("Downloads", systemImage: "arrow.down.circle") }
            Button { services.sheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
        .accessibilityLabel("More")
    }
}

/// Matches from your bookmarks and history under the address bar, plus a plain search for what you typed.
struct Suggestions: View {
    let query: String
    @ObservedObject var library: Library
    let engine: SearchEngine
    let pick: (String) -> Void

    var body: some View {
        let hits = library.suggestions(for: query)
        VStack(alignment: .leading, spacing: 0) {
            row("magnifyingglass", "Search \(engine.name) for \u{201C}\(query)\u{201D}", nil) { pick(query) }
            ForEach(hits, id: \.url) { b in
                row(library.isBookmarked(b.url) ? "star" : "clock", b.title, siteName(b.url)) { pick(b.url) }
            }
        }
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func row(_ symbol: String, _ title: String, _ detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 20)
                Text(title).lineLimit(1)
                if let detail { Text(detail).foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TabStrip: View {
    @ObservedObject var tabs: Tabs
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabs.pages) { p in TabChip(tabs: tabs, page: p) }
            }.padding(.horizontal, 8).padding(.vertical, 6)
        }
        .background(.bar)
    }
}

struct TabChip: View {
    @ObservedObject var tabs: Tabs
    @ObservedObject var page: Page
    @ObservedObject private var icons = Services.shared.icons
    var body: some View {
        Button { tabs.current = page.id } label: {
            HStack(spacing: 4) {
                if page.isPrivate {
                    Image(systemName: "eyeglasses").font(.caption)
                } else if let icon = icons.icon(for: page.address) {
                    icon.resizable().interpolation(.high).frame(width: 14, height: 14).clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(page.title.isEmpty ? "New Tab" : page.title).lineLimit(1).frame(maxWidth: 160)
                if tabs.pages.count > 1 {
                    Button { tabs.close(page) } label: { Image(systemName: "xmark").font(.caption2.weight(.semibold)) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Close " + page.title)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(tabs.current == page.id ? Color.accentColor.opacity(0.18) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((page.isPrivate ? "Private tab, " : "Tab, ") + page.title)
    }
}

struct FindBar: View {
    @ObservedObject var page: Page
    @Binding var isShowing: Bool
    @State private var text = ""
    @State private var found: Bool?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find in page", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { run(backwards: false) }
                #if os(iOS)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                #endif
            if found == false { Text("Not found").font(.footnote).foregroundStyle(.secondary) }
            Button { run(backwards: true) } label: { Image(systemName: "chevron.up") }
                .accessibilityLabel("Previous match")
            Button { run(backwards: false) } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Next match")
            Button("Done") { isShowing = false }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.bar)
        .onAppear { focused = true }
    }

    private func run(backwards: Bool) {
        guard !text.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = backwards
        config.wraps = true
        config.caseSensitive = false
        Task { found = (try? await page.web.find(text, configuration: config))?.matchFound }
    }
}
