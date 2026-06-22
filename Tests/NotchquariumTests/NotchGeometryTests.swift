import XCTest
@testable import Notchquarium

final class NotchGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let notch = CGSize(width: 200, height: 32)

    func testNotchCenteredAtTop() {
        let r = NotchGeometry.notchRect(screenFrame: screen, notchSize: notch)
        XCTAssertEqual(r.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.5)
        XCTAssertEqual(r.width, notch.width, accuracy: 0.5)
    }

    func testTankCenteredUnderNotch() {
        let r = NotchGeometry.tankFrame(screenFrame: screen, notchSize: notch, state: .expanded)
        XCTAssertEqual(r.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.5)
    }

    func testExpandedTallerThanPeekTallerThanAmbient() {
        let ambient = NotchGeometry.tankFrame(screenFrame: screen, notchSize: notch, state: .ambient)
        let peek = NotchGeometry.tankFrame(screenFrame: screen, notchSize: notch, state: .peek)
        let expanded = NotchGeometry.tankFrame(screenFrame: screen, notchSize: notch, state: .expanded)
        XCTAssertGreaterThan(expanded.height, peek.height)
        XCTAssertGreaterThan(peek.height, ambient.height)
    }

    func testTankAtLeastNotchWide() {
        for state in [NotchState.ambient, .peek, .expanded] {
            let r = NotchGeometry.tankFrame(screenFrame: screen, notchSize: notch, state: state)
            XCTAssertGreaterThanOrEqual(r.width, notch.width)
        }
    }
}
