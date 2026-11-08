import SwiftUI
import WebKit

/// Every open tab as a card with a picture of its page, searchable. Tap one to go to it.
struct TabGrid: View {
    @ObservedObject var tabs: Tabs
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var shots: [UUID: Image] = [:]

    private var shown: [Page] {
        guard !query.isEmpty else { return tabs.pages }
        return tabs.pages.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.address.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(shown) { card($0) }
                }
                .padding(16)
            }
            .overlay {
                if shown.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, prompt: "Search tabs")
            .navigationTitle(tabs.pages.count == 1 ? "1 Tab" : "\(tabs.pages.count) Tabs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { tabs.add(); dismiss() } label: { Image(systemName: "plus") }.accessibilityLabel("New Tab")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task {
                // Pages still loading get pictured again once they settle (restored tabs load at launch).
                var pending = tabs.pages.filter { $0.web.url != nil }
                for _ in 0..<5 where !pending.isEmpty {
                    for p in pending {
                        if let image = await Self.snapshot(p.web) { shots[p.id] = image }
                    }
                    pending = pending.filter(\.loading)
                    try? await Task.sleep(for: .seconds(1.5))
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 480)
        #endif
    }

    private func card(_ p: Page) -> some View {
        let selected = p.id == tabs.current
        return Button {
            tabs.current = p.id
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // The card sets the size; the picture fills it from the top and is cut to it.
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.quaternary)
                    .frame(maxWidth: .infinity).frame(height: 200)
                    .overlay(alignment: .top) {
                        if let shot = shots[p.id] {
                            shot.resizable().aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                        } else {
                            Image(systemName: p.isPrivate ? "eyeglasses" : "safari").font(.largeTitle).foregroundStyle(.secondary)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .overlay(alignment: .topTrailing) {
                    if tabs.pages.count > 1 {
                        Button { tabs.close(p) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .buttonStyle(.plain).padding(8)
                        .accessibilityLabel("Close " + (p.title.isEmpty ? "New Tab" : p.title))
                    }
                }
                Text(p.title.isEmpty ? "New Tab" : p.title).font(.caption).lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((p.isPrivate ? "Private tab, " : "Tab, ") + (p.title.isEmpty ? "New Tab" : p.title))
    }

    /// A tab with no window has no size, so it gets one before WebKit paints it.
    @MainActor static func snapshot(_ web: WKWebView) async -> Image? {
        if web.bounds.isEmpty { web.frame = CGRect(x: 0, y: 0, width: 390, height: 844) }
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 300
        guard let image = try? await web.takeSnapshot(configuration: config) else { return nil }
        #if os(macOS)
        return Image(nsImage: image)
        #else
        return Image(uiImage: image)
        #endif
    }
}
