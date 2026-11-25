//
//  SettingsView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("doughSpeak") private var doughSpeak = false
    @AppStorage("showDoughStatus") private var showDoughStatus = true
    @AppStorage("mixerCapacity") private var mixerCapacity: Double = 2500

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TimerStatusView()
                } label: {
                    Label("Timer Status", systemImage: "checklist")
                }
            }
            Section {
                Toggle("Always show dough status", isOn: $showDoughStatus)
            } footer: {
                Text("Pins the current step and countdown to the top of the other tabs while you prepare the dough (weighing, kneading) – not during proofing and not on the Timer page, which shows it large. Running timers move to the Dynamic Island when you leave the app.")
            }
            Section {
                Stepper("Max. dough per batch: \(Int(mixerCapacity)) g", value: $mixerCapacity, in: 500...10000, step: 100)
            } header: {
                Text("Mixer")
            } footer: {
                Text("Larger recipes are split into several batches (ingredients and knead timer).")
            }
            Section {
                Toggle("Announce dough timers on speaker", isOn: $doughSpeak)
                if doughSpeak {
                    HStack {
                        Text("Output")
                        Spacer()
                        AirPlayPicker()
                            .frame(width: 44, height: 44)
                    }
                    Button("Test announcement", systemImage: "speaker.wave.2") {
                        OvenSpeaker.shared.announce(String(localized: "Test: the dough timer announcement works."), repeats: 1)
                    }
                }
            } header: {
                Text("Dough")
            } footer: {
                Text("Announces “dough out in 1 hour”, “take the dough out” and “serving” on the selected speaker (e.g. HomePod). Only works while the app is running – keep it open or in the background (e.g. with the oven probe connected). The normal notification always comes.")
            }
            Section("Oven") {
                NavigationLink {
                    OvenView()
                } label: {
                    Label("Oven Temperature", systemImage: "thermometer.high")
                }
                NavigationLink {
                    BLEDebugView()
                } label: {
                    Label("Bluetooth Test (Ooni Hub)", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
