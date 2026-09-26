import Foundation
import XCTest
@testable import BluetoothStatus

final class SingleInstanceLockTests: XCTestCase {
    func testOnlyOneProcessCanHoldTheLock() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BluetoothStatus-\(UUID().uuidString).lock")
        defer { try? FileManager.default.removeItem(at: url) }

        var first: SingleInstanceLock? = try XCTUnwrap(SingleInstanceLock(url: url))
        XCTAssertNotNil(first)
        XCTAssertNil(SingleInstanceLock(url: url))
        first = nil
        XCTAssertNotNil(SingleInstanceLock(url: url))
    }
}
