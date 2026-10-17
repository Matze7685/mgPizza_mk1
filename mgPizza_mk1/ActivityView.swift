//
//  ActivityView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftData
import SwiftUI

/// Laufende Teige mit Countdown bis "Teig raus" und "Servieren".
struct ActivityView: View {
    @Query(filter: #Predicate<RecipeSetupData> { $0.isStarted == true },
           sort: \RecipeSetupData.dateSelection) private var activeRecipes: [RecipeSetupData]
    
    @EnvironmentObject var ovenMonitor: OvenMonitor

    var body: some View {
        List {
            Section {
                NavigationLink {
                    OvenView()
                } label: {
                    HStack {
                        Label("Oven", systemImage: "thermometer.high")
                        Spacer()
                        if let temp = ovenMonitor.temperatures.compactMap({ $0 }).first {
                            Text("\(Int(temp)) °C").bold().monospacedDigit()
                        } else {
                            Text(ovenMonitor.isActive ? "…" : "Off").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if activeRecipes.isEmpty {
                ContentUnavailableView("No dough running", systemImage: "timer",
                                       description: Text("Press START on a new recipe or “Start dough timer” on a saved one."))
            }
            ForEach(activeRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeData: recipe)
                } label: {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        ActiveDoughRow(recipe: recipe, now: context.date)
                    }
                }
                .swipeActions {
                    Button("Stop", systemImage: "stop.circle", role: .destructive) {
                        recipe.stopTimers()
                    }
                }
            }
        }
        .navigationTitle("Timer")
    }
}

struct ActiveDoughRow: View {
    var recipe: RecipeSetupData
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.displayName).font(.headline)
            if let out = recipe.fridgeOutDate, recipe.coolTime > 0 {
                countdown(title: "Out of the fridge", systemImage: "refrigerator", date: out)
            }
            if let serving = recipe.servingDate {
                countdown(title: "Serving", systemImage: "fork.knife", date: serving)
            }
        }
    }

    private func countdown(title: LocalizedStringKey, systemImage: String, date: Date) -> some View {
        let remaining = date.timeIntervalSince(now)
        return HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            VStack(alignment: .trailing) {
                if remaining > 0 {
                    Text(format(remaining)).monospacedDigit().bold()
                } else {
                    Text("Now!").bold().foregroundStyle(.green)
                }
                Text(date, format: .dateTime.weekday().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(remaining > 0 ? .primary : .secondary)
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let d = total / 86400, h = (total % 86400) / 3600, m = (total % 3600) / 60, s = total % 60
        return d > 0 ? String(format: "%dd %02d:%02d:%02d", d, h, m, s) : String(format: "%02d:%02d:%02d", h, m, s)
    }
}

#Preview {
    NavigationStack { ActivityView() }
        .environmentObject(OvenMonitor())
}
