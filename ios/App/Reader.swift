import SwiftUI
import AVFoundation

extension Page {
    /// The readable text of the open page: headings, paragraphs and list items from the article
    /// (or main region, or body), skipping navigation, headers, footers, sidebars and forms.
    /// Short results fall back to the whole region's text so a plain page still reads.
    static let textScript = """
    (function () {
      var root = document.querySelector('article, main, [role=main]') || document.body;
      if (!root) return '';
      var blocks = 'h1, h2, h3, h4, p, li, blockquote, pre, figcaption';
      var skip = 'nav, header, footer, aside, form, [role=navigation], [aria-hidden=true]';
      var parts = [];
      root.querySelectorAll(blocks).forEach(function (e) {
        if (e.closest(skip) || e.querySelector(blocks)) return;
        var t = e.innerText.trim();
        if (t) parts.push(t);
      });
      var text = parts.join('\\n\\n');
      return text.length >= 200 ? text : root.innerText.trim();
    })()
    """

    /// Nil when nothing is loaded or the page has no text.
    func pageText() async -> String? {
        guard web.url != nil else { return nil }
        let text = try? await web.evaluateJavaScript(Page.textScript) as? String
        return text?.isEmpty == false ? text : nil
    }
}

extension Services {
    /// Keeps the open page's title, address and text on the device for the reading list.
    func saveForLater(_ page: Page) {
        Task {
            guard let text = await page.pageText() else { return }
            library.savePage(title: page.title, url: page.address, text: text)
        }
    }
}

/// Reads saved text aloud with the system voice.
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speaking = false
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func toggle(_ text: String) { speaking ? stop() : start(text) }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speaking = false
    }

    private func start(_ text: String) {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        synth.speak(AVSpeechUtterance(string: text))
        speaking = true
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in speaking = false }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in speaking = false }
    }
}

struct ReadingListView: View {
    @ObservedObject var tabs: Tabs
    @ObservedObject var services: Services
    @ObservedObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var path: [SavedPage] = []

    init(tabs: Tabs, services: Services) {
        self.tabs = tabs
        self.services = services
        _library = ObservedObject(wrappedValue: services.library)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(library.saved) { s in
                    NavigationLink(value: s) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).lineLimit(1)
                            HStack {
                                Text(s.url).lineLimit(1)
                                Spacer()
                                Text(s.saved, format: .relative(presentation: .named))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu { Button("Delete", role: .destructive) { library.removeSaved([s]) } }
                }
                .onDelete { offsets in library.removeSaved(offsets.map { library.saved[$0] }) }
            }
            .overlay {
                if library.saved.isEmpty {
                    ContentUnavailableView("Nothing saved yet", systemImage: "text.book.closed",
                                           description: Text("Choose Save for Later on a page. Its text stays on this device and reads without a connection."))
                }
            }
            .navigationTitle("Reading List")
            .navigationDestination(for: SavedPage.self) { ReaderView(saved: $0, tabs: tabs, services: services) }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear {
            if let id = services.openSaved, let s = library.saved.first(where: { $0.id == id }) { path = [s] }
            services.openSaved = nil
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 560)
        #endif
    }
}

struct ReaderView: View {
    let saved: SavedPage
    @ObservedObject var tabs: Tabs
    @ObservedObject var services: Services
    @AppStorage("readerSize") private var size = 18.0
    @StateObject private var speaker = Speaker()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(saved.title).font(.title.bold())
                Text(saved.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(saved.text).font(.system(size: size)).lineSpacing(size * 0.35).textSelection(.enabled)
            }
            .frame(maxWidth: 680, alignment: .leading).padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(saved.title)
        .toolbar {
            ToolbarItemGroup {
                Button { size = max(14, size - 2) } label: { Image(systemName: "textformat.size.smaller") }
                    .accessibilityLabel("Smaller text")
                Button { size = min(30, size + 2) } label: { Image(systemName: "textformat.size.larger") }
                    .accessibilityLabel("Larger text")
                Button { speaker.toggle(saved.text) } label: { Image(systemName: speaker.speaking ? "stop.fill" : "speaker.wave.2") }
                    .accessibilityLabel(speaker.speaking ? "Stop reading aloud" : "Read aloud")
                Button { tabs.page.go(saved.url); services.sheet = nil } label: { Image(systemName: "safari") }
                    .accessibilityLabel("Open the page")
            }
        }
        .onDisappear { speaker.stop() }
    }
}
