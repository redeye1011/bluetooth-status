import AppKit

protocol BluetoothTransport: AnyObject {
    var isPoweredOn: Bool { get }
    func pairedDevices() -> [PairedDevice]
    func isConnected(address: String) -> Bool
    func batteryPercent(address: String) -> Int?
    func requestBattery(address: String, force: Bool)
    func start(onEvent: @escaping (String?) -> Void)
    func reconcile()
    func stop()
}

@MainActor
final class DeviceMonitor {
    var onChange: ((PeripheralState) -> Void)?

    private let preferences: PreferencesStore
    private let bluetooth: BluetoothTransport
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var running = false
    private var lastStates: [PeripheralType: PeripheralState] = [:]

    init(preferences: PreferencesStore, bluetooth: BluetoothTransport) {
        self.preferences = preferences
        self.bluetooth = bluetooth
    }

    func start() {
        guard !running else { return }
        running = true
        lastStates.removeAll()
        bluetooth.start { [weak self] address in
            self?.refresh(address: address)
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.bluetooth.reconcile() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard self?.running == true else { return }
                self?.bluetooth.reconcile()
            }
        }
    }

    func stop() {
        guard running else { return }
        running = false
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        bluetooth.stop()
    }

    func pairedDevices() -> [PairedDevice] {
        bluetooth.pairedDevices().sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func reconcile() {
        bluetooth.reconcile()
    }

    func refresh(address: String? = nil) {
        let paired = Dictionary(bluetooth.pairedDevices().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for type in PeripheralType.allCases {
            let selected = preferences.address(for: type)
            if let address, normalized(address) != selected.map(normalized) { continue }
            let device = selected.flatMap { paired[$0] }
            let state: ConnectionState
            if !bluetooth.isPoweredOn || device == nil {
                state = .unavailable
            } else if let device, bluetooth.isConnected(address: device.id) {
                state = .connected
            } else {
                state = .disconnected
            }
            let peripheral = PeripheralState(
                id: selected ?? "",
                name: device?.name ?? type.displayName,
                type: type,
                state: state,
                batteryPercent: state == .connected ? device.flatMap { bluetooth.batteryPercent(address: $0.id) } : nil,
                audioKind: device?.audioKind ?? .speaker
            )
            if state == .connected, let device {
                bluetooth.requestBattery(address: device.id, force: lastStates[type]?.state != .connected)
            }
            if lastStates[type] != peripheral {
                lastStates[type] = peripheral
                onChange?(peripheral)
            }
        }
    }

    private func normalized(_ address: String) -> String {
        address.filter { $0.isHexDigit }.uppercased()
    }
}
