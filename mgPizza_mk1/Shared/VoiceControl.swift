//
//  VoiceControl.swift
//  mgPizza_mk1
//

import AVFoundation
import Combine
import Speech
import SwiftUI

/// Sprachsteuerung für den geführten Teigablauf (Kneten → Kühlschrank), z. B. „nächster Schritt“, „Start“, „zurück“.
/// Hört nur, solange sie im Rezept eingeschaltet ist und die App im Vordergrund läuft. Das Display bleibt dabei an.
/// Antworten werden vorgelesen; während der Ansage wird nicht zugehört (sonst hört die App sich selbst).
@MainActor
final class VoiceControl: NSObject, ObservableObject {
    static let shared = VoiceControl()

    @Published private(set) var isListening = false
    @Published private(set) var recipeID: UUID?
    @Published private(set) var lastHeard = ""
    @Published var errorMessage: String?

    private weak var recipe: RecipeSetupData?
    private let audioEngine = AVAudioEngine()
    private let sink = RecognitionSink()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var generation = 0
    private var lastCommandDate = Date.distantPast
    private var heardWhileSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func isListening(for recipe: RecipeSetupData) -> Bool {
        isListening && recipeID == recipe.uid
    }

    func toggle(for recipe: RecipeSetupData) {
        if isListening(for: recipe) { stop() } else { start(for: recipe) }
    }

    // MARK: Start / Stopp

    func start(for recipe: RecipeSetupData) {
        stop()
        errorMessage = nil
        self.recipe = recipe
        recipeID = recipe.uid
        SFSpeechRecognizer.requestAuthorization { @Sendable status in
            Task { @MainActor in
                guard status == .authorized else {
                    VoiceControl.shared.fail(String(localized: "Speech recognition is not allowed. Turn it on in the iOS Settings under Privacy → Speech Recognition."))
                    return
                }
                AVAudioApplication.requestRecordPermission { @Sendable granted in
                    Task { @MainActor in
                        guard granted else {
                            VoiceControl.shared.fail(String(localized: "Microphone access is not allowed. Turn it on in the iOS Settings under Privacy → Microphone."))
                            return
                        }
                        VoiceControl.shared.beginListening()
                    }
                }
            }
        }
    }

    func stop() {
        generation += 1
        task?.cancel()
        task = nil
        sink.finish()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        synthesizer.stopSpeaking(at: .immediate)
        if isListening {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        isListening = false
        recipeID = nil
        recipe = nil
        lastHeard = ""
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func fail(_ message: String) {
        stop()
        errorMessage = message
    }

    private func beginListening() {
        guard let recipe else { return }
        let locale = Locale.current.language.languageCode == .english ? Locale.current : Locale(identifier: "de-DE")
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "de-DE")),
              recognizer.isAvailable else {
            fail(String(localized: "Speech recognition is not available right now."))
            return
        }
        self.recognizer = recognizer

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            let sink = self.sink
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
                sink.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            fail(String(localized: "Microphone could not be started: \(error.localizedDescription)"))
            return
        }

        isListening = true
        UIApplication.shared.isIdleTimerDisabled = true   // Display bleibt an, solange zugehört wird
        startRecognitionTask()
        speak(String(localized: "Voice control on.") + " " + stepText(for: recipe))
    }

    /// Neue Erkennung starten (leert den bisher gehörten Text)
    private func startRecognitionTask() {
        guard isListening, let recognizer else { return }
        task?.cancel()
        generation += 1
        let current = generation

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .confirmation
        request.contextualStrings = VoiceCommand.contextualStrings
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        sink.setRequest(request)
        heardWhileSpeaking = false

        task = recognizer.recognitionTask(with: request) { @Sendable result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                VoiceControl.shared.handle(text: text, isFinal: isFinal, failed: failed, generation: current)
            }
        }
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool, generation current: Int) {
        guard current == generation, isListening else { return }

        if let text, !text.isEmpty {
            if synthesizer.isSpeaking || OvenSpeaker.shared.isSpeaking {
                // Eigene Ansage / Teig-Ansage gehört – ignorieren, danach neu beginnen
                heardWhileSpeaking = true
                return
            }
            if heardWhileSpeaking {
                startRecognitionTask()
                return
            }
            lastHeard = text
            if let command = VoiceCommand.match(text), Date().timeIntervalSince(lastCommandDate) > 1.5 {
                lastCommandDate = Date()
                perform(command)
                startRecognitionTask()
                return
            }
            // Langes Gerede ohne Befehl verwerfen, damit alte Wörter nicht später auslösen
            if text.count > 80 {
                startRecognitionTask()
                return
            }
        }

        if isFinal || failed {
            // Erkennung endet nach Pausen/Fehlern – kurz warten und weiter zuhören
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard current == VoiceControl.shared.generation else { return }
                VoiceControl.shared.startRecognitionTask()
            }
        }
    }

    // MARK: Befehle

    private func perform(_ command: VoiceCommand) {
        guard let recipe else { stop(); return }

        switch command {
        case .stopListening:
            speak(String(localized: "Voice control off."))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { VoiceControl.shared.stop() }

        case .start:
            if recipe.currentKneadStep != nil {
                if recipe.kneadStepEnd == nil {
                    DoughNotifications.requestAuthorization()
                    recipe.startKneadStep()
                    let minutes = Int(recipe.currentKneadStep?.minutes ?? 0)
                    speak(String(localized: "Timer started: \(minutes) minutes."))
                } else {
                    speak(remainingText(for: recipe))
                }
            } else if recipe.hasMoreBatches {
                recipe.startNextBatch()
                speak(stepText(for: recipe))
            } else {
                speak(String(localized: "Kneading is done. Say “fridge” to start the proofing timer."))
            }

        case .next:
            if recipe.currentKneadStep != nil {
                recipe.nextKneadStep()
                speak(stepText(for: recipe))
            } else if recipe.hasMoreBatches {
                recipe.startNextBatch()
                speak(stepText(for: recipe))
            } else {
                speak(String(localized: "Kneading is done. Say “fridge” to start the proofing timer."))
            }

        case .back:
            if recipe.kneadStepIndex > 0 {
                recipe.previousKneadStep()
            } else {
                recipe.restartKneadStep()
            }
            speak(stepText(for: recipe))

        case .repeatStep:
            speak(stepText(for: recipe))

        case .remaining:
            speak(remainingText(for: recipe))

        case .fridge:
            if recipe.isStarted {
                speak(remainingText(for: recipe))
            } else {
                DoughNotifications.requestAuthorization()
                recipe.isInProgress = true
                recipe.startTimers()
                if let out = recipe.fridgeOutDate, recipe.coolTime > 0 {
                    let time = out.formatted(.dateTime.weekday(.wide).hour().minute())
                    speak(String(localized: "Into the fridge. Take the dough out on \(time)."))
                } else {
                    speak(String(localized: "Proofing timer started."))
                }
            }
        }
    }

    /// Wird vom Knet-Timer gerufen, wenn ein Schritt abgelaufen ist (nach dem Weckton)
    func stepFinished(for recipe: RecipeSetupData) {
        guard isListening(for: recipe), !DoughAnnouncer.shared.isEnabled, let step = recipe.currentKneadStep else { return }
        let title = String(localized: String.LocalizationValue(step.title))
        DispatchQueue.main.asyncAfter(deadline: .now() + KneadAlarm.ringDuration) {
            VoiceControl.shared.speak(String(localized: "\(title) is finished. Say “next step”."))
        }
    }

    // MARK: Texte

    private func stepText(for recipe: RecipeSetupData) -> String {
        guard recipe.isActive || recipe.currentKneadStep != nil else {
            return String(localized: "Say “start” to begin.")
        }
        if recipe.isStarted {
            return remainingText(for: recipe)
        }
        if let step = recipe.currentKneadStep {
            var parts = [String(localized: "Step \(recipe.kneadStepIndex + 1) of \(recipe.kneadSteps.count): \(String(localized: String.LocalizationValue(step.title))).")]
            if !recipe.batchLabel.isEmpty { parts.append(recipe.batchLabel + ".") }
            let adds = recipe.addsText(for: step).replacingOccurrences(of: " · ", with: ", ")
            if !adds.isEmpty { parts.append(String(localized: "Add \(adds).")) }
            if recipe.kneadStepEnd == nil {
                parts.append(String(localized: "Say “start” when everything is in the machine."))
            } else {
                parts.append(remainingText(for: recipe))
            }
            return parts.joined(separator: " ")
        }
        if recipe.hasMoreBatches {
            return String(localized: "Batch \(recipe.currentBatch + 1) done. Say “next step” for the next batch.")
        }
        return String(localized: "Kneading is done. Say “fridge” to start the proofing timer.")
    }

    private func remainingText(for recipe: RecipeSetupData, now: Date = Date()) -> String {
        if let end = recipe.kneadStepEnd {
            let seconds = max(0, Int(end.timeIntervalSince(now).rounded(.up)))
            if seconds == 0 { return String(localized: "The step is finished. Say “next step”.") }
            return String(localized: "Still \(seconds / 60) minutes and \(seconds % 60) seconds.")
        }
        if recipe.isStarted {
            if let out = recipe.fridgeOutDate, recipe.coolTime > 0, out > now {
                return String(localized: "The dough comes out of the fridge on \(out.formatted(.dateTime.weekday(.wide).hour().minute())).")
            }
            if let serving = recipe.servingDate, serving > now {
                return String(localized: "Serving on \(serving.formatted(.dateTime.weekday(.wide).hour().minute())).")
            }
            return String(localized: "The dough is ready. Time to heat the oven.")
        }
        return String(localized: "No timer is running. Say “start”.")
    }

    private func speak(_ text: String) {
        guard isListening else { return }
        let utterance = AVSpeechUtterance(string: text)
        let language = recognizer?.locale.identifier.replacingOccurrences(of: "_", with: "-") ?? "de-DE"
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "de-DE")
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    fileprivate func speechFinished() {
        // Alles, was während der Ansage gehört wurde, verwerfen
        if isListening { startRecognitionTask() }
    }
}

extension VoiceControl: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in VoiceControl.shared.speechFinished() }
    }
}

/// Reicht die Mikrofon-Puffer (Audio-Thread) an die jeweils aktuelle Erkennung weiter
nonisolated final class RecognitionSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func setRequest(_ newRequest: SFSpeechAudioBufferRecognitionRequest) {
        lock.lock(); defer { lock.unlock() }
        request?.endAudio()
        request = newRequest
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        request?.append(buffer)
    }

    func finish() {
        lock.lock(); defer { lock.unlock() }
        request?.endAudio()
        request = nil
    }
}

/// Sprachbefehle (Deutsch, zusätzlich Englisch)
enum VoiceCommand: CaseIterable {
    case next, start, back, repeatStep, remaining, fridge, stopListening

    /// Reihenfolge = Priorität (z. B. „Schritt zurück“ vor „Schritt“)
    var phrases: [String] {
        switch self {
        case .stopListening: ["sprachsteuerung aus", "nicht mehr zuhören", "stop listening", "voice control off"]
        case .back: ["zurück", "vorheriger schritt", "letzter schritt", "go back", "previous step", "back"]
        case .fridge: ["kühlschrank", "gärtimer", "gare starten", "fridge"]
        case .remaining: ["wie lange", "restzeit", "wie viel zeit", "wieviel zeit", "how long", "time left"]
        case .repeatStep: ["wiederholen", "nochmal", "noch mal", "was jetzt", "was muss ich", "repeat", "what now"]
        case .next: ["nächster schritt", "nächsten schritt", "nächste schritt", "weiter", "next step", "next"]
        case .start: ["start", "starten", "starte", "los geht's", "los", "timer an", "go"]
        }
    }

    static var contextualStrings: [String] {
        ["nächster Schritt", "weiter", "Start", "zurück", "wiederholen", "wie lange noch", "Kühlschrank", "Sprachsteuerung aus"]
    }

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de-DE"))
        let cleaned = folded.map { $0.isLetter || $0.isNumber || $0 == "'" ? $0 : " " }
        return " " + String(cleaned).split(separator: " ").joined(separator: " ") + " "
    }

    static func match(_ text: String) -> VoiceCommand? {
        let normalized = normalize(text)
        for command in VoiceCommand.allCases.sorted(by: { $0.priority < $1.priority }) {
            for phrase in command.phrases where normalized.contains(normalize(phrase)) {
                return command
            }
        }
        return nil
    }

    private var priority: Int {
        switch self {
        case .stopListening: 0
        case .back: 1
        case .fridge: 2
        case .remaining: 3
        case .repeatStep: 4
        case .next: 5
        case .start: 6
        }
    }
}

/// Mikrofon-Schalter im Knet-Abschnitt
struct VoiceControlRow: View {
    var recipe: RecipeSetupData
    @ObservedObject private var voice = VoiceControl.shared

    var body: some View {
        let active = voice.isListening(for: recipe)
        VStack(alignment: .leading, spacing: 6) {
            Button {
                voice.toggle(for: recipe)
            } label: {
                HStack {
                    Image(systemName: active ? "mic.fill" : "mic")
                        .symbolEffect(.pulse, isActive: active)
                        .foregroundStyle(active ? .red : .accentColor)
                    Text(active ? LocalizedStringKey("Voice control on – listening") : "Voice control")
                    Spacer()
                    Text(active ? LocalizedStringKey("Off") : "On")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if active {
                Text("Say: “next step”, “start”, “back”, “repeat”, “how long”, “fridge”, “voice control off”")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !voice.lastHeard.isEmpty {
                    Text("Heard: \(voice.lastHeard)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            if let error = voice.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
