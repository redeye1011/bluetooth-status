import XCTest
@testable import BluetoothStatus

final class SystemProfilerSnapshotTests: XCTestCase {
    func testParsesPairedAddressesAndIndependentConnectionStates() throws {
        let json = """
        {"SPBluetoothDataType":[{
          "controller_properties":{"controller_state":"attrib_on"},
          "device_connected":[{"MX Keys Mini":{"device_address":"AA:BB:CC:DD:EE:FF"}}],
          "device_not_connected":[{"Xiaoxin M3":{"device_address":"11:22:33:44:55:66"}}]
        }]}
        """

        let snapshot = try XCTUnwrap(SystemProfilerSnapshot.parse(Data(json.utf8)))
        XCTAssertTrue(snapshot.poweredOn)
        XCTAssertEqual(snapshot.devices, [
            PairedDevice(id: "AA:BB:CC:DD:EE:FF", name: "MX Keys Mini"),
            PairedDevice(id: "11:22:33:44:55:66", name: "Xiaoxin M3")
        ])
        XCTAssertEqual(snapshot.connectedAddresses, ["AA:BB:CC:DD:EE:FF"])
    }

    func testParsesOnlyValidConnectedBatteryPercentages() throws {
        let json = """
        {"SPBluetoothDataType":[{
          "controller_properties":{"controller_state":"attrib_on"},
          "device_connected":[
            {"Keyboard":{"device_address":"K","device_batteryLevelMain":"0%"}},
            {"Mouse":{"device_address":"M","device_batteryLevelMain":"100%"}},
            {"Speaker":{"device_address":"S","device_batteryLevelMain":"82%"}},
            {"Invalid":{"device_address":"I","device_batteryLevelMain":"101%"}},
            {"Unknown":{"device_address":"U"}}
          ],
          "device_not_connected":[{"Old":{"device_address":"D","device_batteryLevelMain":"50%"}}]
        }]}
        """

        let snapshot = try XCTUnwrap(SystemProfilerSnapshot.parse(Data(json.utf8)))
        XCTAssertEqual(snapshot.batteryPercentByAddress, ["K": 0, "M": 100, "S": 82])
    }

    func testClassifiesAudioDevicesFromBluetoothType() throws {
        let json = """
        {"SPBluetoothDataType":[{
          "controller_properties":{"controller_state":"attrib_on"},
          "device_connected":[
            {"Living Room":{"device_address":"S","device_minorType":"Speaker"}},
            {"Studio Set":{"device_address":"H","device_minorType":"Headphones"}},
            {"Call Set":{"device_address":"C","device_minorType":"Headset"}},
            {"My AirPods":{"device_address":"A"}}
          ]
        }]}
        """
        let devices = try XCTUnwrap(SystemProfilerSnapshot.parse(Data(json.utf8))).devices
        XCTAssertEqual(devices.map(\.audioKind), [.speaker, .headphones, .headphones, .headphones])
    }
}
