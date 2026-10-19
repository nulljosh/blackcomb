#if os(macOS)
import SwiftUI
import Network
import WebKit

// Lets a local agent drive Blackcomb: one HTTP server on 127.0.0.1, off until Settings turns it on.
// REST (`POST /api/<tool>`) and MCP (`POST /mcp`, JSON-RPC) share one tool table, so they cannot drift.
// Private tabs are never listed or touched.

struct HTTPRequest {
    var method: String
    var path: String
    var headers: [String: String]   // lowercased names
    var body: Data

    enum Parse { case needMore, bad, done(HTTPRequest) }

    /// Reads one request from what has arrived so far: headers, then exactly Content-Length bytes of body.
    static func parse(_ data: Data) -> Parse {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else { return data.count > 65_536 ? .bad : .needMore }
        guard let head = String(data: data[data.startIndex..<end.lowerBound], encoding: .utf8) else { return .bad }
        let lines = head.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ")
        guard first.count >= 2 else { return .bad }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let i = line.firstIndex(of: ":") else { continue }
            headers[line[..<i].lowercased()] = line[line.index(after: i)...].trimmingCharacters(in: .whitespaces)
        }
        if headers["transfer-encoding"] != nil { return .bad }
        guard let length = Int(headers["content-length"] ?? "0"), length >= 0, length <= 4_000_000 else { return .bad }
        guard data.endIndex - end.upperBound >= length else { return .needMore }
        let body = Data(data[end.upperBound..<end.upperBound + length])
        return .done(HTTPRequest(method: String(first[0]), path: String(first[1]), headers: headers, body: body))
    }
}

struct HTTPResponse {
    var status: Int
    var body: Data = Data()
    var type = "application/json"

    var wire: Data {
        let reason = [200: "OK", 202: "Accepted", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden",
                      404: "Not Found", 405: "Method Not Allowed"][status] ?? "OK"
        var head = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
        if status == 405 { head += "Allow: POST\r\n" }
        return Data((head + "\r\n").utf8) + body
    }

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, body: (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8))
    }
    static func fail(_ status: Int, _ message: String) -> HTTPResponse { .json(["error": message], status: status) }
}

/// What a tool returns, in MCP's content shape so REST and MCP answer identically.
struct ToolResult {
    var content: [[String: Any]]
    var isError = false

    static func text(_ s: String, error: Bool = false) -> ToolResult { ToolResult(content: [["type": "text", "text": s]], isError: error) }
    static func image(_ png: Data) -> ToolResult {
        ToolResult(content: [["type": "image", "data": png.base64EncodedString(), "mimeType": "image/png"]])
    }
    var object: [String: Any] { ["content": content, "isError": isError] }
}

struct Tool {
    let name: String
    let about: String
    var props: [(name: String, type: String, about: String)] = []
    var required: [String] = []
    /// Most tools act on a tab: the current one unless `tab` names another.
    var tabbed = true

    var schema: [String: Any] {
        var all = props
        if tabbed { all.append(("tab", "string", "Tab id from tabs_list. Defaults to the current tab.")) }
        var properties: [String: Any] = [:]
        for p in all { properties[p.name] = ["type": p.type, "description": p.about] }
        return ["type": "object", "properties": properties, "required": required]
    }
    var listing: [String: Any] { ["name": name, "description": about, "inputSchema": schema] }
}

enum AutomationAPI {
    static let tools: [Tool] = [
        Tool(name: "tabs_list", about: "List the open tabs (id, title, url, which is current). Private tabs are never shown.", tabbed: false),
        Tool(name: "tab_open", about: "Open a new tab, optionally on a url. Becomes the current tab.",
             props: [("url", "string", "http(s) address to open")], tabbed: false),
        Tool(name: "tab_select", about: "Make a tab the current one.", props: [("tab", "string", "Tab id from tabs_list")], required: ["tab"], tabbed: false),
        Tool(name: "tab_close", about: "Close a tab (the last tab cannot be closed).", props: [("tab", "string", "Tab id from tabs_list")], required: ["tab"], tabbed: false),
        Tool(name: "navigate", about: "Load an http(s) url and wait for the page to finish.", props: [("url", "string", "Address to load")], required: ["url"]),
        Tool(name: "back", about: "Go back one page and wait for it to load."),
        Tool(name: "forward", about: "Go forward one page and wait for it to load."),
        Tool(name: "reload", about: "Reload the page and wait for it to load."),
        Tool(name: "read_page", about: "Read the page: url, title, readable text, and the visible links, buttons and fields (use their text with click and type).",
             props: [("max_chars", "number", "Cap on returned text, default 20000")]),
        Tool(name: "click", about: "Click an element by CSS selector, or by its visible text or aria-label.",
             props: [("selector", "string", "CSS selector"), ("text", "string", "Visible text or aria-label of a link, button or tab")]),
        Tool(name: "type", about: "Type into a field found by CSS selector or by its label, placeholder or name; optionally submit its form.",
             props: [("selector", "string", "CSS selector"), ("label", "string", "Label, placeholder, name or id of the field"),
                     ("text", "string", "Text to put in the field"), ("submit", "boolean", "Submit the form afterwards")], required: ["text"]),
        Tool(name: "eval_js", about: "Run JavaScript in the page and return the last expression's value (wrap objects in JSON.stringify; promises are not awaited).",
             props: [("script", "string", "JavaScript source")], required: ["script"]),
        Tool(name: "screenshot", about: "Capture the tab as a PNG, about 1000 points wide."),
    ]

    static let instructions = "Blackcomb is a browser. Open or select a tab, navigate, read_page to see the text and controls, then click and type by visible text. Private tabs are never exposed."

    /// The one door for requests: checks who is asking, then routes REST and MCP. Pure, so tests need no socket.
    @MainActor
    static func respond(_ req: HTTPRequest, token: String, port: UInt16,
                        call: @MainActor (String, [String: Any]) async -> ToolResult) async -> HTTPResponse {
        // A web page (even one open in Blackcomb) can reach localhost: refuse browsers (Origin) and DNS rebinding (Host).
        guard req.headers["origin"] == nil else { return .fail(403, "browser requests are not allowed") }
        guard let host = req.headers["host"], host == "127.0.0.1:\(port)" || host == "localhost:\(port)" else {
            return .fail(403, "bad host")
        }
        let auth = req.headers["authorization"] ?? ""
        guard auth.lowercased().hasPrefix("bearer "), same(String(auth.dropFirst(7)), token) else {
            return .fail(401, "missing or wrong bearer token")
        }
        let path = req.path.split(separator: "?").first.map(String.init) ?? req.path

        if path == "/mcp" {
            guard req.method == "POST" else { return .fail(405, "POST only") }
            return await mcp(req.body, call: call)
        }
        if path == "/api", req.method == "GET" { return .json(["tools": tools.map(\.listing)]) }
        if path.hasPrefix("/api/") {
            guard req.method == "POST" else { return .fail(405, "POST only") }
            let name = String(path.dropFirst(5))
            guard tools.contains(where: { $0.name == name }) else { return .fail(404, "unknown tool") }
            let args: [String: Any]
            if req.body.isEmpty { args = [:] } else if let o = (try? JSONSerialization.jsonObject(with: req.body)) as? [String: Any] { args = o }
            else { return .fail(400, "body must be a JSON object") }
            return .json(await call(name, args).object)
        }
        return .fail(404, "not found")
    }

    @MainActor
    private static func mcp(_ body: Data, call: @MainActor (String, [String: Any]) async -> ToolResult) async -> HTTPResponse {
        guard let parsed = try? JSONSerialization.jsonObject(with: body) else { return .fail(400, "bad JSON") }
        let batch = parsed as? [Any]
        var replies: [[String: Any]] = []
        for item in batch ?? [parsed] {
            guard let msg = item as? [String: Any] else { continue }
            if let reply = await rpc(msg, call: call) { replies.append(reply) }
        }
        if replies.isEmpty { return HTTPResponse(status: 202) }
        return .json(batch != nil ? replies : replies[0])
    }

    /// One JSON-RPC message. Notifications (no id) get no reply.
    @MainActor
    private static func rpc(_ msg: [String: Any], call: @MainActor (String, [String: Any]) async -> ToolResult) async -> [String: Any]? {
        guard let id = msg["id"] else { return nil }
        let params = msg["params"] as? [String: Any] ?? [:]
        func ok(_ result: Any) -> [String: Any] { ["jsonrpc": "2.0", "id": id, "result": result] }
        switch msg["method"] as? String {
        case "initialize":
            return ok(["protocolVersion": params["protocolVersion"] as? String ?? "2025-03-26",
                       "capabilities": ["tools": [String: Any]()],
                       "serverInfo": ["name": "blackcomb", "version": "1.0.0"],
                       "instructions": instructions])
        case "ping": return ok([String: Any]())
        case "tools/list": return ok(["tools": tools.map(\.listing)])
        case "tools/call":
            guard let name = params["name"] as? String, tools.contains(where: { $0.name == name }) else {
                return ok(ToolResult.text("unknown tool", error: true).object)
            }
            return ok(await call(name, params["arguments"] as? [String: Any] ?? [:]).object)
        default:
            return ["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "method not found"]]
        }
    }

    /// Constant-time compare so the token cannot be guessed byte by byte.
    static func same(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<x.count { diff |= x[i] ^ y[i] }
        return diff == 0
    }
}

@MainActor
final class Automation: ObservableObject {
    static let shared = Automation()
    /// BLACKCOMB_AUTOMATION_PORT lets a QA run sit beside the real app.
    static let port: UInt16 = ProcessInfo.processInfo.environment["BLACKCOMB_AUTOMATION_PORT"].flatMap { UInt16($0) } ?? 47329

    @Published private(set) var running = false
    @Published private(set) var problem: String?
    @Published private(set) var token = ""

    private var tabs: Tabs?
    private var services: Services?
    private var listener: NWListener?
    private var quiet = 0

    private var tokenFile: URL { Library.defaultDirectory.appendingPathComponent("automation-token") }

    /// Wires the shared tabs in and starts the server if Settings (or BLACKCOMB_AUTOMATION=1 for QA runs) says so.
    func configure(tabs: Tabs, services: Services) {
        self.tabs = tabs
        self.services = services
        token = loadToken()
        services.settings.onAutomationChange = { [weak self] on in self?.setEnabled(on) }
        setEnabled(services.settings.automation || ProcessInfo.processInfo.environment["BLACKCOMB_AUTOMATION"] == "1")
    }

    var endpoint: String { "http://127.0.0.1:\(Self.port)/mcp" }
    var claudeCommand: String { "claude mcp add --transport http blackcomb \(endpoint) --header \"Authorization: Bearer \(token)\"" }

    func resetToken() {
        try? FileManager.default.removeItem(at: tokenFile)
        token = loadToken()
    }

    private func loadToken() -> String {
        if let t = try? String(contentsOf: tokenFile, encoding: .utf8), t.count >= 32 { return t }
        let t = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        try? FileManager.default.createDirectory(at: tokenFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? t.write(to: tokenFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile.path)
        return t
    }

    func setEnabled(_ on: Bool) {
        listener?.cancel()
        listener = nil
        running = false
        problem = nil
        guard on else { return }
        do {
            let params = NWParameters.tcp
            params.requiredInterfaceType = .loopback
            let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
            l.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready: self?.running = true
                    case .failed(let e): self?.running = false; self?.problem = "Could not listen on port \(Self.port): \(e.localizedDescription)"
                    default: break
                    }
                }
            }
            l.newConnectionHandler = { [weak self] c in
                c.start(queue: .main)
                Task { @MainActor in self?.read(c, Data()) }
            }
            l.start(queue: .main)
            listener = l
        } catch {
            problem = "Could not listen on port \(Self.port): \(error.localizedDescription)"
        }
    }

    private func read(_ c: NWConnection, _ so_far: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, done, error in
            Task { @MainActor in
                guard let self else { return }
                var buf = so_far
                if let data { buf.append(data) }
                switch HTTPRequest.parse(buf) {
                case .needMore:
                    if done || error != nil { c.cancel() } else { self.read(c, buf) }
                case .bad:
                    self.send(c, .fail(400, "bad request"))
                case .done(let req):
                    let res = await AutomationAPI.respond(req, token: self.token, port: Self.port) { name, args in
                        await self.call(name, args)
                    }
                    self.send(c, res)
                }
            }
        }
    }

    private func send(_ c: NWConnection, _ res: HTTPResponse) {
        c.send(content: res.wire, completion: .contentProcessed { _ in c.cancel() })
    }

    // MARK: Tools

    /// Marks the browser as driven (the address bar shows it) until a few quiet seconds pass.
    private func busy() {
        services?.agentActive = true
        quiet += 1
        let mine = quiet
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            if self?.quiet == mine { self?.services?.agentActive = false }
        }
    }

    func call(_ name: String, _ args: [String: Any]) async -> ToolResult {
        busy()
        guard let tabs else { return .text("browser not ready", error: true) }
        do {
            switch name {
            case "tabs_list": return .text(json(tabs.pages.filter { !$0.isPrivate }.map { state($0, tabs) }))
            case "tab_open":
                tabs.add("")
                let page = tabs.page
                if let url = args["url"] as? String {
                    guard let u = web(url) else { return .text("only http(s) addresses can be opened", error: true) }
                    await page.load(u.absoluteString)
                }
                return .text(json(state(page, tabs)))
            case "tab_select":
                guard let p = tab(args, tabs) else { return .text("no such tab", error: true) }
                tabs.current = p.id
                return .text(json(state(p, tabs)))
            case "tab_close":
                guard let p = tab(args, tabs) else { return .text("no such tab", error: true) }
                guard tabs.pages.count > 1 else { return .text("the last tab cannot be closed", error: true) }
                tabs.close(p)
                return .text(json(tabs.pages.filter { !$0.isPrivate }.map { state($0, tabs) }))
            default: break
            }
            guard let page = tab(args, tabs) else {
                return .text("no such tab, or the current tab is private (private tabs are never exposed)", error: true)
            }
            switch name {
            case "navigate":
                guard let u = web(args["url"] as? String ?? "") else { return .text("only http(s) addresses can be opened", error: true) }
                await page.load(u.absoluteString)
                return .text(json(state(page, tabs)))
            case "back", "forward":
                guard name == "back" ? page.canBack : page.canForward else { return .text("nothing to go \(name) to", error: true) }
                await page.perform {
                    if name == "back" { _ = page.web.goBack() } else { _ = page.web.goForward() }
                }
                return .text(json(state(page, tabs)))
            case "reload":
                await page.perform { _ = page.web.reload() }
                return .text(json(state(page, tabs)))
            case "read_page":
                let cap = (args["max_chars"] as? Int) ?? 20_000
                let text = (try await page.web.evaluateJavaScript(Page.textScript) as? String) ?? ""
                let elements = try await page.web.callAsyncJavaScript(Self.elementsScript, arguments: [:], in: nil, contentWorld: .page)
                var out = state(page, tabs)
                out["text"] = String(text.prefix(cap))
                out["truncated"] = text.count > cap
                out["elements"] = elements ?? []
                return .text(json(out))
            case "click":
                let found = try await page.web.callAsyncJavaScript(Self.clickScript, arguments: [
                    "sel": args["selector"] as? String ?? "", "text": args["text"] as? String ?? "",
                ], in: nil, contentWorld: .page)
                await settle(page)
                return .text(render(found), error: (found as? String) == "not found")
            case "type":
                let found = try await page.web.callAsyncJavaScript(Self.typeScript, arguments: [
                    "sel": args["selector"] as? String ?? "", "label": args["label"] as? String ?? "",
                    "text": args["text"] as? String ?? "", "submit": args["submit"] as? Bool ?? false,
                ], in: nil, contentWorld: .page)
                if args["submit"] as? Bool == true { await settle(page) }
                return .text(render(found), error: (found as? String) == "not found")
            case "eval_js":
                let value = try await page.web.evaluateJavaScript(args["script"] as? String ?? "")
                return .text(render(value))
            case "screenshot":
                // A tab with no window (background tab, hidden app) has no size: give it one so it can paint.
                if page.web.bounds.isEmpty { page.web.frame = CGRect(x: 0, y: 0, width: 1100, height: 760) }
                let config = WKSnapshotConfiguration()
                config.snapshotWidth = 1000
                let image = try await page.web.takeSnapshot(configuration: config)
                var rect = CGRect(origin: .zero, size: image.size)
                guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
                      let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                    return .text("could not capture the page (size \(Int(image.size.width))x\(Int(image.size.height)))", error: true)
                }
                return .image(png)
            default:
                return .text("unknown tool", error: true)
            }
        } catch {
            return .text(error.localizedDescription, error: true)
        }
    }

    /// The tab a call means: `tab` by id, else the current one. Private tabs are refused.
    private func tab(_ args: [String: Any], _ tabs: Tabs) -> Page? {
        let page = (args["tab"] as? String).flatMap { id in tabs.pages.first { $0.id.uuidString == id } } ?? (args["tab"] == nil ? tabs.page : nil)
        return page?.isPrivate == false ? page : nil
    }

    private func web(_ s: String) -> URL? {
        guard let u = resolve(s, engine: services?.settings.engine ?? .google), ["http", "https"].contains(u.scheme?.lowercased()) else { return nil }
        return u
    }

    private func state(_ p: Page, _ tabs: Tabs) -> [String: Any] {
        var s: [String: Any] = ["id": p.id.uuidString, "title": p.title, "url": p.address, "current": p.id == tabs.current, "loading": p.loading]
        if let e = p.errorMessage { s["error"] = e }
        return s
    }

    /// A click may start a navigation: give it a moment, then wait for the load.
    private func settle(_ page: Page) async {
        try? await Task.sleep(for: .milliseconds(300))
        if page.web.isLoading { await page.perform {} }
    }

    private func json(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }

    private func render(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "null" }
        if let s = value as? String { return s }
        if JSONSerialization.isValidJSONObject([value]), let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) {
            return String(decoding: data, as: UTF8.self)
        }
        return String(describing: value)
    }

    static let elementsScript = #"""
    const visible = e => { const r = e.getBoundingClientRect(), s = getComputedStyle(e); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none'; };
    const name = e => (e.getAttribute('aria-label') || e.innerText || e.value || e.placeholder || e.title || e.alt || '').trim().replace(/\s+/g, ' ').slice(0, 80);
    const out = [];
    document.querySelectorAll('a[href], button, input:not([type=hidden]), textarea, select, [role=button], [role=link], [role=tab], summary').forEach(e => {
      if (out.length >= 80 || !visible(e)) return;
      const secret = e.type === 'password';
      out.push({ tag: e.tagName.toLowerCase(), type: e.type || null, text: secret ? '' : name(e), href: e.href || null, name: e.name || null, id: e.id || null,
                 value: e.tagName === 'INPUT' && !secret ? (e.value || null) : null });
    });
    return out;
    """#

    static let clickScript = #"""
    let el = null;
    if (sel) el = document.querySelector(sel);
    else if (text) {
      const t = text.toLowerCase();
      const all = [...document.querySelectorAll('a, button, input[type=submit], input[type=button], [role=button], [role=link], [role=tab], summary, label')];
      const name = e => (e.getAttribute('aria-label') || e.innerText || e.value || '').trim().toLowerCase();
      el = all.find(e => name(e) === t) || all.find(e => name(e).includes(t));
    }
    if (!el) return 'not found';
    el.scrollIntoView({ block: 'center' });
    el.click();
    return 'clicked ' + el.tagName.toLowerCase();
    """#

    static let typeScript = #"""
    let el = sel ? document.querySelector(sel) : null;
    if (!el && label) {
      const l = label.toLowerCase();
      el = [...document.querySelectorAll('input:not([type=hidden]), textarea, select, [contenteditable=true]')].find(e =>
        [e.getAttribute('aria-label'), e.placeholder, e.name, e.id, e.labels && e.labels[0] && e.labels[0].innerText].some(v => v && v.toLowerCase().includes(l)));
    }
    if (!el) return 'not found';
    el.focus();
    if (el.isContentEditable) el.textContent = text;
    else {
      const proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : el.tagName === 'SELECT' ? HTMLSelectElement.prototype : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, text);
    }
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    if (submit) {
      if (el.form && el.form.requestSubmit) el.form.requestSubmit();
      else el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    }
    return 'typed';
    """#
}

/// The Settings section: the switch, what it does, and the one command that connects Claude Code.
struct AutomationSection: View {
    @ObservedObject var settings: Settings
    @ObservedObject private var automation = Automation.shared
    @State private var copied: String?

    var body: some View {
        Section {
            Toggle("Let AI agents and apps control Blackcomb", isOn: $settings.automation)
            if settings.automation {
                LabeledContent("Endpoint", value: automation.endpoint).textSelection(.enabled)
                Button(copied == "cmd" ? "Copied" : "Copy Claude Code Command") { copy(automation.claudeCommand, "cmd") }
                Button(copied == "token" ? "Copied" : "Copy Token") { copy(automation.token, "token") }
                Button("Make a New Token") { automation.resetToken() }
                if let problem = automation.problem { Text(problem).foregroundStyle(.red) }
                else if !automation.running { Text("Starting…").foregroundStyle(.secondary) }
            }
        } header: {
            Text("Automation")
        } footer: {
            Text("Off by default. It listens on this Mac only (127.0.0.1) and every request needs the token. An agent can read, click and type in your normal tabs; private tabs are never shown to it. The address bar glows while an agent is driving.")
        }
    }

    private func copy(_ s: String, _ what: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        copied = what
    }
}
#endif
