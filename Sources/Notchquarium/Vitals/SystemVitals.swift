import Foundation

/// Polls the OS on a timer and publishes an immutable `VitalsSnapshot`.
///
/// This is the *only* component that touches the OS readers. Everything that
/// renders observes `snapshot` and never reads vitals directly.
@MainActor
final class SystemVitals: ObservableObject {
    @Published private(set) var snapshot: VitalsSnapshot = .empty

    private let cpuSampler = CPUReader.LiveSampler()
    private let processReader = ProcessReader()
    private var timer: Timer?

    /// Begin polling. Safe to call repeatedly; restarts the timer.
    func start(interval: TimeInterval = 2.0) {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        snapshot = VitalsSnapshot(
            batteryFraction: BatteryReader.fraction(),
            cpuFraction: cpuSampler.sample(),
            memoryUsedFraction: MemoryReader.live(),
            topProcesses: processReader.topProcesses(limit: 5)
        )
    }
}
