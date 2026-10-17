//
//  OvenMonitor.swift
//  mgPizza_mk1
//

import Combine
import CoreBluetooth
import SwiftUI
import UserNotifications

/// Datenformat des Ooni Digital Temperature Hub (ermittelt mit der Bluetooth-Testansicht).
///
/// Notify-Characteristic 69400002, 22 Bytes, z. B.:
/// `91 00 1E 00 00 00 00 00 00 00 4E 03 1A 33 14 17 29 FD 26 00 00 00`
/// - Byte 0–1: Kennung/Status (unbekannt, bisher immer 91 00)
/// - Byte 2–3: Fühler 1 in ganzen °C (Int16, Little Endian) -> 0x001E = 30 °C
/// - Byte 4–5: vermutlich Fühler 2 (00 00 = nicht eingesteckt)
/// - Byte 6–9: unbekannt (evtl. weitere Fühler)
/// - Byte 10–21: unbekannt, bisher konstant
enum OoniHub {
    static let serviceUUID = CBUUID(string: "69400001-B5A3-F393-E0A9-E50E24DCCA99")
    static let temperatureUUID = CBUUID(string: "69400002-B5A3-F393-E0A9-E50E24DCCA99")
    static let probeCount = 2

    /// nil = Fühler nicht eingesteckt
    static func parse(_ data: Data) -> [Double?] {
        let bytes = [UInt8](data)
        return (0..<probeCount).map { probe in
            let index = 2 + probe * 2
            guard index + 1 < bytes.count else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8)
            return raw == 0 ? nil : Double(raw)
        }
    }
}

/// Verbindet sich mit dem Ooni-Hub, zeigt die Temperaturen und meldet, wenn die Zieltemperatur erreicht ist.
class OvenMonitor: NSObject, ObservableObject {
    @Published var state: CBManagerState = .unknown
    @Published var status: String = ""
    @Published var isActive = false
    @Published var temperatures: [Double?] = Array(repeating: nil, count: OoniHub.probeCount)
    @Published var lastUpdate: Date?

    @AppStorage("ovenTarget0") var target0: Double = 400 { willSet { objectWillChange.send() } }
    @AppStorage("ovenTarget1") var target1: Double = 450 { willSet { objectWillChange.send() } }
    @AppStorage("ovenAlarm0") var alarm0: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("ovenAlarm1") var alarm1: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("ovenSpeakAlarm") var speakAlarm: Bool = false { willSet { objectWillChange.send() } }

    /// Hysterese: erneut melden erst, wenn die Temperatur wieder so weit unter das Ziel gefallen ist
    private let rearmDelta: Double = 20
    private var alarmFired: [Bool] = Array(repeating: false, count: OoniHub.probeCount)

    private var central: CBCentralManager?
    private var hub: CBPeripheral?

    func target(_ probe: Int) -> Double { probe == 0 ? target0 : target1 }
    func isAlarmOn(_ probe: Int) -> Bool { probe == 0 ? alarm0 : alarm1 }

    func start() {
        isActive = true
        alarmFired = Array(repeating: false, count: OoniHub.probeCount)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        if speakAlarm { OvenSpeaker.shared.activateSession() }
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            scan()
        }
    }

    func stop() {
        isActive = false
        central?.stopScan()
        if let hub { central?.cancelPeripheralConnection(hub) }
        hub = nil
        status = String(localized: "Stopped")
        temperatures = Array(repeating: nil, count: OoniHub.probeCount)
    }

    private func scan() {
        guard isActive, let central, central.state == .poweredOn else { return }
        // Bereits verbundenen Hub (z. B. nach App-Neustart) wiederverwenden
        if let known = central.retrieveConnectedPeripherals(withServices: [OoniHub.serviceUUID]).first {
            connect(known)
            return
        }
        status = String(localized: "Searching for Ooni hub …")
        central.scanForPeripherals(withServices: [OoniHub.serviceUUID])
    }

    private func connect(_ peripheral: CBPeripheral) {
        central?.stopScan()
        hub = peripheral
        peripheral.delegate = self
        status = String(localized: "Connecting …")
        central?.connect(peripheral)
    }

    private func checkAlarms() {
        for probe in 0..<OoniHub.probeCount {
            guard let temp = temperatures[probe] else { continue }
            let target = target(probe)
            if !alarmFired[probe], isAlarmOn(probe), temp >= target {
                alarmFired[probe] = true
                notify(probe: probe, temperature: temp)
            } else if alarmFired[probe], temp < target - rearmDelta {
                alarmFired[probe] = false
            }
        }
    }

    /// Bei Änderung des Ziels darf wieder gemeldet werden
    func rearm(_ probe: Int) {
        alarmFired[probe] = false
        checkAlarms()
    }

    private func notify(probe: Int, temperature: Double) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Oven is ready 🔥")
        content.body = String(localized: "Probe \(probe + 1) reached \(Int(temperature)) °C (target \(Int(target(probe))) °C).")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "oven-\(probe)", content: content, trigger: nil))
        if speakAlarm {
            OvenSpeaker.shared.announce(String(localized: "Attention: the pizza oven has reached \(Int(temperature)) degrees."))
        }
    }
}

extension OvenMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        if central.state == .poweredOn {
            scan()
        } else {
            status = String(localized: "Bluetooth not available")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = String(localized: "Connected")
        peripheral.discoverServices([OoniHub.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        status = String(localized: "Connection failed – retrying …")
        hub = nil
        scan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard isActive else { return }
        status = String(localized: "Connection lost – reconnecting …")
        // connect() ohne Timeout: iOS verbindet automatisch, sobald der Hub wieder erreichbar ist
        central.connect(peripheral)
    }
}

extension OvenMonitor: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.filter { $0.uuid == OoniHub.serviceUUID }.forEach {
            peripheral.discoverCharacteristics([OoniHub.temperatureUUID], for: $0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        service.characteristics?.filter { $0.uuid == OoniHub.temperatureUUID }.forEach {
            peripheral.setNotifyValue(true, for: $0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == OoniHub.temperatureUUID, let data = characteristic.value else { return }
        temperatures = OoniHub.parse(data)
        lastUpdate = Date()
        checkAlarms()
    }
}
