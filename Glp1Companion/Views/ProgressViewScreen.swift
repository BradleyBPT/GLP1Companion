import SwiftUI
import Charts
import SwiftData

struct ProgressViewScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Record.date, order: .forward) private var records: [Record]
    @Query(sort: \FluidIntakeLog.date, order: .forward) private var fluidLogs: [FluidIntakeLog]
    @Query private var goalsQuery: [NutritionGoals]

    private var goals: NutritionGoals { goalsQuery.first ?? NutritionGoals() }
    private var weightUnit: WeightUnit { goals.preferredWeightUnit }

    private var weightSamples: [TrendSample] {
        records
            .filter { $0.type == .weight }
            .compactMap { record -> TrendSample? in
                guard let valueString = record.value, let kg = Double(valueString) else { return nil }
                let converted = weightUnit.convertFromKG(kg)
                return TrendSample(date: record.date, value: converted)
            }
    }

    private var hydrationSamples: [TrendSample] {
        let grouped = Dictionary(grouping: fluidLogs) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { (day, logs) in
            TrendSample(date: day, value: logs.reduce(0) { $0 + $1.amountML })
        }
        .sorted { $0.date < $1.date }
    }

    private var moodSamples: [TrendSample] {
        records
            .filter { $0.type == .mood }
            .compactMap { record -> TrendSample? in
                guard let valueString = record.value, let score = Double(valueString) else { return nil }
                return TrendSample(date: record.date, value: score)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !weightSamples.isEmpty {
                    MinimalLineChart(
                        title: "Weight",
                        subtitle: "Unit: \(weightUnit.displayName)",
                        unitLabel: weightUnit == .kilograms ? "kg" : "st",
                        samples: weightSamples,
                        accentColor: .blue
                    )
                }

                if !hydrationSamples.isEmpty {
                    MinimalLineChart(
                        title: "Hydration",
                        subtitle: "Goal: \(Int(goals.dailyHydrationML)) mL",
                        unitLabel: "mL",
                        samples: hydrationSamples,
                        accentColor: .teal
                    )
                }

                if !moodSamples.isEmpty {
                    MinimalLineChart(
                        title: "Mood",
                        subtitle: "Average mood over time",
                        unitLabel: nil,
                        samples: moodSamples,
                        accentColor: .pink
                    )
                }

                if weightSamples.isEmpty && hydrationSamples.isEmpty && moodSamples.isEmpty {
                    VStack(spacing: 12) {
                        Text("No progress data yet")
                            .font(.headline)
                        Text("Log weight, hydration, or mood to see your trends here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .navigationTitle("Progress")
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    let container: ModelContainer = {
        let container = try! ModelContainer(for: Record.self, FluidIntakeLog.self, NutritionGoals.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let goals = NutritionGoals()
        context.insert(goals)
        let now = Date()
        for offset in 0..<10 {
            let date = Calendar.current.date(byAdding: .day, value: -9 + offset, to: now)!
            let kg = 70 + Double(offset) * 0.3
            context.insert(Record(type: .weight, date: date, value: String(format: "%.2f", kg)))
            context.insert(FluidIntakeLog(date: date, amountML: Double.random(in: 1500...2300), type: .water))
        }
        try? context.save()
        return container
    }()

    return NavigationStack {
        ProgressViewScreen()
    }
    .modelContainer(container)
}
