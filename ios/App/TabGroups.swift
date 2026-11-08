import SwiftUI

/// Switch between the main tabs and your named groups, start a new group, or delete the one on screen.
struct TabGroupsMenu: View {
    @ObservedObject var tabs: Tabs
    let services: Services

    var body: some View {
        Menu {
            Toggle("Main Tabs", isOn: Binding(get: { tabs.activeGroup == nil }, set: { if $0 { tabs.switchGroup(to: nil) } }))
            ForEach(tabs.groups) { g in
                Toggle(g.name, isOn: Binding(get: { tabs.activeGroup == g.id }, set: { if $0 { tabs.switchGroup(to: g.id) } }))
            }
            Divider()
            Button { services.namingGroup = true } label: { Label("New Tab Group…", systemImage: "plus.square.on.square") }
            if let id = tabs.activeGroup, let name = tabs.activeGroupName {
                Button(role: .destructive) { tabs.deleteGroup(id) } label: { Label("Delete \u{201C}\(name)\u{201D}", systemImage: "trash") }
            }
        } label: {
            Label(tabs.activeGroupName.map { "Tab Group: " + $0 } ?? "Tab Groups", systemImage: "square.stack")
        }
    }
}

struct NameGroupPrompt: ViewModifier {
    @ObservedObject var tabs: Tabs
    @ObservedObject var services: Services
    @State private var name = ""

    func body(content: Content) -> some View {
        content.alert("New Tab Group", isPresented: $services.namingGroup) {
            TextField("Name", text: $name)
            Button("Create") { tabs.newGroup(named: name); name = "" }
            Button("Cancel", role: .cancel) { name = "" }
        } message: {
            Text("Your tabs now stay in Main Tabs. The new group starts with one empty tab.")
        }
    }
}
