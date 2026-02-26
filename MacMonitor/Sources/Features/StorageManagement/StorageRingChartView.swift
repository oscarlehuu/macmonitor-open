import SwiftUI

private struct RingSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let thicknessRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        let innerRadius = radius * max(0.2, min(thicknessRatio, 0.92))

        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct StorageRingChartView: View {
    let buckets: [StorageRingBucket]
    let totalBytes: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                chart
                    .frame(width: 150, height: 150)

                legend
            }
        }
    }

    private var chart: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let frame = CGRect(x: 0, y: 0, width: size, height: size)

            ZStack {
                ForEach(Array(segments.enumerated()), id: \.element.bucket.id) { _, segment in
                    RingSliceShape(
                        startAngle: segment.startAngle,
                        endAngle: segment.endAngle,
                        thicknessRatio: 0.62
                    )
                    .fill(color(for: segment.bucket.category))
                }

                VStack(spacing: 2) {
                    Text("Scanned")
                        .font(.system(size: 9))
                        .foregroundStyle(PopoverTheme.textMuted)
                    Text(MetricFormatter.bytes(totalBytes))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: size * 0.48)
            }
            .frame(width: frame.width, height: frame.height)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(buckets.prefix(6))) { bucket in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color(for: bucket.category))
                        .frame(width: 7, height: 7)

                    Text(bucket.label)
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(MetricFormatter.bytes(bucket.sizeBytes))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
            }

            if buckets.count > 6 {
                Text("+\(buckets.count - 6) more")
                    .font(.system(size: 9))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
        }
    }

    private var segments: [(bucket: StorageRingBucket, startAngle: Angle, endAngle: Angle)] {
        let sum = buckets.reduce(UInt64(0)) { $0 + $1.sizeBytes }
        guard sum > 0 else { return [] }

        let activeBuckets = buckets.filter { $0.sizeBytes > 0 }
        var spans = activeBuckets.map { bucket -> Double in
            let fraction = Double(bucket.sizeBytes) / Double(sum)
            return max(2.0, fraction * 360.0)
        }

        let total = spans.reduce(0.0, +)
        if total > 360.0 {
            let scale = 360.0 / total
            spans = spans.map { $0 * scale }
        }

        var startDegrees = -90.0
        var output: [(bucket: StorageRingBucket, startAngle: Angle, endAngle: Angle)] = []
        output.reserveCapacity(activeBuckets.count)

        for (bucket, span) in zip(activeBuckets, spans) {
            let endDegrees = startDegrees + span
            output.append(
                (
                    bucket: bucket,
                    startAngle: .degrees(startDegrees),
                    endAngle: .degrees(endDegrees)
                )
            )
            startDegrees = endDegrees
        }

        return output
    }

    private func color(for category: StorageManagedItemCategory) -> Color {
        switch category {
        case .application:
            return PopoverTheme.blue
        case .cache:
            return PopoverTheme.mint
        case .folder:
            return PopoverTheme.purple
        }
    }
}
