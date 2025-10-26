import Foundation
import CoreBluetooth
import Combine

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
    let identifier: UUID
}


class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralBE: CBCentralManager!
    var logCallback: ((String) -> Void)?

    @Published var isSwitchedOn = false
    @Published var peripherals = [Peripheral]()
    @Published var isConnected = false
    @Published var receivedData = ""
    @Published var connectionStatus = "Disconnected"

    var peripheralsId = [UUID]()
    var thermometer: CBPeripheral!
    var writeCharacteristic: CBCharacteristic?
    var controlCharacteristic: CBCharacteristic?

    var serviceId: CBUUID { CBUUID(string: Environment.shared.get("BLE_SERVICE_UUID", defaultValue: "00000001-710e-4a5b-8d75-3e5b444b3c3f")) }
    var readNotify: CBUUID { CBUUID(string: Environment.shared.get("BLE_NOTIFY_UUID", defaultValue: "00000002-710e-4a5b-8d75-3e5b444b3c3f")) }
    var readWrite: CBUUID { CBUUID(string: Environment.shared.get("BLE_WRITE_UUID", defaultValue: "00000003-710e-4a5b-8d75-3e5b444b3c3f")) }
    var controlChar: CBUUID { CBUUID(string: Environment.shared.get("BLE_CONTROL_UUID", defaultValue: "00000004-710e-4a5b-8d75-3e5b444b3c3f")) }
    var esp32DeviceName: String { Environment.shared.get("ESP32_DEVICE_NAME", defaultValue: "Thermometer") }

    override init() {
        super.init()
        centralBE = CBCentralManager(delegate: self, queue: nil)
        centralBE.delegate = self
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
            if !isConnected {
                connectionStatus = "Ready to connect"
            }
            logCallback?("Bluetooth turned ON")
        }
        else {
            isSwitchedOn = false
            connectionStatus = "Bluetooth OFF"
            logCallback?("Bluetooth turned OFF")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var peripheralName: String!

        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            peripheralName = name
            let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue, identifier: peripheral.identifier)
            if !peripheralsId.contains(peripheral.identifier) && peripheralName == esp32DeviceName {
                peripheralsId.append(peripheral.identifier)
                peripherals.append(newPeripheral)
                stopScanning()
                self.thermometer = peripheral
                self.thermometer.delegate = self
                self.centralBE.connect(peripheral, options: nil)
                connectionStatus = "Connecting to \(peripheralName ?? "Unknown")..."
                logCallback?("Found ESP32 device: \(peripheralName ?? "Unknown"), connecting...")
            }
        }
        else {
            peripheralName = "Unknown"
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to ESP32")
        isConnected = true
        connectionStatus = "Connected to \(peripheral.name ?? "ESP32")"
        logCallback?("Successfully connected to ESP32")
        discoverServices(peripheral: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("❌ Disconnected from ESP32")
        isConnected = false
        connectionStatus = isSwitchedOn ? "Ready to connect" : "Bluetooth OFF"
        writeCharacteristic = nil
        controlCharacteristic = nil
        logCallback?("Disconnected from ESP32")
    }

    func startScanning() {
        print("🔍 Starting BLE scan...")
        peripherals.removeAll()
        peripheralsId.removeAll()
        connectionStatus = "Scanning..."
        logCallback?("Started scanning for BLE devices")
        centralBE.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        print("⏹️ Stopped BLE scanning")
        logCallback?("Stopped scanning for BLE devices")
        centralBE.stopScan()
    }

    func sendToESP32(_ message: String) {
        guard let peripheral = thermometer,
              let characteristic = writeCharacteristic,
              isConnected else {
            print("❌ Cannot send message: Not connected or no write characteristic")
            return
        }

        guard let data = message.data(using: .utf8) else {
            print("❌ Failed to encode message")
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("📤 Sent message to ESP32: \(message)")
        logCallback?("Sent message to ESP32: \(message)")
    }

    func sendControlToESP32(_ command: String) {
        guard let peripheral = thermometer,
              let characteristic = controlCharacteristic,
              isConnected else {
            print("❌ Cannot send control command: Not connected or no control characteristic")
            return
        }

        guard let data = command.data(using: .utf8) else {
            print("❌ Failed to encode control command")
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("🎛️ Sent control command to ESP32: \(command)")
        logCallback?("Sent control command to ESP32: \(command)")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for char in characteristics {
            print("📋 Found characteristic: \(char.uuid.uuidString)")

            if char.uuid == readWrite {
                writeCharacteristic = char
                print("✏️ Write characteristic ready")
            } else if char.uuid == controlChar {
                controlCharacteristic = char
                print("🎛️ Control characteristic ready")
            } else if char.uuid == readNotify {
                peripheral.setNotifyValue(true, for: char)
                print("🔔 Subscribed to notifications")
            }

            peripheral.readValue(for: char)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Read error: \(error.localizedDescription)")
            return
        }

        if let data = characteristic.value,
           let stringValue = String(data: data, encoding: .utf8) {
            receivedData = stringValue
            print("📨 Received from ESP32: \(stringValue)")
            logCallback?("Received from ESP32: \(stringValue)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Write error: \(error.localizedDescription)")
        } else {
            print("✅ Data sent successfully to ESP32")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        characteristic.descriptors?.forEach { desc in
            print("🔍 Descriptor: \(desc.uuid.uuidString)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("🔄 Services modified")
    }

    func disconnect(peripheral: CBPeripheral) {
        centralBE.cancelPeripheralConnection(peripheral)
    }

    func discoverServices(peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceId])
    }

    func discoverCharacteristics(peripheral: CBPeripheral) {
        guard let services = peripheral.services else {
            print("❌ No services found")
            return
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Service discovery error: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("❌ No services discovered")
            return
        }

        print("🔍 Discovered \(services.count) services")
        if services.count > 0 {
            discoverCharacteristics(peripheral: peripheral)
        }
    }

    func subscribeToNotifications(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Notification error: \(error.localizedDescription)")
            return
        }
        print("🔔 Notification state updated for \(characteristic.uuid.uuidString)")
    }

    func readValue(characteristic: CBCharacteristic) {
        self.thermometer?.readValue(for: characteristic)
    }
}
