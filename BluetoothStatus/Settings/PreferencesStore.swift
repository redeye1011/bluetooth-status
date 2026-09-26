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

    private func key(for type: PeripheralType) -> String {
        switch type {
        case .keyboard: "keyboardAddress"
        case .mouse: "mouseAddress"
        case .speaker: "speakerAddress"
        }
    }

    private func visibilityKey(for type: PeripheralType) -> String {
        switch type {
        case .keyboard: "keyboardVisible"
        case .mouse: "mouseVisible"
        case .speaker: "speakerVisible"
        }
    }
}
