import SwiftUI
import WebKit

/// Site icons for Favorites, Recent and tabs. Learned from a page you load (its own icon link, fetched from
/// that same site) and kept as small files on the device. No icon service is ever asked.
@MainActor
final class SiteIcons: ObservableObject {
    @Published private var cache: [String: Image] = [:]
    private var missing = Set<String>()
    private let folder: URL

    init(directory: URL) {
        folder = directory.appendingPathComponent("icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func file(_ key: String) -> URL { folder.appendingPathComponent(key + ".img") }

    /// The icon for a page's site, if one was learned.
    func icon(for address: String) -> Image? {
        guard let key = SiteKey.key(for: URL(string: address)) else { return nil }
        if let hit = cache[key] { return hit }
        guard !missing.contains(key) else { return nil }
        guard let data = try? Data(contentsOf: file(key)), let image = Self.image(data) else {
            missing.insert(key)
            return nil
        }
        DispatchQueue.main.async { self.cache[key] = image }
        return image
    }

    /// The largest bitmap icon the page links to, else /favicon.ico.
    static let linkScript = """
    (() => {
      let best = null, size = -1;
      for (const l of document.querySelectorAll('link[rel~="icon"], link[rel^="apple-touch-icon"]')) {
        if (!l.href || /\\.svg(\\?|$)/i.test(l.href)) continue;
        const s = parseInt(((l.sizes && l.sizes.value) || '').split('x')[0]) || (/apple/.test(l.rel) ? 180 : 16);
        if (s > size) { size = s; best = l.href; }
      }
      return best || (location.origin + '/favicon.ico');
    })()
    """

    /// Called after a normal tab finishes loading. Private tabs never get here.
    func learn(from web: WKWebView) async {
        guard let key = SiteKey.key(for: web.url), cache[key] == nil,
              !FileManager.default.fileExists(atPath: file(key).path) else { return }
        let found = try? await web.evaluateJavaScript(Self.linkScript)
        guard let href = found as? String, let url = URL(string: href), url.scheme == "https",
              let host = SiteKey.key(for: url), Self.sameSite(host, key) else { return }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        request.httpShouldHandleCookies = false
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count < 512_000,
              let image = Self.image(data) else { return }
        try? data.write(to: file(key), options: .atomic)
        missing.remove(key)
        cache[key] = image
    }

    /// The icon must come from the page's own site (or a parent or child of it), never a third party.
    nonisolated static func sameSite(_ a: String, _ b: String) -> Bool {
        a == b || a.hasSuffix("." + b) || b.hasSuffix("." + a)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cache = [:]
        missing = []
    }

    static func image(_ data: Data) -> Image? {
        #if os(macOS)
        NSImage(data: data).flatMap { $0.isValid && $0.size.width >= 8 ? Image(nsImage: $0) : nil }
        #else
        UIImage(data: data).flatMap { $0.size.width >= 8 ? Image(uiImage: $0) : nil }
        #endif
    }
}
