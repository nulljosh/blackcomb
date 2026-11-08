import SwiftUI
import WebKit
#if os(macOS)
import AppKit
#endif

/// One file the browser is saving or has saved. The list lasts while the app runs; the files stay where they landed.
@MainActor
final class DownloadItem: ObservableObject, Identifiable {
    enum State: Equatable { case running, done, failed(String) }

    let id = UUID()
    @Published var name: String
    @Published var file: URL?
    @Published var progress: Double = 0
    @Published var state: State = .running
    let download: WKDownload?
    private var watch: NSKeyValueObservation?

    init(name: String, download: WKDownload?) {
        self.name = name
        self.download = download
        watch = download?.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            let value = p.fractionCompleted
            Task { @MainActor in self?.progress = value }
        }
    }
}

/// Saves what a page cannot show (or what a link marks as a download): the Mac's Downloads folder,
/// or the app's own folder on iPhone and iPad, which the Files app shows.
@MainActor
final class Downloads: NSObject, ObservableObject, WKDownloadDelegate {
    @Published private(set) var items: [DownloadItem] = []
    let folder: URL

    init(folder: URL = Downloads.defaultFolder) {
        self.folder = folder
    }

    nonisolated static var defaultFolder: URL {
        #if os(macOS)
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        #else
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }

    var active: Bool { items.contains { $0.state == .running } }

    func adopt(_ download: WKDownload) {
        download.delegate = self
        let name = download.originalRequest?.url?.lastPathComponent ?? "Download"
        items.insert(DownloadItem(name: name, download: download), at: 0)
    }

    func clear() { items.removeAll { $0.state != .running } }

    func cancel(_ item: DownloadItem) {
        item.download?.cancel { _ in }
        item.state = .failed("Cancelled")
    }

    private func item(_ d: WKDownload) -> DownloadItem? { items.first { $0.download === d } }

    /// "report.pdf" becomes "report 2.pdf" when the first is taken. Slashes and leading dots are stripped.
    nonisolated static func destination(for suggested: String, in folder: URL) -> URL {
        var name = suggested.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        while name.hasPrefix(".") { name.removeFirst() }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { name = "Download" }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var url = folder.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return url
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String) async -> URL? {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = Self.destination(for: suggestedFilename, in: folder)
        item(download)?.name = url.lastPathComponent
        item(download)?.file = url
        return url
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let item = item(download) else { return }
        item.progress = 1
        item.state = .done
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let item = item(download), item.state == .running else { return }
        item.state = .failed(error.localizedDescription)
    }
}

struct DownloadsView: View {
    @ObservedObject var downloads: Downloads
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(downloads.items) { DownloadRow(item: $0, downloads: downloads) }
                .overlay {
                    if downloads.items.isEmpty {
                        ContentUnavailableView("No downloads", systemImage: "arrow.down.circle",
                                               description: Text("Files you download land in \(folderName)."))
                    }
                }
                .navigationTitle("Downloads")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") { downloads.clear() }.disabled(downloads.items.allSatisfy { $0.state == .running })
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    private var folderName: String {
        #if os(macOS)
        "your Downloads folder"
        #else
        "Files, On My iPhone, Blackcomb"
        #endif
    }
}

private struct DownloadRow: View {
    @ObservedObject var item: DownloadItem
    let downloads: Downloads

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                switch item.state {
                case .running: ProgressView(value: item.progress)
                case .done: Text("Done").font(.caption).foregroundStyle(.secondary)
                case .failed(let why): Text(why).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            if item.state == .running {
                Button { downloads.cancel(item) } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless).accessibilityLabel("Cancel download")
            } else if item.state == .done, let file = item.file {
                #if os(macOS)
                Button { NSWorkspace.shared.activateFileViewerSelecting([file]) } label: { Image(systemName: "magnifyingglass.circle") }
                    .buttonStyle(.borderless).accessibilityLabel("Show in Finder")
                #else
                ShareLink(item: file) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.borderless).accessibilityLabel("Share")
                #endif
            }
        }
        .padding(.vertical, 4)
        #if os(macOS)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if item.state == .done, let file = item.file { NSWorkspace.shared.open(file) } }
        #endif
    }

    private var icon: String {
        switch item.state {
        case .running: "arrow.down.circle"
        case .done: "doc.fill"
        case .failed: "exclamationmark.circle"
        }
    }
}

/// Shows in the browser chrome once something has been downloaded; fills as the active download runs.
struct DownloadsButton: View {
    @ObservedObject var downloads: Downloads
    let action: () -> Void

    var body: some View {
        if !downloads.items.isEmpty {
            Button(action: action) {
                Image(systemName: downloads.active ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .symbolEffect(.pulse, isActive: downloads.active)
            }
            .accessibilityLabel(downloads.active ? "Downloads, in progress" : "Downloads")
        }
    }
}
