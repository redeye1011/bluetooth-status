import XCTest
@testable import BluetoothStatus

@MainActor
final class DeviceMonitorTests: XCTestCase {
    func testMouseConnectionEventChangesOnlyMouseState() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setAddress("KEYBOARD", for: .keyboard)
        preferences.setAddress("MOUSE", for: .mouse)

        let bluetooth = FakeBluetoothTransport()
        bluetooth.devices = [
            PairedDevice(id: "KEYBOARD", name: "Keychron K2"),
            PairedDevice(id: "MOUSE", name: "MX Master 3S")
        ]
        bluetooth.connected = ["KEYBOARD"]

        let monitor = DeviceMonitor(preferences: preferences, bluetooth: bluetooth)
        var changes: [PeripheralState] = []
        monitor.onChange = { changes.append($0) }
        monitor.start()
        XCTAssertEqual(changes.map(\.state), [.connected, .disconnected, .unavailable, .unavailable])
        XCTAssertEqual(changes.last?.name, "Headphones")

        changes.removeAll()
        bluetooth.connected.insert("MOUSE")
        bluetooth.emit(address: "MOUSE")
        XCTAssertEqual(changes, [PeripheralState(id: "MOUSE", name: "MX Master 3S", type: .mouse, state: .connected)])

        changes.removeAll()
        bluetooth.emit(address: nil)
        XCTAssertTrue(changes.isEmpty, "An unchanged reconciliation should not repaint either item")

        bluetooth.isPoweredOn = false
        bluetooth.emit(address: nil)
        XCTAssertEqual(changes.map(\.state), [.unavailable, .unavailable])
        monitor.stop()
    }

    func testSpeakerEventChangesOnlySpeakerState() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setAddress("SPEAKER", for: .speaker)
        let bluetooth = FakeBluetoothTransport()
        bluetooth.devices = [PairedDevice(id: "SPEAKER", name: "JBL Boombox 2")]

        let monitor = DeviceMonitor(preferences: preferences, bluetooth: bluetooth)
        var changes: [PeripheralState] = []
        monitor.onChange = { changes.append($0) }
        monitor.start()
        XCTAssertEqual(changes.first(where: { $0.type == .speaker })?.state, .disconnected)

        changes.removeAll()
        bluetooth.connected.insert("SPEAKER")
        bluetooth.emit(address: "SPEAKER")
        XCTAssertEqual(changes, [PeripheralState(id: "SPEAKER", name: "JBL Boombox 2", type: .speaker, state: .connected)])
        monitor.stop()
    }

    func testSelectedHeadphonesHaveIndependentStateAcrossConnectionChanges() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setAddress("AIRPODS", for: .speaker)
        let bluetooth = FakeBluetoothTransport()
        bluetooth.devices = [PairedDevice(id: "AIRPODS", name: "AirPods Pro", audioKind: .headphones)]
        let monitor = DeviceMonitor(preferences: preferences, bluetooth: bluetooth)
        var changes: [PeripheralState] = []
        monitor.onChange = { changes.append($0) }
        monitor.start()
        XCTAssertNil(preferences.address(for: .speaker))
        XCTAssertEqual(preferences.address(for: .headphones), "AIRPODS")
        XCTAssertEqual(changes.last?.type, .headphones)
        XCTAssertEqual(changes.last?.state, .disconnected)

        bluetooth.connected.insert("AIRPODS")
        bluetooth.emit(address: "AIRPODS")
        XCTAssertEqual(changes.last?.type, .headphones)
        XCTAssertEqual(changes.last?.state, .connected)
        monitor.stop()
    }

    func testSpeakerAndHeadphonesShowTogetherThenSwitchWithConnections() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setAddress("SPEAKER", for: .speaker)
        preferences.setAddress("AIRPODS", for: .headphones)
        let bluetooth = FakeBluetoothTransport()
        bluetooth.devices = [
            PairedDevice(id: "SPEAKER", name: "JBL"),
            PairedDevice(id: "AIRPODS", name: "AirPods", audioKind: .headphones)
        ]
        bluetooth.connected = ["SPEAKER", "AIRPODS"]

        let monitor = DeviceMonitor(preferences: preferences, bluetooth: bluetooth)
        var changes: [PeripheralState] = []
        monitor.onChange = { changes.append($0) }
        monitor.start()
        XCTAssertEqual(changes.filter { $0.type == .speaker || $0.type == .headphones }.map(\.state), [.connected, .connected])
        XCTAssertTrue(preferences.shouldShow(.speaker, state: .connected))
        XCTAssertTrue(preferences.shouldShow(.headphones, state: .connected))

        changes.removeAll()
        bluetooth.connected.remove("AIRPODS")
        bluetooth.emit(address: "AIRPODS")
        XCTAssertEqual(changes, [PeripheralState(id: "AIRPODS", name: "AirPods", type: .headphones, state: .disconnected)])
        XCTAssertTrue(preferences.shouldShow(.speaker, state: .connected))
        XCTAssertFalse(preferences.shouldShow(.headphones, state: .disconnected))

        changes.removeAll()
        bluetooth.connected.insert("AIRPODS")
        bluetooth.connected.remove("SPEAKER")
        bluetooth.emit(address: nil)
        XCTAssertEqual(changes.map(\.type), [.speaker, .headphones])
        XCTAssertFalse(preferences.shouldShow(.speaker, state: .disconnected))
        XCTAssertTrue(preferences.shouldShow(.headphones, state: .connected))
        monitor.stop()
    }

    func testBatteryChangesUpdateOnlySelectedConnectedDevice() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setAddress("KEYBOARD", for: .keyboard)
        preferences.setAddress("MOUSE", for: .mouse)
        let bluetooth = FakeBluetoothTransport()
        bluetooth.devices = [
            PairedDevice(id: "KEYBOARD", name: "Keyboard"),
            PairedDevice(id: "MOUSE", name: "Mouse")
        ]
        bluetooth.connected = ["KEYBOARD", "MOUSE"]
        bluetooth.batteries = ["KEYBOARD": 75, "MOUSE": 60]

        let monitor = DeviceMonitor(preferences: preferences, bluetooth: bluetooth)
        var changes: [PeripheralState] = []
        monitor.onChange = { changes.append($0) }
        monitor.start()
        XCTAssertEqual(changes.prefix(2).map(\.batteryPercent), [75, 60])
        XCTAssertEqual(bluetooth.batteryRequests.map(\.1), [true, true])

        changes.removeAll()
        bluetooth.batteries["MOUSE"] = 59
        bluetooth.emit(address: "MOUSE")
        XCTAssertEqual(changes, [PeripheralState(id: "MOUSE", name: "Mouse", type: .mouse, state: .connected, batteryPercent: 59)])
        XCTAssertEqual(bluetooth.batteryRequests.last?.1, false)

        changes.removeAll()
        bluetooth.connected.remove("MOUSE")
        bluetooth.emit(address: "MOUSE")
        XCTAssertEqual(changes, [PeripheralState(id: "MOUSE", name: "Mouse", type: .mouse, state: .disconnected)])

        changes.removeAll()
        bluetooth.connected.insert("MOUSE")
        bluetooth.emit(address: "MOUSE")
        XCTAssertEqual(changes, [PeripheralState(id: "MOUSE", name: "Mouse", type: .mouse, state: .connected, batteryPercent: 59)])
        XCTAssertEqual(bluetooth.batteryRequests.last?.1, true)
        monitor.stop()
    }
}

private final class FakeBluetoothTransport: BluetoothTransport {
    var devices: [PairedDevice] = []
    var connected: Set<String> = []
    var batteries: [String: Int] = [:]
    var batteryRequests: [(String, Bool)] = []
    var isPoweredOn = true
    private var onEvent: ((String?) -> Void)?

    func pairedDevices() -> [PairedDevice] { devices }
    func isConnected(address: String) -> Bool { connected.contains(address) }
    func batteryPercent(address: String) -> Int? { batteries[address] }
    func requestBattery(address: String, force: Bool) { batteryRequests.append((address, force)) }
    func start(onEvent: @escaping (String?) -> Void) { self.onEvent = onEvent }
    func reconcile() { onEvent?(nil) }
    func stop() { onEvent = nil }
    func emit(address: String?) { onEvent?(address) }
}
