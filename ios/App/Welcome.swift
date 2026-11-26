import SwiftUI

/// First-launch welcome, shown once over the browser. Three rows, one button.
struct WelcomeView: View {
    let done: () -> Void

    #if os(macOS)
    private let clearHow = "History menu, then Close Tabs and Clear Data. Shift-Command-Delete does it fast."
    private let windowsHow = "Shift-Command-Backslash shows every tab. The Window menu lists every open window."
    #else
    private let clearHow = "Tap the menu, then Close Tabs and Clear Data. History has its own Clear button."
    private let windowsHow = "Tap the tab count to see every open tab, group them, or close the ones you are done with."
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    (Text("Welcome to\n").foregroundStyle(.tint) + Text("Blackcomb"))
                        .font(.largeTitle.bold())
                    VStack(alignment: .leading, spacing: 32) {
                        row("flame", "Clear your tracks", clearHow)
                        row("square.on.square", "See what is open", windowsHow)
                        row("lock.shield", "Stays on your device", "History and bookmarks never leave it. Private tabs keep nothing.")
                    }
                }
                .padding(.top, 80)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button(action: done) {
                Text("Continue").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private func row(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title).foregroundStyle(.tint).frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
