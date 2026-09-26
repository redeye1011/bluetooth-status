import CoreBluetooth
import Foundation
import IOKit.hid

final class CoreBluetoothBatteryReader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let batteryService = CBUUID(string: "180F")
    private let batteryLevel = CBUUID(string: "2A19")
    private let onValue: (String, Int?) -> Void
    private var central: CBCentralManager!
    private var pending: [String: String] = [:]
    private var processScheduled = false
    private var lastAttempt: [String: Date] = [:]
    private var active: [UUID: (address: String, peripheral: CBPeripheral, token: UUID)] = [:]

    init(onValue: @escaping (String, Int?) -> Void) {
        self.onValue = onValue
        super.init()
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func request(address: String, force: Bool) {
        let key = normalized(address)
        guard !key.isEmpty, !active.values.contains(where: { normalized($0.address) == key }) else { return }
        if !force, let lastAttempt = lastAttempt[key], Date().timeIntervalSince(lastAttempt) < 25 { return }
        lastAttempt[key] = Date()
        pending[key] = address
        guard !processScheduled else { return }
        processScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.processScheduled = false
            self?.processPending()
        }
    }

    func stop() {
        pending.removeAll()
        for request in active.values {
            request.peripheral.delegate = nil
            central.cancelPeripheralConnection(request.peripheral)
        }
        active.removeAll()
        central.delegate = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        processPending()
    }

    private func processPending() {
        guard central.state == .poweredOn, !pending.isEmpty else { return }

        // HID exposes both the saved Bluetooth address and Core Bluetooth's peripheral UUID.
        let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatching(hidManager, nil)
        let devices = IOHIDManagerCopyDevices(hidManager) as? Set<IOHIDDevice> ?? []
        var uuidsByAddress: [String: Set<UUID>] = [:]
        for device in devices {
            guard
                let address = IOHIDDeviceGetProperty(device, "DeviceAddress" as CFString) as? String,
                let uuidString = IOHIDDeviceGetProperty(device, "PhysicalDeviceUniqueID" as CFString) as? String,
                let uuid = UUID(uuidString: uuidString)
            else { continue }
            let key = normalized(address)
            if pending[key] != nil { uuidsByAddress[key, default: []].insert(uuid) }
        }

        let connected = Dictionary(
            central.retrieveConnectedPeripherals(withServices: [batteryService]).map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let requests = pending
        pending.removeAll()
        for (key, address) in requests {
            guard
                let uuids = uuidsByAddress[key], uuids.count == 1,
                let uuid = uuids.first,
                let peripheral = connected[uuid]
            else {
                onValue(address, nil)
                continue
            }
            guard active[uuid] == nil else { continue }
            let token = UUID()
            active[uuid] = (address, peripheral, token)
            central.connect(peripheral, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self, weak peripheral] in
                guard let self, let peripheral, self.active[uuid]?.token == token else { return }
                self.finish(peripheral, percent: nil)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard active[peripheral.identifier] != nil else { return }
        peripheral.delegate = self
        peripheral.discoverServices([batteryService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finish(peripheral, percent: nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        finish(peripheral, percent: nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == batteryService }) else {
            finish(peripheral, percent: nil)
            return
        }
        peripheral.discoverCharacteristics([batteryLevel], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard
            error == nil,
            let characteristic = service.characteristics?.first(where: { $0.uuid == batteryLevel }),
            characteristic.properties.contains(.read)
        else {
            finish(peripheral, percent: nil)
            return
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let data = error == nil ? characteristic.value : nil
        let percent = data?.count == 1 ? data?.first.flatMap { $0 <= 100 ? Int($0) : nil } : nil
        finish(peripheral, percent: percent)
    }

    private func finish(_ peripheral: CBPeripheral, percent: Int?) {
        guard let request = active.removeValue(forKey: peripheral.identifier) else { return }
        peripheral.delegate = nil
        onValue(request.address, percent)
        if peripheral.state != .disconnected { central.cancelPeripheralConnection(peripheral) }
    }

    private func normalized(_ address: String) -> String {
        address.filter { $0.isHexDigit }.uppercased()
    }
}
