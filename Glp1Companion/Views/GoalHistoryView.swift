import SwiftUI

struct GoalHistoryView: View {
    let history: [GoalHistoryEntry]

    var body: some View {
        List(history) { entry in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.reason.description)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Calories: \(Int(entry.calories)) kcal")
                    .font(.caption)
                Text("Macros: C \(Int(entry.carbs))g • P \(Int(entry.protein))g • F \(Int(entry.fat))g")
                    .font(.caption)
                Text("Fibre: \(Int(entry.fiber))g")
                    .font(.caption)
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Goal history")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    let entries = [
        GoalHistoryEntry(date: Date(), calories: 1800, carbs: 120, protein: 80, fat: 60, fiber: 28, reason: .manual, notes: "Initial goals"),
        GoalHistoryEntry(date: Date().addingTimeInterval(-86400), calories: 1600, carbs: 110, protein: 90, fat: 55, fiber: 30, reason: .titrationStart, notes: "Dose increased" )
    ]
    return NavigationStack {
        GoalHistoryView(history: entries)
    }
}
