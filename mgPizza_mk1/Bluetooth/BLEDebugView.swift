//
//  BLEDebugView.swift
//  mgPizza_mk1
//

import CoreBluetooth
import SwiftUI

/// Testansicht: Bluetooth-Geräte suchen, verbinden und Rohdaten live anzeigen.
struct BLEDebugView: View {
    @StateObject private var scanner = BLEScanner()
    @State private var showUnnamed = false
    @State private var filter = "ooni"

    var visibleDevices: [BLEScanner.Device] {
        scanner.devices.values
            .filter { showUnnamed || !$0.name.isEmpty }
            .filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
            .sorted { $0.rssi > $1.rssi }
    }

    var body: some View {
        List {
            if scanner.state != .poweredOn {
                Label(stateText, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }

            if scanner.connectedID != nil {
                connectedSection
            } else {
                scanSection
            }
        }
        .navigationTitle("Bluetooth Test")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            scanner.stopScan()
            scanner.disconnect()
        }
    }

    var stateText: LocalizedStringKey {
        switch scanner.state {
        case .poweredOff: return "Bluetooth is off."
        case .unauthorized: return "Bluetooth access denied – allow it in Settings."
        case .unsupported: return "Bluetooth LE not supported."
        default: return "Waiting for Bluetooth …"
        }
    }

    @ViewBuilder
    var scanSection: some View {
        Section(footer: Text("Close the Ooni app first (or disconnect the hub there) – the hub usually accepts only one connection.")) {
            Button(scanner.isScanning ? "Stop scan" : "Start scan",
                   systemImage: scanner.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right") {
                scanner.isScanning ? scanner.stopScan() : scanner.startScan()
            }
            .disabled(scanner.state != .poweredOn)
            TextField("Name filter", text: $filter)
                .textInputAutocapitalization(.never)
            Toggle("Show unnamed devices", isOn: $showUnnamed)
        }
        Section("Devices (\(visibleDevices.count))") {
            ForEach(visibleDevices) { device in
                Button {
                    scanner.connect(device)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name.isEmpty ? "(no name)" : device.name).font(.headline)
                            Text(device.id.uuidString).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(device.rssi) dBm").font(.caption).monospacedDigit()
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    var connectedSection: some View {
        Section {
            Text(scanner.connectionStatus)
            HStack {
                Button("Read again", systemImage: "arrow.clockwise") { scanner.readAgain() }
                    .buttonStyle(.bordered)
                Spacer()
                ShareLink(item: scanner.exportText) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Disconnect", systemImage: "xmark.circle", role: .destructive) { scanner.disconnect() }
                    .buttonStyle(.bordered)
            }
            .labelStyle(.iconOnly)
        } footer: {
            Text("Change the probe temperature (hand, hot water) and watch which bytes turn orange.")
        }

        Section("Characteristics") {
            ForEach(scanner.characteristics.values.sorted { ($0.updateCount, $0.id) > ($1.updateCount, $1.id) }) { info in
                CharacteristicRow(info: info)
            }
        }

        Section("Log (\(scanner.log.count))") {
            ForEach(scanner.log.prefix(100)) { entry in
                VStack(alignment: .leading) {
                    Text("\(entry.date, format: .dateTime.hour().minute().second()) · …\(String(entry.characteristic.suffix(8)))")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(entry.data.hexString).font(.system(.caption, design: .monospaced))
                }
            }
        }
    }
}

struct CharacteristicRow: View {
    var info: BLEScanner.CharacteristicInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.uuid).font(.system(.caption, design: .monospaced)).bold()
            Text("Service \(info.serviceUUID)").font(.caption2).foregroundStyle(.secondary)
            Text("\(info.properties) · \(info.updateCount) updates").font(.caption2).foregroundStyle(.secondary)
            if let value = info.value {
                highlightedHex(value, previous: info.previousValue)
                if let text = String(data: value, encoding: .utf8), text.allSatisfy({ !$0.isASCII || $0.isLetter || $0.isNumber || $0.isPunctuation || $0 == " " }) {
                    Text("Text: \(text)").font(.caption2)
                }
                if value.count >= 2 {
                    Text("LE int: " + value.int16LittleEndian.map(String.init).joined(separator: " | "))
                        .font(.system(.caption2, design: .monospaced))
                }
                let guesses = value.temperatureGuesses
                if !guesses.littleEndian.isEmpty {
                    Text("LE/10: " + guesses.littleEndian.map { String(format: "%.1f", $0) }.joined(separator: " | "))
                        .font(.system(.caption2, design: .monospaced))
                    Text("BE/10: " + guesses.bigEndian.map { String(format: "%.1f", $0) }.joined(separator: " | "))
                        .font(.system(.caption2, design: .monospaced))
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Geänderte Bytes orange markieren
    private func highlightedHex(_ data: Data, previous: Data?) -> Text {
        let bytes = [UInt8](data)
        let old = previous.map { [UInt8]($0) } ?? []
        return bytes.enumerated().reduce(Text("")) { text, item in
            let (index, byte) = item
            let changed = index < old.count && old[index] != byte
            let part = Text(String(format: "%02X ", byte))
                .foregroundStyle(changed ? Color.orange : Color.primary)
            return Text("\(text)\(part)")
        }
        .font(.system(.callout, design: .monospaced))
    }
}

#Preview {
    NavigationStack { BLEDebugView() }
}
