import SwiftUI

/// "www.Apple.com" becomes "apple.com"; an address with no host comes back as it was.
func siteName(_ address: String) -> String {
    URL(string: address)?.host().map(SiteKey.normalise) ?? address
}

extension SavedPage {
    var host: String { siteName(url) }

    /// The first lines of the saved text, joined, for the card on the start page.
    var snippet: String {
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let body = lines.first == title ? Array(lines.dropFirst()) : lines
        return String(body.joined(separator: " ").prefix(160))
    }
}

/// What a new tab shows before it loads anything: your reading list, favorites and recent sites,
/// like Safari's start page. A fresh install, with nothing saved yet, lists what the app does.
struct StartView: View {
    @ObservedObject var page: Page
    @ObservedObject var services: Services
    @ObservedObject private var library: Library

    private let tileColumns = [GridItem(.adaptive(minimum: 88, maximum: 104), spacing: 16, alignment: .top)]
    private let cardColumns = [GridItem(.adaptive(minimum: 200), spacing: 16, alignment: .top)]

    init(page: Page, services: Services) {
        self.page = page
        self.services = services
        _library = ObservedObject(wrappedValue: services.library)
    }

    /// One tile per site, newest first.
    private var recent: [HistoryItem] {
        var seen = Set<String>()
        return library.history.filter { seen.insert(siteName($0.url)).inserted }.prefix(8).map { $0 }
    }

    private var isEmpty: Bool { library.saved.isEmpty && library.bookmarks.isEmpty && library.history.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if page.isPrivate {
                    section("Private Tab") {
                        Text("Pages you open here are not saved: no history, no cookies, no cache. Close the tab and they are gone.")
                            .foregroundStyle(.secondary)
                    }
                }
                if !library.saved.isEmpty {
                    section("Reading List") {
                        LazyVGrid(columns: cardColumns, spacing: 16) {
                            ForEach(library.saved.prefix(4)) { s in
                                Button { services.openSaved = s.id; services.sheet = .reading } label: { card(s) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if !library.bookmarks.isEmpty {
                    section("Favorites") {
                        LazyVGrid(columns: tileColumns, spacing: 16) {
                            ForEach(library.bookmarks.prefix(12)) { b in
                                Tile(title: b.title, address: b.url) { page.go(b.url) }
                            }
                        }
                    }
                }
                if !recent.isEmpty, !page.isPrivate {
                    section("Recent") {
                        LazyVGrid(columns: tileColumns, spacing: 16) {
                            ForEach(recent) { h in
                                Tile(title: siteName(h.url), address: h.url) { page.go(h.url) }
                            }
                        }
                    }
                }
                if isEmpty, !page.isPrivate {
                    section("Welcome to Blackcomb") {
                        VStack(alignment: .leading, spacing: 16) {
                            #if os(macOS)
                            hint("pip", "Float", "Keep a page in a small window above every app. Shift-Command-F.")
                            #else
                            hint("rectangle.split.2x1", "Pair", "Two pages in one window, each with its own address bar.")
                            #endif
                            hint("text.book.closed", "Reading list", "Save a page, read it without a connection, or have it read aloud.")
                            hint("slider.horizontal.3", "Site rules", "Zoom, a dark look and image, script or pop-up blocking per site.")
                            hint("shield", "Tracker blocking", "Third-party ad and tracking hosts are blocked by WebKit on the device.")
                        }
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading).padding(24)
            .frame(maxWidth: .infinity)
        }
        // The address bar is the one place to type, so it takes focus here like Safari's start page.
        .onAppear { services.addressFocusTick += 1 }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title3.bold())
            content()
        }
    }

    private func card(_ s: SavedPage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(s.snippet).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            Spacer(minLength: 0)
            Text(s.host).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
        }
        .multilineTextAlignment(.leading)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func hint(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

/// A site as a rounded square with its first letter, like a favorite on Safari's start page.
/// Drawn on the device: no site is contacted to fetch an icon.
private struct Tile: View {
    let title: String
    let address: String
    let action: () -> Void

    private var letter: String {
        siteName(address).first(where: { $0.isLetter || $0.isNumber }).map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor.opacity(0.14))
                    Text(letter).font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.accentColor)
                }
                .frame(width: 60, height: 60)
                Text(title).font(.caption).lineLimit(1).frame(maxWidth: 88)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
