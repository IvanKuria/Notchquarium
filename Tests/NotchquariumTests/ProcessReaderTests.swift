import XCTest
@testable import Notchquarium

final class ProcessReaderTests: XCTestCase {
    /// Live smoke test: two spaced samples should run without crashing, return
    /// non-empty named processes, and be sorted by CPU descending.
    func testReturnsSortedNamedProcesses() {
        let reader = ProcessReader()
        _ = reader.topProcesses(limit: 5) // establish baseline
        Thread.sleep(forTimeInterval: 0.4)
        let top = reader.topProcesses(limit: 5)

        XCTAssertLessThanOrEqual(top.count, 5)
        for sample in top {
            XCTAssertFalse(sample.name.isEmpty)
            XCTAssertGreaterThan(sample.cpuPercent, 0)
        }
        XCTAssertEqual(top, top.sorted { $0.cpuPercent > $1.cpuPercent })
    }
}
