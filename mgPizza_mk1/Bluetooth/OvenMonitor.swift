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
    static let namePrefix = "Ooni"

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
    /// Eine Instanz für die ganze App – wird schon beim App-Start erzeugt (wichtig für die Bluetooth-Wiederherstellung im Hintergrund)
    static let shared = OvenMonitor()

    @Published var state: CBManagerState = .unknown
    @Published var status: String = ""
    @Published var isActive = false
    @Published var temperatures: [Double?] = Array(repeating: nil, count: OoniHub.probeCount)
    @Published var lastUpdate: Date?
    /// Seit wann der Hub (vermutlich) eingeschaltet ist – er schaltet sich nach 45 Min. selbst ab
    @Published var hubOnSince: Date?

    static let hubAutoOff: TimeInterval = 45 * 60
    static let hubWarningLead: TimeInterval = 5 * 60
    private var hubWarningSent = false

    @AppStorage("ovenTarget0") var target0: Double = 400 { willSet { objectWillChange.send() } }
    @AppStorage("ovenTarget1") var target1: Double = 450 { willSet { objectWillChange.send() } }
    @AppStorage("ovenAlarm0") var alarm0: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("ovenAlarm1") var alarm1: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("ovenSpeakAlarm") var speakAlarm: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("ovenHubReminder") var hubReminder: Bool = true { willSet { objectWillChange.send() } }

    var hubOffDate: Date? { hubOnSince?.addingTimeInterval(Self.hubAutoOff) }

    /// Nach Tastendruck am Hub: 45-Minuten-Zähler neu starten
    func resetHubTimer() {
        hubOnSince = Date()
        hubWarningSent = false
    }

    private func checkHubTimer() {
        guard hubReminder, !hubWarningSent, let off = hubOffDate,
              Date() >= off.addingTimeInterval(-Self.hubWarningLead) else { return }
        hubWarningSent = true
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Temperature hub turns off soon")
        content.body = String(localized: "The Ooni hub switches off in about 5 minutes – press its power button briefly.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "oven-hub-off", content: content, trigger: nil))
        if speakAlarm {
            OvenSpeaker.shared.announce(String(localized: "The temperature hub switches off in five minutes. Please press its button."), repeats: 1)
        }
    }

    /// Hysterese: erneut melden erst, wenn die Temperatur wieder so weit unter das Ziel gefallen ist
    private let rearmDelta: Double = 20
    private var alarmFired: [Bool] = Array(repeating: false, count: OoniHub.probeCount)

    /// Zuletzt verbundener Hub, damit er direkt (auch im Hintergrund) wieder verbunden werden kann
    @AppStorage("ovenHubID") private var savedHubID: String = ""

    /// War die Überwachung aktiv? -> nach einem Neustart der App (auch durch iOS im Hintergrund) fortsetzen
    @AppStorage("ovenMonitorActive") private var wasActive: Bool = false

    private var central: CBCentralManager?
    private var hub: CBPeripheral?
    private static let restoreID = "mgPizzaOvenMonitor"

    override init() {
        super.init()
        if wasActive {
            // iOS kann die App im Hintergrund neu starten (State Restoration) – dann sofort wieder verbinden
            DispatchQueue.main.async { self.start() }
        }
    }

    private func makeCentral() -> CBCentralManager {
        // Restore-ID: iOS hält die Verbindung auch, wenn die App im Sperrbildschirm beendet wird,
        // und weckt sie bei neuen Daten wieder auf
        CBCentralManager(delegate: self, queue: .main,
                         options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreID])
    }

    func target(_ probe: Int) -> Double { probe == 0 ? target0 : target1 }
    func isAlarmOn(_ probe: Int) -> Bool { probe == 0 ? alarm0 : alarm1 }

    func start() {
        isActive = true
        wasActive = true
        alarmFired = Array(repeating: false, count: OoniHub.probeCount)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        if speakAlarm { OvenSpeaker.shared.activateSession() }
        if central == nil {
            central = makeCentral()
        } else {
            scan()
        }
    }

    func stop() {
        isActive = false
        wasActive = false
        central?.stopScan()
        if let hub { central?.cancelPeripheralConnection(hub) }
        hub = nil
        status = String(localized: "Stopped")
        hubOnSince = nil
        temperatures = Array(repeating: nil, count: OoniHub.probeCount)
    }

    private func scan() {
        guard isActive, let central, central.state == .poweredOn else { return }
        // Bereits verbundenen Hub (z. B. nach App-Neustart) wiederverwenden
        if let known = central.retrieveConnectedPeripherals(withServices: [OoniHub.serviceUUID]).first {
            connect(known)
            return
        }
        // Bekannten Hub direkt verbinden – iOS verbindet, sobald er in Reichweite ist
        if let id = UUID(uuidString: savedHubID),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(known)
        }
        // Der Hub sendet seine Service-UUID nicht in der Werbung mit, daher ohne Filter suchen
        // und nach dem Namen ("Ooni_DT_Hub") auswählen.
        // Achtung: Im Hintergrund/Sperrbildschirm liefert iOS bei einer Suche ohne Filter nichts –
        // dort hilft nur die oben gestartete Verbindung zum bekannten Hub (läuft ohne Zeitlimit).
        if hub == nil || hub?.state == .disconnected {
            status = String(localized: "Searching for Ooni hub …")
        }
        central.scanForPeripherals(withServices: nil)
    }

    private func connect(_ peripheral: CBPeripheral) {
        guard hub?.identifier != peripheral.identifier || peripheral.state == .disconnected else { return }
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
    /// iOS hat die App im Hintergrund neu gestartet und gibt die bestehende Verbindung zurück
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else { return }
        isActive = true
        hub = restored
        restored.delegate = self
        if restored.state == .connected {
            status = String(localized: "Connected")
            restored.discoverServices([OoniHub.serviceUUID])
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        if central.state == .poweredOn {
            if let hub, hub.state == .connected {
                // Nach Wiederherstellung: Benachrichtigungen erneut abonnieren
                hub.discoverServices([OoniHub.serviceUUID])
            } else {
                scan()
            }
        } else {
            status = String(localized: "Bluetooth not available")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        guard name.hasPrefix(OoniHub.namePrefix) || services.contains(OoniHub.serviceUUID) else { return }
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        central.stopScan()
        savedHubID = peripheral.identifier.uuidString
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
        // Hub vermutlich aus – beim nächsten Verbinden startet der 45-Minuten-Zähler neu
        hubOnSince = nil
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
        if hubOnSince == nil { resetHubTimer() }
        checkAlarms()
        checkHubTimer()
    }
}
