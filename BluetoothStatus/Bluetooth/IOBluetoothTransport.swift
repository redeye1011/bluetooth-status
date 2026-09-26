import Foundation
import IOBluetooth
import IOKit.hid
import CoreAudio

final class IOBluetoothTransport: NSObject, BluetoothTransport {
    private let worker = DispatchQueue(label: "BluetoothStatus.snapshot", qos: .utility)
    private let legacyWorker = DispatchQueue(label: "BluetoothStatus.IOBluetooth", qos: .utility)
    private let cacheLock = NSLock()
    private var cachedDevices: [PairedDevice] = []
    private var cachedConnections: Set<String> = []
    private var cachedPower = false

    private var onEvent: ((String?) -> Void)?
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var powerObservers: [NSObjectProtocol] = []
    private var hidManager: IOHIDManager?
    private var audioListener: AudioObjectPropertyListenerBlock?

    var isPoweredOn: Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedPower
    }

    func pairedDevices() -> [PairedDevice] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedDevices
    }

    func isConnected(address: String) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedConnections.contains(address)
    }

    func start(onEvent: @escaping (String?) -> Void) {
        guard self.onEvent == nil else { return }
        self.onEvent = onEvent
        for name: Notification.Name in [
            .IOBluetoothHostControllerPoweredOn,
            .IOBluetoothHostControllerPoweredOff
        ] {
            powerObservers.append(NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in self?.reconcile() })
        }
        startHIDNotifications()
        startAudioNotifications()
        reconcile()
        legacyWorker.async { [weak self] in
            guard let self else { return }
            self.connectNotification = IOBluetoothDevice.register(
                forConnectNotifications: self,
                selector: #selector(self.deviceConnected(_:device:))
            )
            for device in IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [] {
                self.registerDisconnect(for: device)
            }
        }
    }

    func reconcile() {
        worker.async { [weak self] in self?.scan(changedAddress: nil) }
    }

    func stop() {
        onEvent = nil
        powerObservers.forEach { NotificationCenter.default.removeObserver($0) }
        powerObservers.removeAll()
        if let hidManager {
            IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
            IOHIDManagerClose(hidManager, 0)
            self.hidManager = nil
        }
        if let audioListener {
            var address = audioDevicesAddress()
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, audioListener)
            self.audioListener = nil
        }
        legacyWorker.async { [weak self] in
            guard let self else { return }
            self.connectNotification?.unregister()
            self.connectNotification = nil
            self.disconnectNotifications.values.forEach { $0.unregister() }
            self.disconnectNotifications.removeAll()
        }
    }

    private func scan(changedAddress: String?) {
        guard let snapshot = SystemProfilerBluetooth.read() else {
            cacheLock.lock()
            cachedPower = false
            cacheLock.unlock()
            DispatchQueue.main.async { [weak self] in self?.onEvent?(nil) }
            return
        }
        cacheLock.lock()
        cachedPower = snapshot.poweredOn
        cachedDevices = snapshot.devices
        cachedConnections = snapshot.connectedAddresses
        cacheLock.unlock()
        DispatchQueue.main.async { [weak self] in self?.onEvent?(changedAddress) }
    }

    private func startHIDNotifications() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        let callback: IOHIDDeviceCallback = { context, _, _, device in
            guard let context else { return }
            let transport = Unmanaged<IOBluetoothTransport>.fromOpaque(context).takeUnretainedValue()
            guard
                let value = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String,
                value.localizedCaseInsensitiveContains("Bluetooth")
            else { return }
            transport.reconcile()
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerSetDeviceMatching(manager, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, callback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, callback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
        IOHIDManagerOpen(manager, 0)
        hidManager = manager
    }

    private func startAudioNotifications() {
        var address = audioDevicesAddress()
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.reconcile() }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) == noErr {
            audioListener = listener
        }
    }

    private func audioDevicesAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func registerDisconnect(for device: IOBluetoothDevice) {
        guard let address = device.addressString, disconnectNotifications[address] == nil else { return }
        disconnectNotifications[address] = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        legacyWorker.async { [weak self] in self?.registerDisconnect(for: device) }
        worker.async { [weak self] in self?.scan(changedAddress: device.addressString) }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        worker.async { [weak self] in self?.scan(changedAddress: device.addressString) }
    }
}
