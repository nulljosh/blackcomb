import SwiftUI
import Translation
import WebKit

/// Translate Page: the page's visible text is translated on the device by Apple's Translation framework
/// (the source language is detected, the target is yours) and written back in place. No server is asked.
extension Page {
    /// Collects the visible text nodes, keeps them on window for the write-back, returns their text.
    static let collectTextScript = """
    const skip = new Set(['SCRIPT','STYLE','NOSCRIPT','TEXTAREA','INPUT','CODE','PRE','SVG']);
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        const p = n.parentElement;
        if (!p || skip.has(p.tagName) || p.isContentEditable) return NodeFilter.FILTER_REJECT;
        return /[\\p{L}]{2}/u.test(n.nodeValue) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    });
    const nodes = [];
    while (walker.nextNode() && nodes.length < 600) nodes.push(walker.currentNode);
    window.__blackcombText = nodes;
    return nodes.map(n => n.nodeValue.slice(0, 2000));
    """

    static let applyTextScript = """
    const nodes = window.__blackcombText || [];
    for (const [i, t] of Object.entries(texts)) { if (nodes[+i]) nodes[+i].nodeValue = t; }
    return Object.keys(texts).length;
    """

    func translate(using session: TranslationSession) async {
        do {
            let found = try await web.callAsyncJavaScript(Self.collectTextScript, arguments: [:], in: nil, contentWorld: .defaultClient)
            let texts = found as? [String] ?? []
            guard !texts.isEmpty else { return }
            let requests = texts.enumerated().map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
            var out: [String: String] = [:]
            // Small batches so the page fills in as it goes instead of all at the end.
            for start in stride(from: 0, to: requests.count, by: 60) {
                let batch = Array(requests[start..<min(start + 60, requests.count)])
                for r in try await session.translations(from: batch) {
                    if let id = r.clientIdentifier { out[id] = r.targetText }
                }
                _ = try await web.callAsyncJavaScript(Self.applyTextScript, arguments: ["texts": out], in: nil, contentWorld: .defaultClient)
                out = [:]
            }
        } catch {
            errorMessage = "This page could not be translated on this device."
        }
    }
}

/// Runs a translation when the Translate Page command asks for one. Lives on the page view so the
/// system can show its language download prompt there.
struct TranslateRunner: ViewModifier {
    @ObservedObject var page: Page
    @ObservedObject var services: Services
    @State private var config: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .translationTask(config) { session in await page.translate(using: session) }
            .onChange(of: services.translateTick) { _, _ in
                guard page.web.url != nil else { return }
                if config == nil { config = .init() } else { config?.invalidate() }
            }
    }
}
