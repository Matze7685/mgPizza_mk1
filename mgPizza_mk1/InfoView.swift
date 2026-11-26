//
//  InfoView.swift
//  mgPizza_mk1
//
//  Info: Version/Build, Pizzazähler aus den Teigrezepten und Changelog.
//

import SwiftData
import SwiftUI

struct InfoView: View {
    @Query(sort: \RecipeSetupData.createdAt) private var recipes: [RecipeSetupData]

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }

    var body: some View {
        List {
            Section {
                PizzaCounterCard(stats: PizzaStats(recipes: recipes))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                Text("Counts the dough balls (or Detroit pans) of all saved dough recipes.")
            }

            Section("App") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: appBuild)
            }

            Section("Changelog") {
                ForEach(Changelog.entries) { entry in
                    ChangelogEntryView(entry: entry, isCurrent: entry.version == appVersion)
                }
            }
        }
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pizzazähler

struct PizzaStats {
    let total: Int
    let round: Int
    let detroit: Int
    let doughs: Int
    let thisYear: Int
    let doughKg: Double
    let flourKg: Double
    let biggest: RecipeSetupData?
    let perYear: [(year: Int, pizzas: Int)]

    init(recipes: [RecipeSetupData], now: Date = Date()) {
        let calendar = Calendar.current
        let pizzas: (RecipeSetupData) -> Int = { max(0, Int($0.doughBallsCount.rounded())) }
        let year = calendar.component(.year, from: now)

        total = recipes.reduce(0) { $0 + pizzas($1) }
        detroit = recipes.filter(\.isDetroit).reduce(0) { $0 + pizzas($1) }
        round = total - detroit
        doughs = recipes.count
        thisYear = recipes.filter { calendar.component(.year, from: $0.createdAt) == year }.reduce(0) { $0 + pizzas($1) }
        doughKg = recipes.reduce(0) { $0 + $1.totalDoughWeight } / 1000
        flourKg = recipes.reduce(0) { $0 + $1.flour } / 1000
        biggest = recipes.max { pizzas($0) < pizzas($1) }

        let byYear = Dictionary(grouping: recipes) { calendar.component(.year, from: $0.createdAt) }
        perYear = byYear.map { (year: $0.key, pizzas: $0.value.reduce(0) { $0 + pizzas($1) }) }
            .sorted { $0.year > $1.year }
    }
}

private struct PizzaCounterCard: View {
    let stats: PizzaStats

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("🍕").font(.system(size: 44))
                Text("\(stats.total)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Pizzas baked")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    tile("\(stats.doughs)", "Doughs", "scalemass")
                    tile("\(stats.thisYear)", "This year", "calendar")
                }
                GridRow {
                    tile("\(stats.round)", "Round", "circle")
                    tile("\(stats.detroit)", "Detroit", "square")
                }
                GridRow {
                    tile(stats.doughKg.formatted(.number.precision(.fractionLength(1))) + " kg", "Dough total", "shippingbox")
                    tile(stats.flourKg.formatted(.number.precision(.fractionLength(1))) + " kg", "Flour total", "leaf")
                }
            }

            if let biggest = stats.biggest, stats.total > 0 {
                HStack {
                    Label("Biggest dough", systemImage: "trophy")
                    Spacer()
                    Text("\(Int(biggest.doughBallsCount.rounded()))× · \(biggest.displayName)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.subheadline)
            }

            if stats.perYear.count > 1 {
                VStack(spacing: 6) {
                    ForEach(stats.perYear, id: \.year) { entry in
                        HStack {
                            Text(verbatim: "\(entry.year)")
                            Spacer()
                            Text("\(entry.pizzas)").monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.orange.gradient.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
    }

    private func tile(_ value: String, _ title: LocalizedStringKey, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(.orange)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Changelog

private struct ChangelogEntryView: View {
    let entry: Changelog.Entry
    let isCurrent: Bool
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.changes, id: \.self) { change in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "•").foregroundStyle(.orange)
                        Text(verbatim: change)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "Version \(entry.version)").font(.headline)
                    if isCurrent {
                        Text("Current")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Text(verbatim: "Build \(entry.builds) · \(entry.date) · \(entry.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { if isCurrent { isExpanded = true } }
    }
}

/// Änderungen pro Version. Neueste oben.
/// Build-Nummer = fortlaufende Zahl der Änderungen (Commits) im Projekt.
/// Bei jeder neuen Version: oben einen Eintrag ergänzen und in Xcode
/// MARKETING_VERSION / CURRENT_PROJECT_VERSION (App + Widget) anpassen.
enum Changelog {
    struct Entry: Identifiable {
        var id: String { version }
        let version: String
        let builds: String
        let date: String
        let title: String
        let changes: [String]
    }

    static let entries: [Entry] = [
        Entry(version: "1.7", builds: "80–82", date: "26.11.26", title: "Geteilte Ansicht", changes: [
            "⋯-Menü: Spalten und Knick-Abstand als beschriftete Untermenüs, „Nächste Pizza daneben“ zeigt die Hälfte immer an",
            "Tomatensauce, Reibekäse und Mozzarella stehen oben immer untereinander (🍅 🧀 ⚪️)",
            "Oben nur noch Zutatennamen, auch bei Zusatzzutaten ohne Mengen",
            "Zutaten größer in 2 oder 3 Spalten (Einstellungen), optional die nächste Pizza mit Zutaten daneben",
            "Button „Nächste Pizza“ in der oberen Hälfte",
        ]),
        Entry(version: "1.6", builds: "79", date: "26.11.26", title: "Info", changes: [
            "Info-Seite in den Einstellungen mit Version, Build und Changelog",
            "Pizzazähler aus allen Teigrezepten: gesamt, dieses Jahr, rund/Detroit, Teig und Mehl in kg, größter Teig",
        ]),
        Entry(version: "1.5", builds: "61–78", date: "26.11.26", title: "Anlass & Einkauf", changes: [
            "Tab „Anlass“ statt Speisekarte, eigener Einkauf-Tab, Tomatensauce aufgeteilt",
            "Anlass als erledigt markieren (wandert zu Vergangene, Bestellung geschlossen)",
            "Reibekäse (30 g) auf jeder Pizza, Parmesan immer als Extra",
            "Neue Pizza mit Zutatenauswahl und Vorlage",
            "Belagmengen für alle Pizzen auf einmal ändern, Mengen werden beim Tippen gespeichert",
            "Geteilte Ansicht: oben Gast mit Pizza und Zutaten, unten änderbare Reihenfolge",
            "Anlässe: schönere Übersicht, einfache Neuanlage, feste Seitenadresse",
            "Gästelink: Einrichtung vorbelegt, nichts mehr einzugeben",
            "Gästeseite: ein Gast pro Handy, nach dem Bestellen nur noch der eigene Name",
            "Push bei Gästebestellungen (Pizza-Push über den Mac mini)",
        ]),
        Entry(version: "1.4", builds: "53–60", date: "25.11.26", title: "Teig-Einstellung & Dynamic Island", changes: [
            "Teig-Einstellung als eine Seite im Stil der Zubereitung",
            "Rezeptansicht: Status angeheftet, nur aktueller Knetschritt, Gewichte",
            "Knet-Timer klingelt nur noch einmal und überlebt den Hintergrund",
            "Widget für die Dynamic Island, Countdown wird nicht mehr abgeschnitten",
            "Gäste: anonyme Anmeldung, fremde Bestellungen nicht mehr sichtbar",
        ]),
        Entry(version: "1.3", builds: "51–52", date: "16.–19.11.26", title: "Faltbares iPhone", changes: [
            "Geteilte Ansicht für das faltbare iPhone (oben Übersicht, unten Bedienung)",
            "Gästeseite: Bestellungen pro Gerät geschützt, Gastgeber kann freigeben/löschen",
        ]),
        Entry(version: "1.2", builds: "26–50", date: "15.11.26", title: "Gästeseite", changes: [
            "Gäste-Speisekartenlink mit eigener Webseite im Trattoria-Design",
            "Gäste wählen ihren Namen, Pizzen, Zusatzzutaten (Checkboxen) und abgewählte Zutaten",
            "Mehrere Abende/Anlässe mit Übersicht in der App",
            "Gästeliste: Gäste umbenennen und entfernen",
            "Sicherheitsfrage vor dem Löschen einer Bestellung",
            "Bestellungen abholen füllt direkt die Einkaufsliste, Ordner pro Anlass",
            "Einkaufsliste rechnet gleiche Zutaten zusammen (auch g ↔ Stück)",
            "Aufgeräumte Oberfläche: 3 Tabs, Hero-Karte, einklappbare Rezeptbereiche",
        ]),
        Entry(version: "1.1", builds: "22–25", date: "14.11.26", title: "Speisekarte & Sprachsteuerung", changes: [
            "Speisekarte für Gäste (als Text/PDF teilen, Bestellungen, Belag → Einkaufsliste)",
            "Statusleiste oben während der Zubereitung",
            "Sprachsteuerung für den Knetablauf",
            "Timer in der Dynamic Island beim Verlassen der App",
            "Ooni-Hub bleibt auch im Sperrbildschirm verbunden",
        ]),
        Entry(version: "1.0", builds: "13–21", date: "01.11.26", title: "Geführter Ablauf", changes: [
            "App heißt jetzt „Pizza“",
            "Geführter Ablauf: Zutaten → Kneten (mit Mengen und Alarm) → Kühlschrank-Timer",
            "Datum/Uhrzeit für „aus dem Kühlschrank“ und „Servieren“, Zeiten werden berechnet",
            "Mehl-Tipp: Caputo Rot für > 24 h, Caputo Blau für < 24 h Gare",
            "Teig in Durchgänge teilen, wenn er größer als die Knetmaschine ist",
            "Zutaten-Tipps für Saucen",
        ]),
        Entry(version: "0.2", builds: "4–12", date: "07.–10.08.26", title: "Rezepte & Timer", changes: [
            "Rezept-Assistent und gespeicherte Rezepte (SwiftData)",
            "Hefesorten, deutsche Übersetzung",
            "Timer mit Erinnerungen (1 h vorher, Teig raus, Servieren)",
            "Saucenrechner und Einkaufsliste",
        ]),
        Entry(version: "0.1", builds: "1–3", date: "29.07.26", title: "Start", changes: [
            "Erster Teigrechner",
        ]),
    ]
}

#Preview {
    NavigationStack { InfoView() }
        .modelContainer(for: RecipeSetupData.self, inMemory: true)
}
