import Foundation

/// The three sizes the aquarium can take.
enum NotchState {
    case ambient   // resting at the notch
    case peek      // shallow tank on hover
    case expanded  // full tank on click
}

/// Pure geometry for placing the notch widget. No AppKit, fully testable.
///
/// All rects are in screen coordinates with the origin at bottom-left (AppKit
/// convention), so "top of screen" is `maxY`. The tank always hangs *down* from
/// the top edge, centered under the notch.
enum NotchGeometry {
    /// The physical notch rectangle, centered at the top of the screen.
    static func notchRect(screenFrame: CGRect, notchSize: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - notchSize.width / 2,
            y: screenFrame.maxY - notchSize.height,
            width: notchSize.width,
            height: notchSize.height
        )
    }

    /// The widget frame for a given state, centered under the notch and pinned
    /// to the top edge of the screen.
    static func tankFrame(screenFrame: CGRect, notchSize: CGSize, state: NotchState) -> CGRect {
        let size = tankSize(notchSize: notchSize, state: state)
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private static func tankSize(notchSize: CGSize, state: NotchState) -> CGSize {
        switch state {
        case .ambient:
            return CGSize(width: notchSize.width, height: notchSize.height)
        case .peek:
            return CGSize(width: notchSize.width + 40, height: 90)
        case .expanded:
            return CGSize(width: max(notchSize.width, 460), height: 240)
        }
    }
}
