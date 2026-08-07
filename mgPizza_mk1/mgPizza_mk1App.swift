//
//  mgPizza_mk1App.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 28.07.26.
//

import SwiftData
import SwiftUI

@main
struct mgPizza_mk1App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecipeSetupData.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
//        .modelContainer(for: RecipeSetupData.self)
        .modelContainer(sharedModelContainer)
    }
}
