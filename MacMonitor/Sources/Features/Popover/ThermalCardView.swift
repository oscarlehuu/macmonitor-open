import SwiftUI

struct ThermalCardView: View {
    let state: ThermalState
    let lastUpdated: Date?
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Heat", systemImage: state.symbolName)
                    .font(.headline)
                Spacer()
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state.color)
            }

            Text(descriptionText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastUpdated {
                Text("Updated \(MetricFormatter.relativeTime(from: lastUpdated))")
                    .font(.caption2)
                    .foregroundStyle(isStale ? .orange : .secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(state.color.opacity(0.35), lineWidth: 1)
        )
    }

    private var descriptionText: String {
        switch state {
        case .nominal:
            return "System thermal pressure is low."
        case .fair:
            return "Thermal pressure is elevated but stable."
        case .serious:
            return "System is under high thermal pressure."
        case .critical:
            return "Critical thermal pressure; performance may throttle."
        case .unknown:
            return "Thermal pressure data is unavailable."
        }
    }
}

private extension ThermalState {
    var color: Color {
        switch self {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        case .unknown:
            return .gray
        }
    }

    var symbolName: String {
        switch self {
        case .nominal:
            return "thermometer.low"
        case .fair:
            return "thermometer.medium"
        case .serious:
            return "thermometer.high"
        case .critical:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
}
