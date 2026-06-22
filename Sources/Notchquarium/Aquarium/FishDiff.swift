import Foundation

/// A change to apply to the set of fish nodes.
enum FishOp: Equatable {
    case add(ProcessSample)
    case remove(pid: pid_t)
    case update(ProcessSample)
}

/// Pure diff: turns "current fish" + "next snapshot processes" into the minimal
/// set of operations. Keyed by pid. Removes are emitted first (in current
/// order), then adds/updates (in next order) — deterministic for testing and
/// for stable rendering.
enum FishDiff {
    static func ops(current: [ProcessSample], next: [ProcessSample]) -> [FishOp] {
        let currentByPID = Dictionary(uniqueKeysWithValues: current.map { ($0.pid, $0) })
        let nextByPID = Dictionary(uniqueKeysWithValues: next.map { ($0.pid, $0) })

        var ops: [FishOp] = []

        for sample in current where nextByPID[sample.pid] == nil {
            ops.append(.remove(pid: sample.pid))
        }

        for sample in next {
            if let existing = currentByPID[sample.pid] {
                if existing != sample {
                    ops.append(.update(sample))
                }
            } else {
                ops.append(.add(sample))
            }
        }

        return ops
    }
}
