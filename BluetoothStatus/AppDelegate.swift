import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = PreferencesStore()
    private let loginItem = LoginItemManager()
    private let bluetooth = IOBluetoothTransport()
    private lazy var monitor = DeviceMonitor(preferences: preferences, bluetooth: bluetooth)
    private lazy var status = StatusBarController()
    private var settingsWindow: NSWindow?
    private var instanceLock: SingleInstanceLock?
    private var openSettingsAtLaunch = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplication(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        let lockURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.thns.BluetoothStatus.lock")
        guard let lock = SingleInstanceLock(url: lockURL) else {
            NSApp.terminate(nil)
            return
        }
        instanceLock = lock
        status.onOpenSettings = { [weak self] in self?.showSettings() }
        status.style = preferences.style
        status.iconFamily = preferences.iconFamily
        refreshStatusVisibility()
        status.onToggleLogin = { [weak self] in self?.toggleLogin() }
        status.isLoginEnabled = { [weak self] in self?.loginItem.isEnabled ?? false }
        status.loginNeedsApproval = { [weak self] in self?.loginItem.requiresApproval ?? false }
        status.onMenuOpen = { [weak self] in self?.monitor.reconcile() }
        monitor.onChange = { [weak self] state in
            guard let self else { return }
            self.status.update(state)
            self.status.setVisible(self.preferences.shouldShow(state.type, state: state.state), for: state.type)
        }
        monitor.start()

        if openSettingsAtLaunch || preferences.needsInitialSetup {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if instanceLock != nil && !hasVisibleStatusItems { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if instanceLock != nil { showSettings() }
        return false
    }

    @objc private func handleOpenApplication(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        let reason = event.paramDescriptor(forKeyword: keyAEPropData)?.typeCodeValue
        if reason == keyAELaunchedAsLogInItem || reason == keyAELaunchedAsServiceItem { return }
        if instanceLock != nil { showSettings() }
        else { openSettingsAtLaunch = true }
    }

    private var hasVisibleStatusItems: Bool {
        status.hasVisibleItems
    }

    private func showSettings() {
        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(
            preferences: preferences,
            loginItem: loginItem,
            devices: monitor.pairedDevices(),
            refreshDevices: { [weak self] in self?.monitor.pairedDevices() ?? [] },
            requestScan: { [weak self] in self?.monitor.reconcile() },
            onSaved: { [weak self] in
                self?.monitor.refresh()
                self?.status.style = self?.preferences.style ?? .color
                self?.status.iconFamily = self?.preferences.iconFamily ?? .system
                self?.status.refreshStyles()
                self?.refreshStatusVisibility()
            },
            onDone: { [weak self] in
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
            },
            onQuit: { NSApp.terminate(nil) }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Bluetooth Status"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toggleLogin() {
        if loginItem.requiresApproval {
            loginItem.openApprovalSettings()
            return
        }
        do {
            try loginItem.setEnabled(!loginItem.isEnabled)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func refreshStatusVisibility() {
        for type in PeripheralType.allCases {
            status.setVisible(preferences.shouldShow(type, state: status.state(for: type)), for: type)
        }
    }
}
