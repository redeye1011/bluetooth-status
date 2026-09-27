import Foundation

final class PreferencesStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func address(for type: PeripheralType) -> String? {
        defaults.string(forKey: key(for: type))
    }

    func setAddress(_ address: String?, for type: PeripheralType) {
        defaults.set(address, forKey: key(for: type))
    }

    func isVisible(_ type: PeripheralType) -> Bool {
        let key = visibilityKey(for: type)
        return defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
    }

    func setVisible(_ visible: Bool, for type: PeripheralType) {
        defaults.set(visible, forKey: visibilityKey(for: type))
    }

    func hidesWhenDisconnected(_ type: PeripheralType) -> Bool {
        let key = hideWhenDisconnectedKey(for: type)
        if defaults.object(forKey: key) == nil { return type == .speaker || type == .headphones }
        return defaults.bool(forKey: key)
    }

    func setHideWhenDisconnected(_ hide: Bool, for type: PeripheralType) {
        defaults.set(hide, forKey: hideWhenDisconnectedKey(for: type))
    }

    func shouldShow(_ type: PeripheralType, state: ConnectionState) -> Bool {
        isVisible(type) && (!hidesWhenDisconnected(type) || state == .connected)
    }

    var style: IndicatorStyle {
        IndicatorStyle(rawValue: defaults.string(forKey: "indicatorStyle") ?? "") ?? .color
    }

    func setStyle(_ style: IndicatorStyle) {
        defaults.set(style.rawValue, forKey: "indicatorStyle")
    }

    var iconFamily: IconFamily {
        IconFamily(rawValue: defaults.string(forKey: "iconFamily") ?? "") ?? .system
    }

    func setIconFamily(_ family: IconFamily) {
        defaults.set(family.rawValue, forKey: "iconFamily")
    }

    var needsInitialSetup: Bool {
        [.keyboard, .mouse].contains { isVisible($0) && address(for: $0) == nil }
    }

    func migrateLegacyHeadphones(using devices: [PairedDevice]) {
        guard let oldAddress = address(for: .speaker),
              devices.contains(where: { $0.id == oldAddress && $0.audioKind == .headphones }) else { return }
        if address(for: .headphones) == nil {
            setAddress(oldAddress, for: .headphones)
            for (oldKey, newKey) in [(visibilityKey(for: .speaker), visibilityKey(for: .headphones)),
                                     (hideWhenDisconnectedKey(for: .speaker), hideWhenDisconnectedKey(for: .headphones))] {
                if defaults.object(forKey: newKey) == nil, let value = defaults.object(forKey: oldKey) {
                    defaults.set(value, forKey: newKey)
                }
                defaults.removeObject(forKey: oldKey)
            }
        }
        setAddress(nil, for: .speaker)
    }

    private func key(for type: PeripheralType) -> String {
        switch type {
        case .keyboard: "keyboardAddress"
        case .mouse: "mouseAddress"
        case .speaker: "speakerAddress"
        case .headphones: "headphonesAddress"
        }
    }

    private func visibilityKey(for type: PeripheralType) -> String {
        switch type {
        case .keyboard: "keyboardVisible"
        case .mouse: "mouseVisible"
        case .speaker: "speakerVisible"
        case .headphones: "headphonesVisible"
        }
    }

    private func hideWhenDisconnectedKey(for type: PeripheralType) -> String {
        switch type {
        case .keyboard: "keyboardHideWhenDisconnected"
        case .mouse: "mouseHideWhenDisconnected"
        case .speaker: "speakerHideWhenDisconnected"
        case .headphones: "headphonesHideWhenDisconnected"
        }
    }
}
