import SwiftUI

/// Glossy Frutiger-Aero gel readout shown along the bottom of the expanded tank.
struct StatBar: View {
    @ObservedObject var vitals: SystemVitals

    var body: some View {
        let snapshot = vitals.snapshot
        HStack(spacing: 16) {
            stat(symbol: "battery.100", value: batteryText(snapshot.batteryFraction))
            stat(symbol: "cpu", value: "\(Int((snapshot.cpuFraction * 100).rounded()))%")
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 11, weight: .semibold))
                ramBar(snapshot.memoryUsedFraction)
            }
        }
        .fixedSize()
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.white.opacity(0.12))
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [.white.opacity(0.28), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
                )
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
        )
    }

    private func stat(symbol: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }

    private func ramBar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.5, green: 0.9, blue: 1.0), Color(red: 0.2, green: 0.6, blue: 0.9)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(width: 54, height: 9)
    }

    private func batteryText(_ fraction: Double?) -> String {
        guard let fraction else { return "—" }
        return "\(Int((fraction * 100).rounded()))%"
    }
}
