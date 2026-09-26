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
        case .a: "A — Solid"
        case .b: "B — Outline"
        case .c: "C — Rounded"
        }
    }

    func assetName(for type: PeripheralType) -> String {
        "Menu\(rawValue.uppercased())\(type.displayName)"
    }
}

struct PairedDevice: Equatable, Identifiable {
    let id: String
    let name: String
}

struct PeripheralState: Equatable {
    let id: String
    let name: String
    let type: PeripheralType
    let state: ConnectionState
    let batteryPercent: Int?

    init(id: String, name: String, type: PeripheralType, state: ConnectionState, batteryPercent: Int? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.state = state
        self.batteryPercent = batteryPercent
    }
}
