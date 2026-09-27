import Foundation

struct SystemProfilerSnapshot {
    let poweredOn: Bool
    let devices: [PairedDevice]
    let connectedAddresses: Set<String>
    let batteryPercentByAddress: [String: Int]

    static func parse(_ data: Data) -> Self? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let bluetooth = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
            let controller = bluetooth["controller_properties"] as? [String: Any]
        else { return nil }

        var devices: [PairedDevice] = []
        var connectedAddresses: Set<String> = []
        var batteryPercentByAddress: [String: Int] = [:]
        for (key, connected) in [("device_connected", true), ("device_not_connected", false)] {
            for group in bluetooth[key] as? [[String: [String: Any]]] ?? [] {
                for (name, details) in group {
                    guard let address = details["device_address"] as? String else { continue }
                    let cleanName = name.trimmingCharacters(in: .whitespaces)
                    devices.append(PairedDevice(
                        id: address,
                        name: cleanName,
                        audioKind: AudioKind.identify(minorType: details["device_minorType"] as? String, name: cleanName)
                    ))
                    if connected {
                        connectedAddresses.insert(address)
                        if let raw = details["device_batteryLevelMain"] as? String {
                            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                            let digits = value.hasSuffix("%") ? String(value.dropLast()) : value
                            if let percent = Int(digits), (0...100).contains(percent) {
                                batteryPercentByAddress[address] = percent
                            }
                        }
                    }
                }
            }
        }
        return Self(
            poweredOn: controller["controller_state"] as? String == "attrib_on",
            devices: devices,
            connectedAddresses: connectedAddresses,
            batteryPercentByAddress: batteryPercentByAddress
        )
    }
}

enum SystemProfilerBluetooth {
    static func read() -> SystemProfilerSnapshot? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return SystemProfilerSnapshot.parse(data)
    }
}
