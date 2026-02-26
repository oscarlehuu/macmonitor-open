import AppIntents
import SwiftUI
import WidgetKit

private struct WidgetSharedSnapshotPoint: Codable {
    let timestamp: Date
    let thermalState: String
    let memoryUsagePercent: Double
    let storageUsagePercent: Double
    let batteryPercent: Int?
    let cpuUsagePercent: Double?
    let networkDownloadBytesPerSecond: Double?
    let networkUploadBytesPerSecond: Double?
}

private struct WidgetSharedSnapshotSummary: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let latest: WidgetSharedSnapshotPoint
    let trend24Hours: [WidgetSharedSnapshotPoint]
    let trend7Days: [WidgetSharedSnapshotPoint]
}

private enum WidgetTrendWindow: String, AppEnum {
    case last24Hours
    case last7Days

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Trend Window")
    static let caseDisplayRepresentations: [WidgetTrendWindow: DisplayRepresentation] = [
        .last24Hours: "24h",
        .last7Days: "7d"
    ]
}

private struct StatusEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSharedSnapshotSummary?
}

private struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), summary: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: Date(), summary: WidgetSharedSnapshotReader().loadSummary()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let entry = StatusEntry(date: Date(), summary: WidgetSharedSnapshotReader().loadSummary())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct StatusWidgetView: View {
    let entry: StatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MacMonitor")
                .font(.system(size: 12, weight: .semibold))

            if let summary = entry.summary {
                HStack {
                    metricChip(title: "RAM", value: "\(Int(summary.latest.memoryUsagePercent.rounded()))%")
                    metricChip(title: "SSD", value: "\(Int(summary.latest.storageUsagePercent.rounded()))%")
                }
                HStack {
                    metricChip(title: "CPU", value: summary.latest.cpuUsagePercent.map { "\(Int($0.rounded()))%" } ?? "--")
                    metricChip(title: "BAT", value: summary.latest.batteryPercent.map { "\($0)%" } ?? "--")
                }
                Text("Thermal: \(summary.latest.thermalState.capitalized)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text("Open MacMonitor once to generate shared data.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(10)
    }

    private func metricChip(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
    }
}

private struct BatteryTrendIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Battery Trend"
    static let description = IntentDescription("Select the trend window displayed by the widget.")

    @Parameter(title: "Window", default: .last24Hours)
    var window: WidgetTrendWindow
}

private struct BatteryTrendEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSharedSnapshotSummary?
    let window: WidgetTrendWindow
}

private struct BatteryTrendProvider: AppIntentTimelineProvider {
    typealias Intent = BatteryTrendIntent
    typealias Entry = BatteryTrendEntry

    func placeholder(in context: Context) -> BatteryTrendEntry {
        BatteryTrendEntry(date: Date(), summary: nil, window: .last24Hours)
    }

    func snapshot(for configuration: BatteryTrendIntent, in context: Context) async -> BatteryTrendEntry {
        BatteryTrendEntry(
            date: Date(),
            summary: WidgetSharedSnapshotReader().loadSummary(),
            window: configuration.window
        )
    }

    func timeline(for configuration: BatteryTrendIntent, in context: Context) async -> Timeline<BatteryTrendEntry> {
        let entry = BatteryTrendEntry(
            date: Date(),
            summary: WidgetSharedSnapshotReader().loadSummary(),
            window: configuration.window
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1_800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

private struct BatteryTrendWidgetView: View {
    let entry: BatteryTrendEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Battery Trend")
                .font(.system(size: 12, weight: .semibold))

            if let values = batteryPoints(), values.count >= 2 {
                MiniSparkline(values: values)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(height: 34)
                Text("Latest: \(Int(values.last?.rounded() ?? 0))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No battery trend samples available.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(10)
    }

    private func batteryPoints() -> [Double]? {
        guard let summary = entry.summary else { return nil }
        let points = switch entry.window {
        case .last24Hours: summary.trend24Hours
        case .last7Days: summary.trend7Days
        }
        let values = points.compactMap { $0.batteryPercent.map(Double.init) }
        return values.isEmpty ? nil : values
    }
}

private struct MiniSparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let span = max(maxValue - minValue, 0.0001)
        let step = rect.width / CGFloat(values.count - 1)

        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * step
            let normalized = (value - minValue) / span
            let y = rect.height - (CGFloat(normalized) * rect.height)
            let point = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private struct WidgetSharedSnapshotReader {
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSummary() -> WidgetSharedSnapshotSummary? {
        let fileManager = FileManager.default
        let fileURL: URL?

        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.oscar.macmonitor") {
            fileURL = containerURL
                .appendingPathComponent("Snapshots", isDirectory: true)
                .appendingPathComponent("shared-snapshot-v2.json")
        } else {
            fileURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("MacMonitor", isDirectory: true)
                .appendingPathComponent("SharedSnapshots", isDirectory: true)
                .appendingPathComponent("shared-snapshot-v2.json")
        }

        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? decoder.decode(WidgetSharedSnapshotSummary.self, from: data)
    }
}

@main
struct MacMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacMonitorStatusWidget()
        MacMonitorBatteryTrendWidget()
    }
}

struct MacMonitorStatusWidget: Widget {
    let kind = "MacMonitorStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("MacMonitor Status")
        .description("Current RAM, storage, CPU, and battery summary.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MacMonitorBatteryTrendWidget: Widget {
    let kind = "MacMonitorBatteryTrendWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: BatteryTrendIntent.self, provider: BatteryTrendProvider()) { entry in
            BatteryTrendWidgetView(entry: entry)
        }
        .configurationDisplayName("Battery Trend")
        .description("Recent battery trend from shared snapshots.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
