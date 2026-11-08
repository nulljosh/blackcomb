import SwiftUI
import WebKit

struct BookmarksView: View {
    @ObservedObject var tabs: Tabs
    @ObservedObject var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var filter = ""

    private var items: [Bookmark] {
        filter.isEmpty ? library.bookmarks
            : library.bookmarks.filter { $0.title.localizedCaseInsensitiveContains(filter) || $0.url.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { b in
                    Button { tabs.page.go(b.url); dismiss() } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.title).lineLimit(1)
                            Text(b.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Delete", role: .destructive) { library.removeBookmarks([b]) } }
                }
                .onDelete { offsets in library.removeBookmarks(offsets.map { items[$0] }) }
            }
            .overlay {
                if library.bookmarks.isEmpty {
                    ContentUnavailableView("No bookmarks yet", systemImage: "star",
                                           description: Text("Tap the star in the address bar to save a page."))
                }
            }
            .searchable(text: $filter)
            .navigationTitle("Bookmarks")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 500)
        #endif
    }
}

struct HistoryView: View {
    @ObservedObject var tabs: Tabs
    @ObservedObject var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var filter = ""
    @State private var confirmClear = false

    private var items: [HistoryItem] {
        filter.isEmpty ? library.history
            : library.history.filter { $0.title.localizedCaseInsensitiveContains(filter) || $0.url.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { h in
                    Button { tabs.page.go(h.url); dismiss() } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.title).lineLimit(1)
                            HStack {
                                Text(h.url).lineLimit(1)
                                Spacer()
                                Text(h.visited, format: .relative(presentation: .named))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in library.removeHistory(offsets.map { items[$0] }) }
            }
            .overlay {
                if library.history.isEmpty {
                    ContentUnavailableView("No history", systemImage: "clock",
                                           description: Text("Pages you visit show up here. Private tabs are never recorded."))
                }
            }
            .searchable(text: $filter)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { confirmClear = true }.disabled(library.history.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Clear all browsing history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { library.clearHistory() }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 500)
        #endif
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var cleared = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Search engine", selection: $settings.engine) {
                        ForEach(SearchEngine.allCases) { Text($0.name).tag($0) }
                    }
                    LabeledContent("Homepage") {
                        TextField("Start page", text: $settings.homepage)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            #endif
                    }
                    Picker("New tabs open", selection: $settings.homepage) {
                        Text("Start page").tag("")
                        Text("Google").tag("https://www.google.com/")
                        if !["", "https://www.google.com/"].contains(settings.homepage) {
                            Text("Homepage above").tag(settings.homepage)
                        }
                    }
                } header: {
                    Text("Search")
                } footer: {
                    Text("Leave the homepage empty and new tabs open the start page: search, reading list, bookmarks and recent pages.")
                }
                Section {
                    Toggle("Block trackers and ads", isOn: $settings.blockTrackers)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Blocks third-party requests to well-known ad and tracking hosts. Private tabs also keep no history, cookies or cache.")
                }
                #if os(macOS)
                AutomationSection(settings: settings)
                #endif
                Section("Data") {
                    Button("Clear History") { library.clearHistory() }.disabled(library.history.isEmpty)
                    Button(cleared ? "Website Data Cleared" : "Clear Cookies and Website Data") {
                        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                                                modifiedSince: .distantPast) { cleared = true }
                    }
                    .disabled(cleared)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 440)
        #endif
    }
}
