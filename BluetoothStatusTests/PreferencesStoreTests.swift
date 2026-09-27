import XCTest
@testable import BluetoothStatus

final class PreferencesStoreTests: XCTestCase {
    func testSelectedDevicesSurviveStoreRecreation() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = PreferencesStore(defaults: defaults)
        first.setAddress("AA-BB-CC-DD-EE-FF", for: .keyboard)
        first.setAddress("11-22-33-44-55-66", for: .mouse)
        first.setAddress("77-88-99-AA-BB-CC", for: .speaker)
        first.setAddress("00-11-22-33-44-55", for: .headphones)
        first.setStyle(.shape)

        let reopened = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reopened.address(for: .keyboard), "AA-BB-CC-DD-EE-FF")
        XCTAssertEqual(reopened.address(for: .mouse), "11-22-33-44-55-66")
        XCTAssertEqual(reopened.address(for: .speaker), "77-88-99-AA-BB-CC")
        XCTAssertEqual(reopened.address(for: .headphones), "00-11-22-33-44-55")
        XCTAssertEqual(reopened.style, .shape)
    }

    func testVisibilityDefaultsOnAndPersistsIndependently() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = PreferencesStore(defaults: defaults)
        XCTAssertTrue(PeripheralType.allCases.allSatisfy { first.isVisible($0) })
        first.setVisible(false, for: .mouse)
        first.setVisible(false, for: .speaker)
        first.setVisible(false, for: .headphones)

        let reopened = PreferencesStore(defaults: defaults)
        XCTAssertTrue(reopened.isVisible(.keyboard))
        XCTAssertFalse(reopened.isVisible(.mouse))
        XCTAssertFalse(reopened.isVisible(.speaker))
        XCTAssertFalse(reopened.isVisible(.headphones))
        reopened.setVisible(true, for: .speaker)
        XCTAssertTrue(first.isVisible(.speaker))
    }

    func testHideWhenDisconnectedDefaultsOffAndPersistsPerDevice() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = PreferencesStore(defaults: defaults)
        for type in [PeripheralType.keyboard, .mouse] {
            XCTAssertFalse(preferences.hidesWhenDisconnected(type))
            XCTAssertTrue(preferences.shouldShow(type, state: .disconnected))
        }
        for type in [PeripheralType.speaker, .headphones] {
            XCTAssertTrue(preferences.hidesWhenDisconnected(type))
            XCTAssertFalse(preferences.shouldShow(type, state: .disconnected))
            XCTAssertTrue(preferences.shouldShow(type, state: .connected))
        }

        preferences.setHideWhenDisconnected(true, for: .speaker)
        preferences.setHideWhenDisconnected(true, for: .mouse)
        preferences.setHideWhenDisconnected(false, for: .headphones)
        let reopened = PreferencesStore(defaults: defaults)
        XCTAssertTrue(reopened.shouldShow(.keyboard, state: .disconnected))
        for type in [PeripheralType.mouse, .speaker] {
            XCTAssertTrue(reopened.hidesWhenDisconnected(type))
            XCTAssertFalse(reopened.shouldShow(type, state: .disconnected))
            XCTAssertFalse(reopened.shouldShow(type, state: .unavailable))
            XCTAssertTrue(reopened.shouldShow(type, state: .connected))
        }
        XCTAssertTrue(reopened.shouldShow(.headphones, state: .disconnected))

        reopened.setVisible(false, for: .speaker)
        XCTAssertFalse(preferences.shouldShow(.speaker, state: .connected))
    }

    func testLegacyHeadphoneChoiceMovesToIndependentSlotWithItsVisibility() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setAddress("AIRPODS", for: .speaker)
        preferences.setVisible(false, for: .speaker)
        preferences.setHideWhenDisconnected(false, for: .speaker)

        preferences.migrateLegacyHeadphones(using: [PairedDevice(id: "AIRPODS", name: "AirPods", audioKind: .headphones)])

        XCTAssertNil(preferences.address(for: .speaker))
        XCTAssertEqual(preferences.address(for: .headphones), "AIRPODS")
        XCTAssertTrue(preferences.isVisible(.speaker))
        XCTAssertFalse(preferences.isVisible(.headphones))
        XCTAssertTrue(preferences.hidesWhenDisconnected(.speaker))
        XCTAssertFalse(preferences.hidesWhenDisconnected(.headphones))
    }

    func testAllIconsCanStayHiddenWithoutForcingInitialSetup() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setAddress("KEYBOARD", for: .keyboard)
        for type in PeripheralType.allCases { preferences.setVisible(false, for: type) }

        let reopened = PreferencesStore(defaults: defaults)
        XCTAssertTrue(PeripheralType.allCases.allSatisfy { !reopened.isVisible($0) })
        XCTAssertEqual(reopened.address(for: .keyboard), "KEYBOARD")
        XCTAssertFalse(reopened.needsInitialSetup)
    }

    func testGeneratedIconFamilyPersists() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = PreferencesStore(defaults: defaults)
        XCTAssertEqual(first.iconFamily, .system)
        first.setIconFamily(.b)
        XCTAssertEqual(PreferencesStore(defaults: defaults).iconFamily, .b)
    }

    func testHiddenUnselectedDeviceDoesNotForceSetupOnEveryLaunch() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        XCTAssertTrue(preferences.needsInitialSetup)

        preferences.setVisible(false, for: .keyboard)
        preferences.setAddress("MOUSE", for: .mouse)
        XCTAssertFalse(preferences.needsInitialSetup)

        preferences.setVisible(true, for: .keyboard)
        XCTAssertTrue(preferences.needsInitialSetup)
    }
}
