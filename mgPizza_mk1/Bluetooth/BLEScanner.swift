//
//  BLEScanner.swift
//  mgPizza_mk1
//

import Combine
import CoreBluetooth
import Foundation

/// Test-Scanner, um das Datenformat des Ooni Digital Temperature Hub herauszufinden.
class BLEScanner: NSObject, ObservableObject {
    struct Device: Identifiable {
        let id: UUID
        let peripheral: CBPeripheral
        var name: String
        var rssi: Int
        var lastSeen: Date
    }

    struct CharacteristicInfo: Identifiable {
        let id: String              // Service-UUID/Characteristic-UUID
        let serviceUUID: String
        let uuid: String
        let properties: String
        var value: Data?
        var previousValue: Data?
        var updateCount = 0
        var lastUpdate: Date?
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let date: Date
        let characteristic: String
        let data: Data
    }

    @Published var state: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var devices: [UUID: Device] = [:]
    @Published var connectedID: UUID?
    @Published var connectionStatus = ""
    @Published var characteristics: [String: CharacteristicInfo] = [:]
    @Published var log: [LogEntry] = []

    private var central: CBCentralManager!
    private var connected: CBPeripheral?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else { return }
        devices = [:]
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
    }

    func connect(_ device: Device) {
        stopScan()
        disconnect()
        characteristics = [:]
        log = []
        connected = device.peripheral
        connectedID = device.id
        connectionStatus = String(localized: "Connecting …")
        device.peripheral.delegate = self
        central.connect(device.peripheral)
    }

    func disconnect() {
        if let connected { central.cancelPeripheralConnection(connected) }
        connected = nil
        connectedID = nil
        connectionStatus = ""
    }

    func readAgain() {
        guard let connected else { return }
        connected.services?.forEach { service in
            service.characteristics?.filter { $0.properties.contains(.read) }.forEach { connected.readValue(for: $0) }
        }
    }

    /// Text-Export zum Teilen / Auswerten
    var exportText: String {
        var lines = ["Device: \(connectedID.flatMap { devices[$0]?.name } ?? "-")", "", "Characteristics:"]
        for info in characteristics.values.sorted(by: { $0.id < $1.id }) {
            lines.append("\(info.serviceUUID) / \(info.uuid) [\(info.properties)] = \(info.value?.hexString ?? "-")")
        }
        lines.append("")
        lines.append("Log:")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withTime, .withFractionalSeconds, .withColonSeparatorInTime]
        for entry in log.reversed() {
            lines.append("\(formatter.string(from: entry.date)) \(entry.characteristic) \(entry.data.hexString)")
        }
        return lines.joined(separator: "\n")
    }

    private static func describe(_ properties: CBCharacteristicProperties) -> String {
        var result: [String] = []
        if properties.contains(.read) { result.append("read") }
        if properties.contains(.write) { result.append("write") }
        if properties.contains(.writeWithoutResponse) { result.append("writeNR") }
        if properties.contains(.notify) { result.append("notify") }
        if properties.contains(.indicate) { result.append("indicate") }
        return result.joined(separator: ", ")
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        if central.state != .poweredOn { isScanning = false }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        devices[peripheral.identifier] = Device(id: peripheral.identifier, peripheral: peripheral,
                                                name: name, rssi: RSSI.intValue, lastSeen: Date())
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = String(localized: "Connected – discovering services …")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = String(localized: "Connection failed: \(error?.localizedDescription ?? "-")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral.identifier == connectedID {
            connectionStatus = String(localized: "Disconnected \(error?.localizedDescription ?? "")")
        }
    }
}

extension BLEScanner: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        connectionStatus = String(localized: "Connected")
        service.characteristics?.forEach { characteristic in
            let key = "\(service.uuid.uuidString)/\(characteristic.uuid.uuidString)"
            characteristics[key] = CharacteristicInfo(id: key, serviceUUID: service.uuid.uuidString,
                                                      uuid: characteristic.uuid.uuidString,
                                                      properties: Self.describe(characteristic.properties))
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let service = characteristic.service, let data = characteristic.value else { return }
        let key = "\(service.uuid.uuidString)/\(characteristic.uuid.uuidString)"
        if var info = characteristics[key] {
            let oldValue = info.value
            info.previousValue = oldValue
            info.value = data
            info.updateCount += 1
            info.lastUpdate = Date()
            characteristics[key] = info
        }
        log.insert(LogEntry(date: Date(), characteristic: characteristic.uuid.uuidString, data: data), at: 0)
        if log.count > 500 { log.removeLast(log.count - 500) }
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Mögliche Temperaturen: jeweils 2 Bytes als UInt16 (Little/Big Endian) geteilt durch 10
    var temperatureGuesses: (littleEndian: [Double], bigEndian: [Double]) {
        let bytes = [UInt8](self)
        var le: [Double] = [], be: [Double] = []
        var i = 0
        while i + 1 < bytes.count {
            le.append(Double(UInt16(bytes[i]) | UInt16(bytes[i + 1]) << 8) / 10.0)
            be.append(Double(UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1])) / 10.0)
            i += 2
        }
        return (le, be)
    }
}
