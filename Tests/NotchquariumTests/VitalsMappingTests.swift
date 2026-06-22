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

    func testCPUFractionFromDeltas() {
        // 30 busy ticks vs 70 idle ticks -> 0.3 busy
        let f = CPUReader.fraction(prevBusy: 0, prevIdle: 0, curBusy: 30, curIdle: 70)
        XCTAssertEqual(f, 0.3, accuracy: 0.001)
    }

    func testCPUFractionClampsAndHandlesNoDelta() {
        // No elapsed ticks -> 0, not NaN.
        XCTAssertEqual(CPUReader.fraction(prevBusy: 5, prevIdle: 5, curBusy: 5, curIdle: 5), 0, accuracy: 0.001)
    }

    func testMemoryUsedFraction() {
        let f = MemoryReader.usedFraction(usedBytes: 8_000_000_000, totalBytes: 16_000_000_000)
        XCTAssertEqual(f, 0.5, accuracy: 0.001)
    }

    func testMemoryUsedFractionClamps() {
        XCTAssertEqual(MemoryReader.usedFraction(usedBytes: 20, totalBytes: 0), 0, accuracy: 0.001)
        XCTAssertEqual(MemoryReader.usedFraction(usedBytes: 30, totalBytes: 10), 1, accuracy: 0.001)
    }
}
