import SwiftUI

@main
struct ServerZentraleApp: App {
    @State private var model = ServerModel()
    @State private var forwards = ForwardStore()

    var body: some Scene {
        MenuBarExtra {
            StatusMenu(model: model, forwardCount: forwards.forwards.count)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Weiterleitungen", id: "forwards") {
            ForwardsView(store: forwards)
        }
    }
}
