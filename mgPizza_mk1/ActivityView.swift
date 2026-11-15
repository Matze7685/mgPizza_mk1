//
//  ActivityView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftData
import SwiftUI

/// Startseite: laufende Rezepte ganz oben (Knet-Timer bzw. Gärtimer), darunter Ofen und Status.
struct ActivityView: View {
    @Query(filter: #Predicate<RecipeSetupData> { $0.isStarted == true || $0.isInProgress == true },
           sort: \RecipeSetupData.dateSelection) private var activeRecipes: [RecipeSetupData]
    
    @EnvironmentObject var ovenMonitor: OvenMonitor
    @Environment(\.scenePhase) private var scenePhase

    /// Rezepte, die gerade Aufmerksamkeit brauchen (Zutaten/Kneten), zuerst; danach nach nächstem Termin.
    private func prioritized(now: Date) -> [RecipeSetupData] {
        activeRecipes.sorted { a, b in
            let pa = a.phase(now: now), pb = b.phase(now: now)
            let aBusy = pa == .ingredients || pa == .knead
            let bBusy = pb == .ingredients || pb == .knead
            if aBusy != bBusy { return aBusy }
            return (a.nextEvent(now: now)?.date ?? .distantFuture) < (b.nextEvent(now: now)?.date ?? .distantFuture)
        }
    }

    private func recipeLink<Label: View>(_ recipe: RecipeSetupData, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            RecipeDetailView(recipeData: recipe)
        } label: {
            label()
        }
        .swipeActions {
            Button("Finish", systemImage: "stop.circle", role: .destructive) {
                recipe.finishSession()
            }
        }
    }

    var body: some View {
        List {
            if activeRecipes.isEmpty {
                ContentUnavailableView("No dough running", systemImage: "timer",
                                       description: Text("Open a recipe and tap “Bake now”, or create a new one with the + button."))
            } else {
                let ordered = prioritized(now: .now)
                // Hero: das Wichtigste groß, der Rest kompakt darunter
                if let hero = ordered.first {
                    Section {
                        recipeLink(hero) {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                ActiveRecipeCard(recipe: hero, now: context.date)
                            }
                        }
                        .listRowBackground(Color.orange.opacity(0.12))
                    }
                }
                if ordered.count > 1 {
                    Section("Also running") {
                        ForEach(ordered.dropFirst()) { recipe in
                            recipeLink(recipe) {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    CompactRecipeRow(recipe: recipe, now: context.date)
                                }
                            }
                        }
                    }
                }
            }
            // Ofen als schmale Statuszeile (Timer-Status liegt jetzt in den Einstellungen)
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
                            Text(ovenMonitor.isActive ? LocalizedStringKey("…") : "Off").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Timer")
        // Live Activities aktualisieren (nächstes Ereignis, 8-Std.-Grenze von iOS)
        .onAppear { LiveActivityManager.shared.refreshDough(activeRecipes.filter(\.isStarted)) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { LiveActivityManager.shared.refreshDough(activeRecipes.filter(\.isStarted)) }
        }
    }
}

/// Karte für ein laufendes Rezept: Fortschritt + das, was gerade zu tun ist
struct ActiveRecipeCard: View {
    var recipe: RecipeSetupData
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.displayName).font(.headline)
            PhaseProgressView(phase: recipe.phase(now: now))
            switch recipe.phase(now: now) {
            case .ingredients:
                Label("Weigh the ingredients, then start kneading", systemImage: "scalemass")
                    .font(.callout)
            case .knead:
                kneadInfo
            default:
                if let event = recipe.nextEvent(now: now) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(event.title, systemImage: event.icon)
                        Spacer()
                        Text(ActivityFormat.countdown(event.date.timeIntervalSince(now)))
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(event.date, format: .dateTime.weekday().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ActiveDoughRow(recipe: recipe, now: now, showsName: false)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var kneadInfo: some View {
        if let step = recipe.currentKneadStep {
            HStack {
                Label(recipe.kneadTitle(step), systemImage: "timer")
                Spacer()
                if let end = recipe.kneadStepEnd {
                    let remaining = max(0, end.timeIntervalSince(now))
                    Text(Duration.seconds(remaining.rounded(.up)), format: .time(pattern: .minuteSecond))
                        .monospacedDigit().bold()
                        .foregroundStyle(remaining == 0 ? .green : .primary)
                } else {
                    Text("Ready to start").font(.caption).foregroundStyle(.orange)
                }
            }
        } else if recipe.hasMoreBatches {
            Label("Batch \(recipe.currentBatch + 1) done – start the next one", systemImage: "square.split.2x1")
                .font(.callout)
                .foregroundStyle(.orange)
        } else {
            Label("Kneading done – start the fridge timer", systemImage: "refrigerator")
                .font(.callout)
                .foregroundStyle(.blue)
        }
    }
}

/// Eine Zeile pro weiterem laufenden Rezept: Name, Phase, nächste Zeit.
struct CompactRecipeRow: View {
    var recipe: RecipeSetupData
    var now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.displayName).font(.subheadline.weight(.semibold))
                Text(phaseTitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let event = recipe.nextEvent(now: now) {
                Text(ActivityFormat.countdown(event.date.timeIntervalSince(now)))
                    .monospacedDigit().bold()
            }
        }
    }

    private var phaseTitle: LocalizedStringKey {
        switch recipe.phase(now: now) {
        case .ingredients: return "Ingredients"
        case .knead: return "Knead"
        case .fridge: return "Fridge"
        case .room: return "Room"
        case .serve: return "Serve"
        case nil: return ""
        }
    }
}

enum ActivityFormat {
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let d = total / 86400, h = (total % 86400) / 3600, m = (total % 3600) / 60, s = total % 60
        return d > 0 ? String(format: "%dd %02d:%02d:%02d", d, h, m, s) : String(format: "%02d:%02d:%02d", h, m, s)
    }
}

extension RecipeSetupData {
    /// Nächstes zeitgesteuertes Ereignis (Teig raus / Servieren)
    func nextEvent(now: Date) -> (title: LocalizedStringKey, icon: String, date: Date)? {
        if isStarted {
            if let out = fridgeOutDate, coolTime > 0, out > now { return ("Out of the fridge", "refrigerator", out) }
            if let serving = servingDate, serving > now { return ("Serving", "fork.knife", serving) }
        }
        return nil
    }
}

struct ActiveDoughRow: View {
    var recipe: RecipeSetupData
    var now: Date
    var showsName = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsName {
                Text(recipe.displayName).font(.headline)
            }
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
