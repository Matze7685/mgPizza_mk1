//
//  OvenView.swift
//  mgPizza_mk1
//

import SwiftUI

/// Live-Temperatur des Ooni-Hubs mit Zieltemperatur-Alarm.
struct OvenView: View {
    @EnvironmentObject var monitor: OvenMonitor

    var body: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(monitor.lastUpdate.map { Date().timeIntervalSince($0) < 10 } == true ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(monitor.status.isEmpty ? String(localized: "Not connected") : monitor.status)
                    Spacer()
                    Button(monitor.isActive ? LocalizedStringKey("Stop") : "Connect") {
                        monitor.isActive ? monitor.stop() : monitor.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(monitor.isActive ? .red : .green)
                }
            } footer: {
                Text("Close the Ooni app first – the hub accepts only one connection. Keep this app running in the background to get the alarm.")
            }

            // Fühler 1 immer, weitere nur wenn eingesteckt
            ForEach(0..<OoniHub.probeCount, id: \.self) { probe in
                if probe == 0 || monitor.temperatures[probe] != nil {
                    probeSection(probe)
                }
            }

            hubTimerSection
            speakerSection
        }
        .navigationTitle("Oven Temperature")
        .navigationBarTitleDisplayMode(.inline)
    }

    var hubTimerSection: some View {
        Section {
            Toggle("Remind 5 min before auto-off", isOn: $monitor.hubReminder)
            if let off = monitor.hubOffDate {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, off.timeIntervalSince(context.date))
                    LabeledContent("Hub turns off in") {
                        Text(Duration.seconds(remaining.rounded(.up)), format: .time(pattern: .minuteSecond))
                            .monospacedDigit()
                            .foregroundStyle(remaining < OvenMonitor.hubWarningLead ? .red : .primary)
                    }
                }
                Button("I pressed the hub button", systemImage: "arrow.counterclockwise") {
                    monitor.resetHubTimer()
                }
            }
        } header: {
            Text("Hub auto-off (45 min)")
        } footer: {
            Text("Counted from the first connection. If you switched the hub on earlier, the real time may be shorter.")
        }
    }

    var speakerSection: some View {
        Section {
            Toggle("Announce alarm on speaker", isOn: $monitor.speakAlarm)
            if monitor.speakAlarm {
                HStack {
                    Text("Output")
                    Spacer()
                    AirPlayPicker()
                        .frame(width: 44, height: 44)
                }
                Button("Test announcement", systemImage: "speaker.wave.2") {
                    OvenSpeaker.shared.announce(String(localized: "Test: the pizza oven alarm works."), repeats: 1)
                }
            }
        } header: {
            Text("HomePod")
        } footer: {
            Text("Tap the AirPlay icon and choose your HomePod. The app must stay connected to the hub (running in the background) for the announcement.")
        }
    }

    @ViewBuilder
    func probeSection(_ probe: Int) -> some View {
        let temp = monitor.temperatures[probe]
        let target = monitor.target(probe)
        Section("Probe \(probe + 1)") {
            VStack(spacing: 8) {
                if let temp {
                    Text("\(Int(temp)) °C")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(temp >= target ? .green : .orange)
                    ProgressView(value: min(max(temp / target, 0), 1))
                        .tint(temp >= target ? .green : .orange)
                } else {
                    Text("– – –")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(monitor.isActive ? LocalizedStringKey("No probe plugged in") : "Not connected")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            Toggle("Alarm", isOn: probe == 0 ? $monitor.alarm0 : $monitor.alarm1)
            Stepper("Target: \(Int(target)) °C",
                    value: probe == 0 ? $monitor.target0 : $monitor.target1,
                    in: 50...550, step: 10) { editing in
                if !editing { monitor.rearm(probe) }
            }
        }
    }
}

#Preview {
    NavigationStack { OvenView() }
        .environmentObject(OvenMonitor())
}
