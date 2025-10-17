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
    @State private var hydrationText: String
    @State private var selectedFluids: Set<FluidType>

    init(goals: NutritionGoals) {
        self._goals = Bindable(goals)
        _calorieText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyCalories))
        _carbsText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyCarbs))
        _proteinText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyProtein))
        _fatText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyFat))
        _fiberText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyFiber))
        _hydrationText = State(initialValue: GoalsSettingsView.formatNumber(goals.dailyHydrationML))
        let allowed = Set(goals.hydrationTypesEnabled.compactMap { FluidType(rawValue: $0) })
        _selectedFluids = State(initialValue: allowed.isEmpty ? Set(FluidType.allCases) : allowed)
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

                Section(header: Text("Hydration")) {
                    NumericGoalField(title: "Daily goal", suffix: "mL", text: $hydrationText)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Count these beverages:")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(FluidType.allCases) { type in
                            Toggle(type.displayName, isOn: Binding(
                                get: { selectedFluids.contains(type) },
                                set: { enabled in
                                    if enabled { selectedFluids.insert(type) } else { selectedFluids.remove(type) }
                                }
                            ))
                        }
                    }
                }

                if !goals.history.isEmpty {
                    Section(header: Text("Goal History")) {
                        NavigationLink("View history") {
                            GoalHistoryView(history: goals.history.sorted(by: { $0.date > $1.date }))
                        }
                    }
                }
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
        [calorieText, carbsText, proteinText, fatText, fiberText, hydrationText]
            .allSatisfy {
                if let value = GoalsSettingsView.parseNumber($0) { return value > 0 }
                return false
            }
            && !selectedFluids.isEmpty
    }

    private func saveChanges() {
        goals.dailyCalories = GoalsSettingsView.parseNumber(calorieText) ?? goals.dailyCalories
        goals.dailyCarbs = GoalsSettingsView.parseNumber(carbsText) ?? goals.dailyCarbs
        goals.dailyProtein = GoalsSettingsView.parseNumber(proteinText) ?? goals.dailyProtein
        goals.dailyFat = GoalsSettingsView.parseNumber(fatText) ?? goals.dailyFat
        goals.dailyFiber = GoalsSettingsView.parseNumber(fiberText) ?? goals.dailyFiber
        goals.dailyHydrationML = GoalsSettingsView.parseNumber(hydrationText) ?? goals.dailyHydrationML
        goals.hydrationTypesEnabled = selectedFluids.map { $0.rawValue }
        let entry = GoalHistoryEntry(date: Date(),
                                     calories: goals.dailyCalories,
                                     carbs: goals.dailyCarbs,
                                     protein: goals.dailyProtein,
                                     fat: goals.dailyFat,
                                     fiber: goals.dailyFiber,
                                     reason: .manual,
                                     notes: "Updated via goal settings")
        goals.history.append(entry)
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
