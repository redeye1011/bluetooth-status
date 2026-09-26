import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    let speakerItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mouseItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let keyboardItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    var onOpenSettings: () -> Void = {}
    var onToggleLogin: () -> Void = {}
    var isLoginEnabled: () -> Bool = { false }
    var loginNeedsApproval: () -> Bool = { false }
    var onMenuOpen: () -> Void = {}
    var style: IndicatorStyle = .color
    var iconFamily: IconFamily = .system

    private var menus: [PeripheralType: NSMenu] = [:]
    private var lastStates: [PeripheralType: PeripheralState] = [:]

    override init() {
        super.init()
        for type in PeripheralType.allCases {
            let item = statusItem(for: type)
            item.menu = makeMenu(for: type)
            update(PeripheralState(
                id: "",
                name: type.displayName,
                type: type,
                state: .unavailable
            ))
        }
    }

    func update(_ peripheral: PeripheralState) {
        lastStates[peripheral.type] = peripheral
        let item = statusItem(for: peripheral.type)
        item.button?.image = StatusIcon.image(
            for: peripheral.type,
            state: peripheral.state,
            style: style,
            family: iconFamily,
            name: peripheral.name
        )
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.contentTintColor = nil
        item.button?.alphaValue = 1
        item.button?.toolTip = "\(peripheral.name) — \(title(for: peripheral.state))"
        item.button?.setAccessibilityLabel("\(peripheral.type.displayName): \(peripheral.name), \(title(for: peripheral.state))")

        if let menu = menus[peripheral.type] {
            menu.items[0].title = peripheral.name
            menu.items[0].attributedTitle = NSAttributedString(string: peripheral.name, attributes: [
                .foregroundColor: NSColor.textColor,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            ])
            menu.items[1].title = "● \(title(for: peripheral.state))"
            let statusTitle = NSMutableAttributedString(string: "●", attributes: [.foregroundColor: color(for: peripheral.state)])
            statusTitle.append(NSAttributedString(string: " \(title(for: peripheral.state))", attributes: [.foregroundColor: NSColor.textColor]))
            menu.items[1].attributedTitle = statusTitle
        }
    }

    func refreshStyles() {
        for state in lastStates.values { update(state) }
    }

    func setVisible(_ visible: Bool, for type: PeripheralType) {
        statusItem(for: type).isVisible = visible
    }

    func menuWillOpen(_ menu: NSMenu) {
        onMenuOpen()
        if let item = menu.items.first(where: { $0.action == #selector(toggleLogin) }) {
            item.state = isLoginEnabled() ? .on : .off
            item.title = loginNeedsApproval() ? "Launch at Login (Approve…)" : "Launch at Login"
        }
    }

    private func statusItem(for type: PeripheralType) -> NSStatusItem {
        switch type {
        case .keyboard: keyboardItem
        case .mouse: mouseItem
        case .speaker: speakerItem
        }
    }

    private func makeMenu(for type: PeripheralType) -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        let name = NSMenuItem(title: type.displayName, action: nil, keyEquivalent: "")
        let state = NSMenuItem(title: "● Unavailable", action: nil, keyEquivalent: "")
        menu.addItem(name)
        menu.addItem(state)
        menu.addItem(.separator())
        menu.addItem(actionItem("Settings…", #selector(openSettings)))
        menu.addItem(actionItem("Launch at Login", #selector(toggleLogin)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Bluetooth Status", #selector(quit)))
        menus[type] = menu
        return menu
    }

    private func actionItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    private func color(for state: ConnectionState) -> NSColor {
        switch state {
        case .connected: .systemGreen
        case .disconnected: .systemRed
        case .unavailable: .systemGray
        }
    }

    private func title(for state: ConnectionState) -> String {
        switch state {
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        case .unavailable: "Unavailable"
        }
    }

    @objc private func openSettings() { onOpenSettings() }
    @objc private func toggleLogin() { onToggleLogin() }
    @objc private func quit() { NSApp.terminate(nil) }
}
