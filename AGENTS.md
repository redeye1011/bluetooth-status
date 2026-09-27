# AGENTS.md

This repository is a native macOS menu-bar utility. Keep changes small, local, and testable.

## Source of truth

- `project.yml` defines the Xcode project. Regenerate `BluetoothStatus.xcodeproj` with `xcodegen generate --spec project.yml` after changing its source-file set.
- AppKit owns status items and menus; SwiftUI owns the Settings window. `DeviceMonitor` publishes independent keyboard, mouse, speaker, and headphones states.
- Devices are selected by stable Bluetooth address. Keep one shared icon family and status style, per-device visibility, and reopen Settings when all status items are hidden.
- Preserve event-driven Bluetooth updates, the 30-second fallback, and wake reconciliation. Do not introduce a daemon, network dependency, battery feature, or reconnect control without a request.
- Keep the app menu-bar-only (`LSUIElement`) and single-instance. Never run the installed app alongside a test or visual-audit copy.

## Validation

- Run `xcodebuild test -project BluetoothStatus.xcodeproj -scheme BluetoothStatus -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` after behavior changes.
- Before tests or a replacement build, stop only the known Bluetooth Status process. After installing, verify the code signature, bundle resources, and exactly one running instance.
- Treat a passing unit suite as code evidence, not proof of the live menu, actual sleep/wake, or Login Items approval. Report those checks separately.
- Do not change the user's paired-device choices, icon visibility, or Launch at Login setting merely to run tests.

## Repository hygiene

- Commit source, tests, `project.yml`, the generated Xcode project, and the selected/generated icon assets. Do not commit `dist/`, DerivedData, `.app` bundles, local preferences, or credentials.
- Review generated Xcode project changes before committing. Keep documentation consistent with build commands that work from a fresh clone.
- This repository is private. Do not change its visibility or publish a release without explicit authorization.
