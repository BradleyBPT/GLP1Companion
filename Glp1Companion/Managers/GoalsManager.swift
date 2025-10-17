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

    func update(calories: Double, carbs: Double, protein: Double, fat: Double, fiber: Double) {
        goals.dailyCalories = calories
        goals.dailyCarbs = carbs
        goals.dailyProtein = protein
        goals.dailyFat = fat
        goals.dailyFiber = fiber
        goals.updatedAt = Date()
        do {
            try context.save()
        } catch {
            print("GoalsManager.update error: \(error)")
        }
        objectWillChange.send()
    }
}
