# Bluetooth Status

A small native macOS 13+ menu-bar app for a Bluetooth keyboard, mouse, and optional speaker. Each device has its own icon and connection state. The app has no Dock icon, daemon, network service, or reconnect action.

## Use

Click any Bluetooth Status icon in the menu bar to see the selected device name and status, open Settings, toggle Launch at Login, or quit. Device names and status text remain readable in the dark menu.

Click a connected icon to see the device's battery percentage in its menu when macOS reports it. Devices without a readable battery percentage show no battery row.

In Settings, assign paired devices by Bluetooth address rather than by a name guess. You can show or hide each of the three icons independently. If all are hidden, reopen Bluetooth Status from Spotlight or Finder to access Settings. Assignments remain saved when an icon is hidden. One icon family and one status style apply to all three devices.

| Status style | Connected | Disconnected | Unavailable |
| --- | --- | --- | --- |
| Outline / Fill | filled | outlined | gray |
| Black / White | white badge | black badge | gray |
| Red / Green | green | red | gray |

Icon families are SF Symbols, [A Solid](Design/MenuIconOptions/A-solid.png), [B Outline](Design/MenuIconOptions/B-outline.png), and [C Rounded](Design/MenuIconOptions/C-rounded.png). The selected app-icon artwork is in [Design/AppIcon](Design/AppIcon).

The app reads paired-device state at startup, reacts to Bluetooth connection events, rescans after wake, and reconciles every 30 seconds. HID and Core Audio changes can also trigger a scan. A process-held lock prevents a second instance from starting, even when the executable is launched directly.

## Build and test

Requirements: macOS 13 or newer, Xcode with the macOS SDK. Open `BluetoothStatus.xcodeproj` in Xcode, or use:

```sh
xcodebuild test -project BluetoothStatus.xcodeproj -scheme BluetoothStatus \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO

xcodebuild build -project BluetoothStatus.xcodeproj -scheme BluetoothStatus \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO
```

`project.yml` is the XcodeGen source of truth. After adding or removing source files, run `xcodegen generate --spec project.yml` and commit the generated `BluetoothStatus.xcodeproj`.

Run `./scripts/package.sh` to build an arm64 Release app and create a ZIP, DMG, and SHA-256 checksums under a new `dist/BluetoothStatus-<version>-*` directory. The script verifies the app signature, architecture, menu-bar setting, ZIP, and DMG. These packages are ad-hoc signed local previews; public distribution needs Developer ID signing and notarization.

For a local installation, quit any running copy before replacing it:

```sh
ditto ./DerivedData/Build/Products/Release/BluetoothStatus.app /Applications/BluetoothStatus.app
codesign --force --deep --sign - /Applications/BluetoothStatus.app
open -a /Applications/BluetoothStatus.app
```

The `dist/` directory is an untracked local build artifact, not part of this repository. The command above creates an ad-hoc signed local app; distribution outside your own Mac requires appropriate Developer ID signing and notarization. Install in `/Applications` before enabling Launch at Login. macOS may require approval in System Settings → Login Items.

## Project layout

- `BluetoothStatus/Bluetooth/`: local Bluetooth snapshot and event triggers.
- `BluetoothStatus/StatusBar/`: independent menu-bar items and icon rendering.
- `BluetoothStatus/Settings/`: device selection, visibility, styles, and preferences.
- `BluetoothStatus/Services/`: launch-at-login and single-instance support.
- `BluetoothStatusTests/`: state, icon, parser, preference, and singleton tests.
- `Design/`: menu icon option boards and selected app-icon source.

No device identifiers or connection history are sent to a server. Preferences are stored locally in macOS UserDefaults.
