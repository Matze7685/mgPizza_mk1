//
//  KneadTimerView.swift
//  mgPizza_mk1
//

import AudioToolbox
import Combine
import SwiftUI

/// Knet-Timer direkt im Rezept: aktueller Schritt groß (mit Zutatenmengen), darunter alle Schritte.
/// Jeder Schritt wird von Hand gestartet, sobald alles in der Maschine ist.
struct KneadSection: View {
    @Bindable var recipe: RecipeSetupData
    var isExpanded = true
    var onToggle: () -> Void = {}
    /// Abwiegen der Zutaten, oben im Bereich (aus der Rezeptansicht)
    var ingredients: AnyView? = nil
    @State private var isEditing = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Section {
            if isExpanded {
                if let ingredients { ingredients }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    currentStepView(now: context.date)
                }
                VoiceControlRow(recipe: recipe)
            }
        } header: {
            // Alarm & Editor hängen am Header, damit sie auch eingeklappt funktionieren
            HStack {
                Button(action: onToggle) {
                    HStack {
                        Text("1 · Weigh & knead")
                        if !recipe.batchLabel.isEmpty {
                            Text("· \(recipe.batchLabel)").foregroundStyle(.orange)
                        }
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if isExpanded {
                    Button("Edit") { isEditing = true }
                        .font(.caption)
                }
            }
            .textCase(nil)
            .sheet(isPresented: $isEditing) {
                KneadStepsEditor(steps: $recipe.kneadSteps, defaultPlan: KneadStep.plan(forStyle: recipe.style))
            }
            .onReceive(tick) { now in
                // Schritt gerade eben bei offener App abgelaufen: Den Ton liefert die Benachrichtigung
                // (einzige Tonquelle, siehe AppDelegate). Die App klingelt nur selbst, wenn Benachrichtigungen aus sind.
                // KneadAlarm.finish meldet jedes Schrittende genau einmal, auch wenn die Rezeptansicht mehrfach offen ist.
                guard UIApplication.shared.applicationState == .active,
                      let end = recipe.kneadStepEnd, now >= end, now.timeIntervalSince(end) < 3,
                      KneadAlarm.finish(recipe.uid.uuidString, end: end) else { return }
                if DoughNotifications.isAuthorized != true {
                    KneadAlarm.ring()
                }
                VoiceControl.shared.stepFinished(for: recipe)
            }
        }
    }

    @ViewBuilder
    private func currentStepView(now: Date) -> some View {
        if let step = recipe.currentKneadStep {
            VStack(spacing: 10) {
                Text("Step \(recipe.kneadStepIndex + 1) of \(recipe.kneadSteps.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(LocalizedStringKey(step.title)).font(.title2).bold()
                let adds = recipe.addsText(for: step)
                if !adds.isEmpty {
                    Label(adds, systemImage: "plus.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                if !step.detail.isEmpty {
                    Text(LocalizedStringKey(step.detail)).font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let end = recipe.kneadStepEnd {
                    let remaining = max(0, end.timeIntervalSince(now))
                    Text(Duration.seconds(remaining.rounded(.up)), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(remaining == 0 ? .green : .primary)
                    Button {
                        recipe.nextKneadStep()
                    } label: {
                        prominentLabel(remaining == 0 ? LocalizedStringKey("Next step") : "Skip", systemImage: "forward.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(remaining == 0 ? .green : .gray)
                } else {
                    Text(Duration.seconds(step.minutes * 60), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button {
                        DoughNotifications.requestAuthorization()
                        recipe.startKneadStep()
                    } label: {
                        prominentLabel("Start (ready)", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } else if recipe.hasMoreBatches {
            VStack(spacing: 8) {
                Label("Batch \(recipe.currentBatch + 1) done", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Take the dough out, then fill the machine for the next batch.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button {
                    recipe.startNextBatch()
                } label: {
                    prominentLabel("Start batch \(recipe.currentBatch + 2) of \(recipe.batchCount)", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } else {
            VStack(spacing: 8) {
                Label("All steps done – into the fridge with it!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Button("Knead again", systemImage: "arrow.counterclockwise") {
                    recipe.resetKnead()
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    /// Wie „Jetzt backen“: Symbol + Text, fett, volle Breite (sonst zeigt iOS in Listen teils nur den Text)
    private func prominentLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .font(.headline)
            .frame(maxWidth: .infinity)
    }
}

/// Ersatz-Weckton für den Knet-Timer, falls Benachrichtigungen ausgeschaltet sind.
/// Normalerweise klingelt nur die Benachrichtigung (auch bei offener App) – vorher liefen App-Alarm und
/// Benachrichtigung getrennt und waren doppelt zu hören.
@MainActor
enum KneadAlarm {
    /// Wartezeit, bis eine Sprachansage nach dem Ton starten darf
    static let ringDuration: TimeInterval = 2.5
    private static var finishedSteps: Set<String> = []

    /// true beim ersten Aufruf für dieses Rezept und dieses Schrittende, danach false.
    static func finish(_ recipeID: String, end: Date) -> Bool {
        finishedSteps.insert("\(recipeID)@\(Int(end.timeIntervalSince1970))").inserted
    }

    /// Ein einzelner Ton (inkl. Vibration)
    static func ring() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }
}

struct KneadStepsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var steps: [KneadStep]
    var defaultPlan: [KneadStep] = KneadStep.defaultPlan

    var body: some View {
        NavigationStack {
            List {
                ForEach($steps) { $step in
                    VStack(alignment: .leading) {
                        TextField("Title", text: $step.title).font(.headline)
                        TextField("Description", text: $step.detail, axis: .vertical).font(.caption)
                        Stepper("\(step.minutes, specifier: "%.0f") min", value: $step.minutes, in: 1...60)
                    }
                }
                .onDelete { steps.remove(atOffsets: $0) }
                .onMove { steps.move(fromOffsets: $0, toOffset: $1) }

                Button("Add step", systemImage: "plus") {
                    steps.append(KneadStep(title: String(localized: "New step"), detail: "", minutes: 2))
                }
                Button("Restore default plan", systemImage: "arrow.uturn.backward") {
                    steps = defaultPlan
                }
            }
            .navigationTitle("Knead Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { List { KneadSection(recipe: RecipeSetupData()) } }
}
