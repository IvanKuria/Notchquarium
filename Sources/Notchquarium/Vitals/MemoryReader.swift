import Foundation
import Darwin

/// Reads memory pressure as a used fraction of physical RAM.
enum MemoryReader {
    /// Pure: used / total, clamped to 0...1 (0 when total is 0).
    static func usedFraction(usedBytes: Double, totalBytes: Double) -> Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(usedBytes / totalBytes, 0), 1)
    }

    /// Live used-memory fraction (active + wired + compressed) over physical RAM.
    static func live() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reb in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reb, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        return usedFraction(usedBytes: used, totalBytes: total)
    }
}
