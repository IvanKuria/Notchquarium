import XCTest
@testable import Notchquarium

final class VitalsMappingTests: XCTestCase {
    func testSnapshotStoresFields() {
        let p = ProcessSample(pid: 1, name: "Chrome", cpuPercent: 41)
        let s = VitalsSnapshot(
            batteryFraction: 0.8,
            cpuFraction: 0.23,
            memoryUsedFraction: 0.5,
            topProcesses: [p]
        )
        XCTAssertEqual(s.topProcesses.first?.name, "Chrome")
        XCTAssertEqual(s, s)
    }
}
