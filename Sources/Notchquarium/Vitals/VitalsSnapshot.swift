import Foundation

/// A single process the aquarium can represent as a fish.
struct ProcessSample: Equatable {
    let pid: Int32
    let name: String
    /// Recent CPU usage as a percentage (0...100+, can exceed 100 on multi-core).
    let cpuPercent: Double
}

/// An immutable snapshot of the Mac's vitals at one instant.
///
/// The aquarium renders purely from this value — nothing in the rendering layer
/// reads the OS directly. Producing these is `SystemVitals`' only job.
struct VitalsSnapshot: Equatable {
    /// Battery charge as a fraction 0...1, or `nil` on a Mac without a battery.
    let batteryFraction: Double?
    /// Total CPU busy fraction 0...1.
    let cpuFraction: Double
    /// Used memory as a fraction of total, 0...1.
    let memoryUsedFraction: Double
    /// Busiest processes, sorted descending by `cpuPercent`.
    let topProcesses: [ProcessSample]

    static let empty = VitalsSnapshot(
        batteryFraction: nil,
        cpuFraction: 0,
        memoryUsedFraction: 0,
        topProcesses: []
    )
}
