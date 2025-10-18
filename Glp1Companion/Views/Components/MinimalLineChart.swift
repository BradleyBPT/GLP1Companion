import SwiftUI
import Charts

struct TrendSample: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct MinimalLineChart: View {
    let title: String
    let subtitle: String?
    let unitLabel: String?
    let samples: [TrendSample]
    let accentColor: Color

    private var latestValue: Double? { samples.last?.value }
    private var firstValue: Double? { samples.first?.value }
    private var deltaString: String {
        guard let latest = latestValue, let first = firstValue else { return "" }
        let delta = latest - first
        guard abs(delta) >= 0.01 else { return "No change" }
        return String(format: "%@%.2f", delta >= 0 ? "+" : "", delta)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let latest = latestValue {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.2f", latest))
                            .font(.headline)
                        Text(deltaString)
                            .font(.caption)
                            .foregroundStyle(deltaString.hasPrefix("-") ? Color.green : Color.secondary)
                    }
                }
            }

            if samples.count >= 2 {
                Chart(samples) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Value", sample.value)
                    )
                    .lineStyle(.init(lineWidth: 2))
                    .foregroundStyle(accentColor)

                    AreaMark(
                        x: .value("Date", sample.date),
                        y: .value("Value", sample.value)
                    )
                    .foregroundStyle(accentColor.opacity(0.2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 120)
            } else {
                Text("Not enough data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    let now = Date()
    let samples = (0..<10).map { offset in
        TrendSample(date: Calendar.current.date(byAdding: .day, value: -9 + offset, to: now)!, value: Double.random(in: 70...75))
    }
    return MinimalLineChart(title: "Weight", subtitle: "Last 10 days", unitLabel: "kg", samples: samples, accentColor: .blue)
        .padding()
}
