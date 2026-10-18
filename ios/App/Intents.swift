import AppIntents
import Foundation

/// Shortcuts action: open a link in Blackcomb.
struct OpenInBlackcombIntent: AppIntent {
    static let title: LocalizedStringResource = "Open in Blackcomb"
    static let description = IntentDescription("Opens a link in a new Blackcomb tab.")
    static let openAppWhenRun = true

    @Parameter(title: "Link") var url: URL

    @MainActor func perform() async throws -> some IntentResult {
        Services.shared.receive(url, in: .tab)
        return .result()
    }
}

#if os(macOS)
/// Shortcuts action (Mac): open a link in the floating, see-through Float window.
struct OpenInFloatIntent: AppIntent {
    static let title: LocalizedStringResource = "Open in Float Window"
    static let description = IntentDescription("Opens a link in Blackcomb's floating window that stays above other apps.")
    static let openAppWhenRun = true

    @Parameter(title: "Link") var url: URL

    @MainActor func perform() async throws -> some IntentResult {
        Services.shared.receive(url, in: .float)
        return .result()
    }
}
#endif

struct BlackcombShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenInBlackcombIntent(), phrases: ["Open a link in \(.applicationName)"],
                    shortTitle: "Open in Blackcomb", systemImageName: "safari")
        #if os(macOS)
        AppShortcut(intent: OpenInFloatIntent(), phrases: ["Float a link in \(.applicationName)"],
                    shortTitle: "Open in Float Window", systemImageName: "pip")
        #endif
    }
}
