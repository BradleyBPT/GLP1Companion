import SwiftUI
import SwiftData

struct GoalsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var goals: NutritionGoals

    @State private var calorieText: String
    @State private var carbsText: String
    @State private var proteinText: String
    @State private var fatText: String
    @State private var fiberText: String

    init(goals: NutritionGoals) {
        self._goals = Bindable(goals)
        _calorieText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyCalories))
        _carbsText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyCarbs))
        _proteinText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyProtein))
        _fatText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyFat))
        _fiberText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyFiber))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Daily Targets")) {
                    NumericGoalField(title: "Calories", suffix: "kcal", text: $calorieText)
                    NumericGoalField(title: "Carbs", suffix: "g", text: $carbsText)
                    NumericGoalField(title: "Protein", suffix: "g", text: $proteinText)
                    NumericGoalField(title: "Fat", suffix: "g", text: $fatText)
                    NumericGoalField(title: "Fibre", suffix: "g", text: $fiberText)
                }
                Section(footer: Text("Fibre helps GLP-1 medication users manage satiety and digestion. Aim for at least 30g per day unless your clinician advises otherwise.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)) { EmptyView() }
            }
            .navigationTitle("Nutrition Goals")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        [calorieText, carbsText, proteinText, fatText, fiberText]
            .allSatisfy {
                if let value = GoalsSettingsView.parseNumber($0) { return value > 0 }
                return false
            }
    }

    private func saveChanges() {
        goals.dailyCalories = GoalsSettingsView.parseNumber(calorieText) ?? goals.dailyCalories
        goals.dailyCarbs = GoalsSettingsView.parseNumber(carbsText) ?? goals.dailyCarbs
        goals.dailyProtein = GoalsSettingsView.parseNumber(proteinText) ?? goals.dailyProtein
        goals.dailyFat = GoalsSettingsView.parseNumber(fatText) ?? goals.dailyFat
        goals.dailyFiber = GoalsSettingsView.parseNumber(fiberText) ?? goals.dailyFiber
        goals.updatedAt = Date()
        do {
            try context.save()
        } catch {
            print("GoalsSettingsView.save error: \(error)")
        }
    }

    private static func parseNumber(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func formatNumber(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

private struct NumericGoalField: View {
    let title: String
    let suffix: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: NutritionGoals.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let goals = NutritionGoals()
    container.mainContext.insert(goals)
    return GoalsSettingsView(goals: goals)
        .modelContainer(container)
}
