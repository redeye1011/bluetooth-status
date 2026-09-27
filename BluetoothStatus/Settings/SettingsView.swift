import SwiftUI

struct SettingsView: View {
    @State private var keyboardAddress: String
    @State private var mouseAddress: String
    @State private var speakerAddress: String
    @State private var keyboardVisible: Bool
    @State private var mouseVisible: Bool
    @State private var speakerVisible: Bool
    @State private var indicatorStyle: IndicatorStyle
    @State private var iconFamily: IconFamily
    @State private var launchAtLogin: Bool
    @State private var devices: [PairedDevice]
    @State private var errorMessage: String?

    let preferences: PreferencesStore
    let loginItem: LoginItemManager
    let refreshDevices: () -> [PairedDevice]
    let requestScan: () -> Void
    let onSaved: () -> Void
    let onDone: () -> Void

    init(
        preferences: PreferencesStore,
        loginItem: LoginItemManager,
        devices: [PairedDevice],
        refreshDevices: @escaping () -> [PairedDevice],
        requestScan: @escaping () -> Void,
        onSaved: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.loginItem = loginItem
        self.refreshDevices = refreshDevices
        self.requestScan = requestScan
        self.onSaved = onSaved
        self.onDone = onDone
        _keyboardAddress = State(initialValue: preferences.address(for: .keyboard) ?? "")
        _mouseAddress = State(initialValue: preferences.address(for: .mouse) ?? "")
        _speakerAddress = State(initialValue: preferences.address(for: .speaker) ?? "")
        _keyboardVisible = State(initialValue: preferences.isVisible(.keyboard))
        _mouseVisible = State(initialValue: preferences.isVisible(.mouse))
        _speakerVisible = State(initialValue: preferences.isVisible(.speaker))
        _indicatorStyle = State(initialValue: preferences.style)
        _iconFamily = State(initialValue: preferences.iconFamily)
        _launchAtLogin = State(initialValue: loginItem.isRequested)
        _devices = State(initialValue: devices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bluetooth Status").font(.title2).bold()

            VStack(spacing: 12) {
                HStack {
                    Text("Keyboard").frame(width: 80, alignment: .trailing)
                    Picker("Keyboard", selection: $keyboardAddress) {
                        Text("Select a device").tag("")
                        ForEach(devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                }
                HStack {
                    Text("Mouse").frame(width: 80, alignment: .trailing)
                    Picker("Mouse", selection: $mouseAddress) {
                        Text("Select a device").tag("")
                        ForEach(devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                }
                HStack {
                    Text("Audio").frame(width: 80, alignment: .trailing)
                    Picker("Audio", selection: $speakerAddress) {
                        Text("Select a device").tag("")
                        ForEach(devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Visible in menu bar")
                    HStack(spacing: 12) {
                        Toggle("Keyboard", isOn: $keyboardVisible)
                        Toggle("Mouse", isOn: $mouseVisible)
                        Toggle("Audio", isOn: $speakerVisible)
                    }
                    .toggleStyle(.checkbox)
                }
                HStack {
                    Text("Style").frame(width: 80, alignment: .trailing)
                    Picker("Style", selection: $indicatorStyle) {
                        ForEach(IndicatorStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                }
                HStack {
                    Text("Icons").frame(width: 80, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Icons", selection: $iconFamily) {
                            ForEach(IconFamily.allCases) { family in
                                Text(family.displayName).tag(family)
                            }
                        }
                        .labelsHidden()
                        HStack(spacing: 16) {
                            ForEach(PeripheralType.allCases, id: \.self) { type in
                                if let preview = StatusIcon.image(
                                    for: type,
                                    state: .connected,
                                    style: indicatorStyle,
                                    family: iconFamily,
                                    name: type.displayName,
                                    audioKind: type == .speaker ? devices.first(where: { $0.id == speakerAddress })?.audioKind ?? .speaker : .speaker
                                ) {
                                    Image(nsImage: preview)
                                        .resizable()
                                        .frame(width: 20, height: 18)
                                        .accessibilityLabel(type.displayName)
                                }
                            }
                        }
                    }
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .padding(.leading, 80)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }
            if loginItem.requiresApproval {
                Button("Approve in Login Items…") { loginItem.openApprovalSettings() }
            }

            HStack {
                Button("Refresh Devices") { requestScan() }
                Spacer()
                Button("Done", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 390)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let updated = refreshDevices()
            if devices != updated { devices = updated }
        }
    }

    private func save() {
        preferences.setAddress(keyboardAddress.isEmpty ? nil : keyboardAddress, for: .keyboard)
        preferences.setAddress(mouseAddress.isEmpty ? nil : mouseAddress, for: .mouse)
        preferences.setAddress(speakerAddress.isEmpty ? nil : speakerAddress, for: .speaker)
        preferences.setVisible(keyboardVisible, for: .keyboard)
        preferences.setVisible(mouseVisible, for: .mouse)
        preferences.setVisible(speakerVisible, for: .speaker)
        preferences.setStyle(indicatorStyle)
        preferences.setIconFamily(iconFamily)
        onSaved()
        do {
            try loginItem.setEnabled(launchAtLogin)
            if launchAtLogin && loginItem.requiresApproval {
                errorMessage = "Approve Bluetooth Status in System Settings to launch at login."
            } else {
                onDone()
            }
        } catch {
            errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }
}
