import Foundation
import IOKit.ps

/// Reads battery charge via IOKit power sources.
enum BatteryReader {
    /// Charge as a fraction 0...1, or nil on a Mac with no battery (desktop).
    static func fraction() -> Double? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                  let current = desc[kIOPSCurrentCapacityKey] as? Double,
                  let max = desc[kIOPSMaxCapacityKey] as? Double,
                  max > 0
            else { continue }
            return min(current / max, 1)
        }
        return nil
    }
}
