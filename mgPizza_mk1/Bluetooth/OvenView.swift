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
                    Button(monitor.isActive ? "Stop" : "Connect") {
                        monitor.isActive ? monitor.stop() : monitor.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(monitor.isActive ? .red : .green)
                }
            } footer: {
                Text("Close the Ooni app first – the hub accepts only one connection. Keep this app running in the background to get the alarm.")
            }

            ForEach(0..<OoniHub.probeCount, id: \.self) { probe in
                probeSection(probe)
            }
        }
        .navigationTitle("Oven Temperature")
        .navigationBarTitleDisplayMode(.inline)
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
                    Text(monitor.isActive ? "No probe plugged in" : "Not connected")
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
