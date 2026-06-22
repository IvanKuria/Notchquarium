import Foundation
import Darwin

/// Reads total CPU busy fraction from the Mach host.
///
/// CPU usage is inherently a *rate*: you must compare two tick readings over
/// time. `fraction(...)` is the pure math (testable); `LiveSampler` holds the
/// previous reading and turns successive live samples into a 0...1 value.
enum CPUReader {
    /// Busy fraction between two cumulative tick readings. Returns 0 when no
    /// time elapsed (avoids NaN) and clamps to 0...1.
    static func fraction(prevBusy: Double, prevIdle: Double, curBusy: Double, curIdle: Double) -> Double {
        let dBusy = curBusy - prevBusy
        let dIdle = curIdle - prevIdle
        let total = dBusy + dIdle
        guard total > 0 else { return 0 }
        return min(max(dBusy / total, 0), 1)
    }

    /// Cumulative (busy, idle) ticks since boot, or nil if the host call fails.
    static func currentTicks() -> (busy: Double, idle: Double)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reb in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reb, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        return (user + system + nice, idle)
    }

    /// Stateful helper that remembers the last tick reading.
    final class LiveSampler {
        private var prev: (busy: Double, idle: Double)?

        /// Busy fraction since the previous call (0 on the very first call).
        func sample() -> Double {
            guard let cur = CPUReader.currentTicks() else { return 0 }
            defer { prev = cur }
            guard let prev else { return 0 }
            return CPUReader.fraction(
                prevBusy: prev.busy, prevIdle: prev.idle,
                curBusy: cur.busy, curIdle: cur.idle
            )
        }
    }
}
