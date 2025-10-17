import SwiftUI

struct FluidIntakeCard: View {
    let summary: DailySummary

    private var progress: Double {
        guard summary.hydrationGoalML > 0 else { return 0 }
        return min(summary.hydrationML / summary.hydrationGoalML, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Hydration", systemImage: "drop.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accentColor)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(summary.hydrationML)) / \(Int(summary.hydrationGoalML)) mL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(Color.accentColor)
            if progress < 1 {
                Text("Add \(Int(summary.hydrationGoalML - summary.hydrationML)) mL more to hit today’s hydration goal.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Hydration goal met—nice job staying ahead of GLP‑1 side effects.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    FluidIntakeCard(summary: DailySummary(date: Date(),
                                          caloriesIn: 1500,
                                          caloriesGoal: 1800,
                                          caloriesOut: 300,
                                          carbs: 120,
                                          protein: 80,
                                          fat: 60,
                                          fiber: 24,
                                          fiberGoal: 30,
                                          hydrationML: 1500,
                                          hydrationGoalML: 2000,
                                          medicationPhase: .titration))
        .padding()
}
