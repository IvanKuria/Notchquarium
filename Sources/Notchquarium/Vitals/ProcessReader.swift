import Foundation
import Darwin

/// Samples per-process CPU usage and returns the busiest processes.
///
/// CPU% per process is a rate: `proc_pidinfo` reports cumulative user+system
/// nanoseconds, so we cache the previous reading per pid and divide the delta
/// by elapsed wall-clock time. The first call has no baseline and returns `[]`.
final class ProcessReader {
    private var prevCPU: [pid_t: UInt64] = [:]
    private var prevTime: TimeInterval?

    func topProcesses(limit: Int) -> [ProcessSample] {
        let now = Date().timeIntervalSince1970
        let pids = listPIDs()
        let elapsed = prevTime.map { now - $0 } ?? 0

        var current: [pid_t: UInt64] = [:]
        var samples: [ProcessSample] = []
        current.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            guard let totalNs = cpuNanoseconds(pid: pid) else { continue }
            current[pid] = totalNs
            guard let prev = prevCPU[pid], elapsed > 0 else { continue }
            let deltaNs = totalNs >= prev ? Double(totalNs - prev) : 0
            let percent = deltaNs / (elapsed * 1_000_000_000) * 100
            if percent > 0.1 {
                samples.append(ProcessSample(pid: pid, name: name(pid: pid), cpuPercent: percent))
            }
        }

        prevCPU = current
        prevTime = now
        return Array(samples.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(limit))
    }

    // MARK: - libproc plumbing

    private func listPIDs() -> [pid_t] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }
        let capacity = Int(byteCount) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: capacity)
        let returned = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, byteCount)
        guard returned > 0 else { return [] }
        let n = Int(returned) / MemoryLayout<pid_t>.size
        return Array(pids.prefix(n))
    }

    private func cpuNanoseconds(pid: pid_t) -> UInt64? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        guard result == size else { return nil }
        return info.pti_total_user + info.pti_total_system
    }

    private func name(pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        if length > 0 {
            return String(cString: buffer)
        }
        return "pid \(pid)"
    }
}
