import Foundation
import SwiftData

@MainActor
final class GoalsManager: ObservableObject {
    private let context: ModelContext
    @Published private(set) var goals: NutritionGoals

    init(context: ModelContext) {
        self.context = context

        if let existing = try? context.fetch(FetchDescriptor<NutritionGoals>()).first {
            goals = existing
        } else {
            let defaultGoals = NutritionGoals()
            context.insert(defaultGoals)
            do {
                try context.save()
            } catch {
                print("GoalsManager.save initial goals error: \(error)")
            }
            goals = defaultGoals
        }
    }

    func update(calories: Double,
                carbs: Double,
                protein: Double,
                fat: Double,
                fiber: Double,
                hydration: Double,
                allowedFluids: [FluidType]) {
        goals.dailyCalories = calories
        goals.dailyCarbs = carbs
        goals.dailyProtein = protein
        goals.dailyFat = fat
        goals.dailyFiber = fiber
        goals.dailyHydrationML = hydration
        goals.hydrationTypesEnabled = allowedFluids.map { $0.rawValue }
        goals.updatedAt = Date()
        appendHistory(reason: .manual)
        do {
            try context.save()
        } catch {
            print("GoalsManager.update error: \(error)")
        }
        objectWillChange.send()
    }

    func adjustForMedicationPhase(_ phase: MedicationPhase, baseGoals: NutritionGoals) {
        goals.dailyFiber = phase.suggestedFibreTarget
        goals.dailyCalories = baseGoals.dailyCalories + phase.suggestedCalorieOffset
        goals.updatedAt = Date()
        appendHistory(reason: .coachAdvice)
        do {
            try context.save()
        } catch {
            print("GoalsManager.adjust error: \(error)")
        }
        objectWillChange.send()
    }

    private func appendHistory(reason: GoalChangeReason) {
        let entry = GoalHistoryEntry(date: Date(),
                                     calories: goals.dailyCalories,
                                     carbs: goals.dailyCarbs,
                                     protein: goals.dailyProtein,
                                     fat: goals.dailyFat,
                                     fiber: goals.dailyFiber,
                                     reason: reason,
                                     notes: nil)
        goals.history.append(entry)
    }
}
