import SwiftUI

/// What a new tab shows before it loads anything: a search field, the reading list, bookmarks,
/// recent pages and the things Blackcomb does beyond showing a page.
struct StartView: View {
    @ObservedObject var page: Page
    @ObservedObject var services: Services
    @ObservedObject private var library: Library
    init(page: Page, services: Services) {
        self.page = page
        self.services = services
        _library = ObservedObject(wrappedValue: services.library)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if !library.saved.isEmpty {
                    section("Reading List", symbol: "text.book.closed") {
                        ForEach(library.saved.prefix(5)) { s in
                            row(s.title, s.url) { services.openSaved = s.id; services.sheet = .reading }
                        }
                    }
                }
                if !library.bookmarks.isEmpty {
                    section("Bookmarks", symbol: "star") {
                        ForEach(library.bookmarks.prefix(8)) { b in row(b.title, b.url) { page.go(b.url) } }
                    }
                }
                if !library.history.isEmpty, !page.isPrivate {
                    section("Recent", symbol: "clock") {
                        ForEach(library.history.prefix(8)) { h in row(h.title, h.url) { page.go(h.url) } }
                    }
                }
                section("Blackcomb", symbol: "mountain.2") {
                    #if os(macOS)
                    hint("pip", "Float", "Keep a page in a small window above every app. Shift-Command-F.")
                    #else
                    hint("rectangle.split.2x1", "Pair", "Two pages in one window, each with its own address bar.")
                    #endif
                    hint("slider.horizontal.3", "Site rules", "Zoom, a dark look and image, script or pop-up blocking per site.")
                    hint("text.book.closed", "Reading list", "Save a page, read it without a connection, or have it read aloud.")
                    hint("shield", "Tracker blocking", "Third-party ad and tracking hosts are blocked by WebKit on the device.")
                }
            }
            .frame(maxWidth: 680, alignment: .leading).padding(24)
            .frame(maxWidth: .infinity)
        }
        // The address bar is the one place to type, so it takes focus here like Safari's start page.
        .onAppear { services.addressFocusTick += 1 }
    }

    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
    }

    private func row(_ title: String, _ url: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lineLimit(1)
                Text(url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func hint(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
