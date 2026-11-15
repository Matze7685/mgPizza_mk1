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

    var body: some View {
        List {
            if activeRecipes.isEmpty {
                ContentUnavailableView("No dough running", systemImage: "timer",
                                       description: Text("Open a recipe and tap “Bake now”, or create a new one with … → New Recipe."))
            } else {
                Section("Running") {
                    ForEach(activeRecipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipeData: recipe)
                        } label: {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                ActiveRecipeCard(recipe: recipe, now: context.date)
                            }
                        }
                        .listRowBackground(Color.orange.opacity(0.12))
                        .swipeActions {
                            Button("Finish", systemImage: "stop.circle", role: .destructive) {
                                recipe.finishSession()
                            }
                        }
                    }
                }
            }
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
                NavigationLink {
                    TimerStatusView()
                } label: {
                    TimerStatusBadge()
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
                ActiveDoughRow(recipe: recipe, now: now, showsName: false)
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

/// Oben angeheftete Statusleiste (in der ganzen App) während der Zubereitung (Zutaten/Kneten) – nicht während der Garzeit.
/// Ein-/ausschaltbar in den Einstellungen („Always show dough status“).
struct DoughStatusBar: View {
    @Query(filter: #Predicate<RecipeSetupData> { $0.isStarted == true || $0.isInProgress == true },
           sort: \RecipeSetupData.dateSelection) private var activeRecipes: [RecipeSetupData]
    @ObservedObject private var router = AppRouter.shared

    /// Nur Rezepte in der Zubereitung (Gärphasen zeigt die Aktivitäts-Seite)
    private var preparing: [RecipeSetupData] {
        activeRecipes.filter { !$0.isStarted && $0.isInProgress }
    }

    var body: some View {
        if let recipe = preparing.first {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Button {
                    router.open(recipe)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: icon(recipe, now: context.date)).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(recipe.displayName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Text(title(recipe, now: context.date)).font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                        Spacer()
                        if let target = target(recipe, now: context.date) {
                            let remaining = max(0, target.timeIntervalSince(context.date))
                            Text(format(remaining)).font(.subheadline.weight(.bold)).monospacedDigit()
                                .foregroundStyle(remaining == 0 ? .green : .primary)
                        }
                        if preparing.count > 1 {
                            Text("+\(preparing.count - 1)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func target(_ recipe: RecipeSetupData, now: Date) -> Date? {
        switch recipe.phase(now: now) {
        case .knead: return recipe.kneadStepEnd
        case .fridge: return recipe.fridgeOutDate
        case .room: return recipe.servingDate
        default: return nil
        }
    }

    private func icon(_ recipe: RecipeSetupData, now: Date) -> String {
        switch recipe.phase(now: now) {
        case .ingredients: "scalemass"
        case .knead: "timer"
        case .fridge: "refrigerator"
        case .room: "thermometer.medium"
        default: "fork.knife"
        }
    }

    private func title(_ recipe: RecipeSetupData, now: Date) -> String {
        switch recipe.phase(now: now) {
        case .ingredients: return String(localized: "Weigh the ingredients")
        case .knead:
            if let step = recipe.currentKneadStep {
                return recipe.kneadStepEnd == nil ? String(localized: "Ready: \(recipe.kneadTitle(step))") : recipe.kneadTitle(step)
            }
            return recipe.hasMoreBatches ? String(localized: "Start the next batch") : String(localized: "Kneading done – into the fridge")
        case .fridge: return String(localized: "Out of the fridge")
        case .room: return String(localized: "Serving")
        default: return String(localized: "Ready to serve")
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let d = total / 86400, h = (total % 86400) / 3600, m = (total % 3600) / 60, sec = total % 60
        if d > 0 { return String(format: "%dd %02d:%02d", d, h, m) }
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}
