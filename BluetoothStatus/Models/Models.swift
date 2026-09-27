enum PeripheralType: CaseIterable {
    case keyboard
    case mouse
    case speaker

    var displayName: String {
        switch self {
        case .keyboard: "Keyboard"
        case .mouse: "Mouse"
        case .speaker: "Speaker"
        }
    }
}

enum ConnectionState: Equatable {
    case connected
    case disconnected
    case unavailable
}

enum IndicatorStyle: String, CaseIterable, Identifiable {
    case shape
    case monochrome
    case color

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shape: "Outline / Fill"
        case .monochrome: "Black / White"
        case .color: "Red / Green"
        }
    }
}

enum IconFamily: String, CaseIterable, Identifiable {
    case system
    case a
    case b
    case c

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "SF Symbols"
        case .a: "Solid"
        case .b: "Outline"
        case .c: "Rounded"
        }
    }

    func assetName(for type: PeripheralType, audioKind: AudioKind = .speaker) -> String {
        "Menu\(rawValue.uppercased())\(type == .speaker && audioKind == .headphones ? "Headphones" : type.displayName)"
    }
}

enum AudioKind: Equatable {
    case speaker
    case headphones

    static func identify(minorType: String?, name: String) -> Self {
        if let minorType {
            let value = minorType.lowercased()
            if value.contains("headphone") || value.contains("headset") || value.contains("earbud") || value.contains("earphone") || value.contains("airpod") {
                return .headphones
            }
            if value.contains("speaker") { return .speaker }
        }
        return name.localizedCaseInsensitiveContains("AirPods") ? .headphones : .speaker
    }
}

struct PairedDevice: Equatable, Identifiable {
    let id: String
    let name: String
    let audioKind: AudioKind

    init(id: String, name: String, audioKind: AudioKind = .speaker) {
        self.id = id
        self.name = name
        self.audioKind = audioKind
    }
}

struct PeripheralState: Equatable {
    let id: String
    let name: String
    let type: PeripheralType
    let state: ConnectionState
    let batteryPercent: Int?
    let audioKind: AudioKind

    init(id: String, name: String, type: PeripheralType, state: ConnectionState, batteryPercent: Int? = nil, audioKind: AudioKind = .speaker) {
        self.id = id
        self.name = name
        self.type = type
        self.state = state
        self.batteryPercent = batteryPercent
        self.audioKind = audioKind
    }
}
