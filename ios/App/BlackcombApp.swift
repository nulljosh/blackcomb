import SwiftUI

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
#endif

@main
struct BlackcombApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var services: Services
    @StateObject private var tabs: Tabs
    #if os(macOS)
    @ObservedObject private var floating = FloatController.shared
    #endif

    init() {
        let services = Services.shared
        _services = StateObject(wrappedValue: services)
        let tabs = Tabs(services: services, restore: true, defaults: services.defaults)
        _tabs = StateObject(wrappedValue: tabs)
        #if os(macOS)
        Automation.shared.configure(tabs: tabs, services: services)
        #endif
    }

    var body: some Scene {
        WindowGroup { BrowserView(tabs: tabs, services: services) }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        // The address bar sits in the title bar row beside the window buttons, like Safari's compact tabs.
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { tabs.add() }.keyboardShortcut("t")
                Button("New Private Tab") { tabs.add(isPrivate: true) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Reopen Closed Tab") { tabs.reopenClosed() }.keyboardShortcut("t", modifiers: [.command, .shift])
                    .disabled(tabs.closed.isEmpty)
                #if os(macOS)
                // Command-W closes the front window unless that is the browser with tabs to spare.
                Button("Close") {
                    guard let front = NSApp.keyWindow else { return }
                    if front === services.browserWindow, tabs.pages.count > 1 { tabs.close(tabs.page) } else { front.performClose(nil) }
                }
                .keyboardShortcut("w")
                #else
                Button("Close Tab") { tabs.close(tabs.page) }.keyboardShortcut("w").disabled(tabs.pages.count == 1)
                #endif
            }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { tabs.page.zoom(by: 0.1) }.keyboardShortcut("=")
                Button("Zoom Out") { tabs.page.zoom(by: -0.1) }.keyboardShortcut("-")
                Button("Actual Size") { tabs.page.zoom(by: nil) }.keyboardShortcut("0")
                Divider()
                Button("Show All Tabs") { services.sheet = .tabs }.keyboardShortcut("\\", modifiers: [.command, .shift])
                Button("Show Next Tab") { tabs.cycle(1) }.keyboardShortcut(.tab, modifiers: .control)
                Button("Show Previous Tab") { tabs.cycle(-1) }.keyboardShortcut(.tab, modifiers: [.control, .shift])
                ForEach(1..<10) { n in
                    Button(n == 9 ? "Show Last Tab" : "Show Tab \(n)") { tabs.select(number: n) }
                        .keyboardShortcut(KeyEquivalent(Character(String(n))))
                }
                Divider()
            }
            #if os(macOS)
            CommandGroup(after: .toolbar) {
                Button("Float Current Tab") { floating.open(tabs.page.address, services: services) }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(tabs.page.address.isEmpty)
                Button(floating.clickThrough ? "Turn Float Click-Through Off" : "Turn Float Click-Through On") {
                    floating.toggleClickThrough()
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(!floating.isOpen)
                Button("Close Float Window") { floating.close() }
                    .keyboardShortcut("f", modifiers: [.command, .control])
                    .disabled(!floating.isOpen)
            }
            #endif
            CommandGroup(after: .textEditing) {
                Button("Find in Page") { services.finding = true }.keyboardShortcut("f")
                Button("Translate Page") { services.translateTick += 1 }.keyboardShortcut("t", modifiers: [.command, .control])
                Button("Open Location") { services.addressFocusTick += 1 }.keyboardShortcut("l")
            }
            CommandMenu("Site") {
                Button("Site Rules…") { services.sheet = .siteRules }.keyboardShortcut("s", modifiers: [.command, .option])
                #if os(iOS)
                Button("Pair Two Pages") { tabs.startPair() }.keyboardShortcut("p", modifiers: [.command, .option])
                #endif
            }
            CommandMenu("Bookmarks") {
                Button("Bookmark This Page") {
                    let page = tabs.page
                    services.library.toggleBookmark(title: page.title, url: page.address)
                }
                .keyboardShortcut("d")
                Button("Show Bookmarks") { services.sheet = .bookmarks }.keyboardShortcut("b", modifiers: [.command, .option])
                Divider()
                Button("Save for Later") { services.saveForLater(tabs.page) }
                    .keyboardShortcut("s")
                    .disabled(tabs.page.web.url == nil)
                Button("Show Reading List") { services.sheet = .reading }.keyboardShortcut("r", modifiers: [.command, .option])
            }
            CommandMenu("History") {
                Button("Show History") { services.sheet = .history }.keyboardShortcut("y")
                Button("Clear History") { services.library.clearHistory() }
                Button("Close Tabs and Clear Data…") { services.confirmBurn = true }.keyboardShortcut(.delete, modifiers: [.command, .shift])
                Divider()
                Button("Show Downloads") { services.sheet = .downloads }.keyboardShortcut("l", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { services.sheet = .settings }.keyboardShortcut(",")
            }
        }
        #if os(macOS)
        // One window per panel: opening Bookmarks twice brings the same window forward.
        WindowGroup(id: "panel", for: Services.Sheet.self) { $sheet in
            if let sheet { PanelView(sheet: sheet, tabs: tabs, services: services) }
        }
        .defaultSize(width: 560, height: 640)
        #endif
    }
}
