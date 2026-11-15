import SwiftUI

@main
struct ServerZentraleApp: App {
    @State private var model = ServerModel()

    var body: some Scene {
        MenuBarExtra {
            StatusMenu(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
