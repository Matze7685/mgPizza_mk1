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
    @State private var isEditing = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                currentStepView(now: context.date)
            }
            VoiceControlRow(recipe: recipe)
            ForEach(Array(recipe.kneadSteps.enumerated()), id: \.element.id) { index, step in
                stepRow(index: index, step: step)
            }
        } header: {
            HStack {
                Text("2 · Knead")
                if !recipe.batchLabel.isEmpty {
                    Text("· \(recipe.batchLabel)").foregroundStyle(.orange)
                }
                Spacer()
                Button("Edit") { isEditing = true }
                    .font(.caption)
                    .textCase(nil)
            }
        }
        .sheet(isPresented: $isEditing) {
            KneadStepsEditor(steps: $recipe.kneadSteps, defaultPlan: KneadStep.plan(forStyle: recipe.style))
        }
        .onReceive(tick) { now in
            // Alarm, wenn der laufende Schritt abgelaufen ist und die App offen ist.
            // KneadAlarm klingelt pro Schritt nur einmal (auch wenn die Benachrichtigung gleichzeitig kommt
            // oder die Rezeptansicht zweimal im Navigationsstapel liegt).
            // Nur klingeln, wenn der Schritt gerade eben bei sichtbarer App abgelaufen ist. Läuft die App nur im
            // Hintergrund weiter (Bluetooth/Audio) oder kommt man erst später zurück, hat die Benachrichtigung
            // schon geklingelt – ein zweiter Ton wäre genau der Doppelalarm.
            guard UIApplication.shared.applicationState == .active,
                  let end = recipe.kneadStepEnd, now >= end, now.timeIntervalSince(end) < 3 else { return }
            if KneadAlarm.ring(for: recipe.uid.uuidString) {
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
                    Button(remaining == 0 ? LocalizedStringKey("Next step") : "Skip", systemImage: "forward.fill") {
                        recipe.nextKneadStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(remaining == 0 ? .green : .gray)
                } else {
                    Text(Duration.seconds(step.minutes * 60), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Start (ready)", systemImage: "play.fill") {
                        DoughNotifications.requestAuthorization()
                        recipe.startKneadStep()
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
                Button("Start batch \(recipe.currentBatch + 2) of \(recipe.batchCount)", systemImage: "arrow.right.circle.fill") {
                    recipe.startNextBatch()
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

    private func stepRow(index: Int, step: KneadStep) -> some View {
        let current = recipe.kneadStepIndex
        return HStack(alignment: .top) {
            Image(systemName: index < current ? "checkmark.circle.fill" : (index == current ? "circle.inset.filled" : "circle"))
                .foregroundStyle(index < current ? .green : (index == current ? .orange : .gray))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(step.title)).font(.subheadline.weight(.semibold))
                let adds = recipe.addsText(for: step)
                if !adds.isEmpty {
                    Text(adds).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            Text("\(step.minutes, specifier: "%.0f") min").font(.caption).monospacedDigit()
        }
        .opacity(index < current ? 0.5 : 1)
    }
}

/// Weckton für den Knet-Timer (wenn die App offen ist; im Hintergrund klingelt die Benachrichtigung).
/// Einzige Stelle, die im Vordergrund klingelt: Knet-Benachrichtigungen werden ohne eigenen Ton
/// angezeigt (siehe AppDelegate) und jeder Schritt klingelt nur einmal – vorher liefen Benachrichtigungston
/// und App-Alarm (ggf. mehrfach) gleichzeitig.
@MainActor
enum KneadAlarm {
    static let ringDuration: TimeInterval = 3.6
    private static var lastRing: [String: Date] = [:]

    /// Klingelt einmal pro Rezept und Schritt (30-s-Fenster: Benachrichtigung und Ansicht melden dasselbe Ende).
    @discardableResult
    static func ring(for recipeID: String) -> Bool {
        let now = Date()
        if let last = lastRing[recipeID], now.timeIntervalSince(last) < 30 { return false }
        lastRing[recipeID] = now
        ring()
        return true
    }

    private static func ring(times: Int = 3) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.2) {
                AudioServicesPlayAlertSound(SystemSoundID(1005))
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
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
