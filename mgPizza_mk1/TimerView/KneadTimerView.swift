//
//  KneadTimerView.swift
//  mgPizza_mk1
//

import SwiftUI

/// Manuell gestartete Timer für die Knetmaschine: Schritt starten, wenn alles drin ist.
struct KneadTimerView: View {
    @Bindable var recipe: RecipeSetupData

    @AppStorage("kneadRecipeID") private var kneadRecipeID: String = ""
    @AppStorage("kneadStepIndex") private var storedIndex: Int = 0
    @AppStorage("kneadStepEnd") private var storedEnd: Double = 0
    @State private var isEditing = false

    private var isMine: Bool { kneadRecipeID == recipe.uid.uuidString }
    private var currentIndex: Int { isMine ? storedIndex : 0 }
    private var stepEnd: Date? { isMine && storedEnd > 0 ? Date(timeIntervalSince1970: storedEnd) : nil }
    private var isFinished: Bool { currentIndex >= recipe.kneadSteps.count }

    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    currentStepView(now: context.date)
                }
            }
            Section("Steps") {
                ForEach(Array(recipe.kneadSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top) {
                        Image(systemName: index < currentIndex ? "checkmark.circle.fill" : (index == currentIndex ? "circle.inset.filled" : "circle"))
                            .foregroundStyle(index < currentIndex ? .green : (index == currentIndex ? .orange : .gray))
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey(step.title)).font(.headline)
                            Text(LocalizedStringKey(step.detail)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(step.minutes, specifier: "%.0f") min").monospacedDigit()
                    }
                }
            }
            Section {
                Button("Reset", systemImage: "arrow.counterclockwise", role: .destructive) {
                    reset()
                }
            }
        }
        .navigationTitle("Knead Timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit", systemImage: "pencil") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            KneadStepsEditor(steps: $recipe.kneadSteps)
        }
        .onAppear { DoughNotifications.requestAuthorization() }
    }

    @ViewBuilder
    func currentStepView(now: Date) -> some View {
        if isFinished {
            Label("All steps done – into the fridge with it!", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
        } else {
            let step = recipe.kneadSteps[currentIndex]
            VStack(spacing: 12) {
                Text("Step \(currentIndex + 1) of \(recipe.kneadSteps.count)").font(.caption).foregroundStyle(.secondary)
                Text(LocalizedStringKey(step.title)).font(.title2).bold()
                Text(LocalizedStringKey(step.detail)).font(.callout).multilineTextAlignment(.center)

                if let end = stepEnd {
                    let remaining = max(0, end.timeIntervalSince(now))
                    Text(Duration.seconds(remaining.rounded(.up)), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(remaining == 0 ? .green : .primary)
                    Button(remaining == 0 ? LocalizedStringKey("Next step") : "Skip", systemImage: "forward.fill") {
                        nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(remaining == 0 ? .green : .gray)
                } else {
                    Text(Duration.seconds(step.minutes * 60), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Start (ready)", systemImage: "play.fill") {
                        start(step)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private func start(_ step: KneadStep) {
        kneadRecipeID = recipe.uid.uuidString
        storedIndex = currentIndex
        let end = Date().addingTimeInterval(step.minutes * 60)
        storedEnd = end.timeIntervalSince1970
        DoughNotifications.scheduleKneadStep(title: step.title, at: end)
    }

    private func nextStep() {
        DoughNotifications.cancelKneadStep()
        kneadRecipeID = recipe.uid.uuidString
        storedIndex = currentIndex + 1
        storedEnd = 0
    }

    private func reset() {
        DoughNotifications.cancelKneadStep()
        kneadRecipeID = recipe.uid.uuidString
        storedIndex = 0
        storedEnd = 0
    }
}

struct KneadStepsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var steps: [KneadStep]

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
                    steps = KneadStep.defaultPlan
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
    NavigationStack { KneadTimerView(recipe: RecipeSetupData()) }
}
