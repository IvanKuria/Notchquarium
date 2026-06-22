import XCTest
@testable import Notchquarium

final class FishDiffTests: XCTestCase {
    private let a = ProcessSample(pid: 1, name: "A", cpuPercent: 10)
    private let b = ProcessSample(pid: 2, name: "B", cpuPercent: 20)

    func testAddNewProcess() {
        XCTAssertEqual(FishDiff.ops(current: [a], next: [a, b]), [.add(b)])
    }

    func testRemoveGoneProcess() {
        XCTAssertEqual(FishDiff.ops(current: [a, b], next: [a]), [.remove(pid: 2)])
    }

    func testUpdateChangedProcess() {
        let aHot = ProcessSample(pid: 1, name: "A", cpuPercent: 55)
        XCTAssertEqual(FishDiff.ops(current: [a], next: [aHot]), [.update(aHot)])
    }

    func testNoChangeWhenIdentical() {
        XCTAssertEqual(FishDiff.ops(current: [a], next: [a]), [])
    }

    func testEmptyNextKeepsNothing() {
        XCTAssertEqual(FishDiff.ops(current: [a, b], next: []), [.remove(pid: 1), .remove(pid: 2)])
    }
}
