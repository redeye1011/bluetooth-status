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
}
