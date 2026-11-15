//
//  OvenSpeaker.swift
//  mgPizza_mk1
//

import AVFoundation
import AVKit
import SwiftUI

/// Sagt den Ofen-Alarm per Sprachausgabe an – über die gewählte AirPlay-Ausgabe (z. B. HomePod).
final class OvenSpeaker {
    static let shared = OvenSpeaker()
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking: Bool { synthesizer.isSpeaking }

    /// Long-Form-Audio erlaubt die Ausgabe auf AirPlay-Lautsprechern wie dem HomePod
    func activateSession() {
        // Während der Sprachsteuerung läuft das Mikrofon – Audio-Session dann nicht umstellen
        if VoiceControl.shared.isListening { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }

    /// `delay`: Pause vor der ersten Ansage, z. B. damit sie nicht über den Weckton läuft
    func announce(_ text: String, repeats: Int = 2, delay: TimeInterval = 0.5) {
        activateSession()
        let voice = AVSpeechSynthesisVoice(language: Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
            ?? AVSpeechSynthesisVoice(language: "de-DE")
        for index in 0..<repeats {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.preUtteranceDelay = index == 0 ? delay : 2.0
            synthesizer.speak(utterance)
        }
    }

    var currentOutputName: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "-"
    }
}

/// AirPlay-Auswahl (HomePod, AirPlay-Lautsprecher, iPhone)
struct AirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
