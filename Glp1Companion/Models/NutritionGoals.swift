import Foundation
import SwiftData

@Model
final class NutritionGoals {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var dailyCalories: Double
    var dailyCarbs: Double
    var dailyProtein: Double
    var dailyFat: Double
    var dailyFiber: Double
    var dailyHydrationML: Double
    var hydrationTypesEnabled: [FluidType.RawValue]
    @Relationship(deleteRule: .cascade) var history: [GoalHistoryEntry] = []

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         dailyCalories: Double = 1800,
         dailyCarbs: Double = 130,
         dailyProtein: Double = 90,
         dailyFat: Double = 60,
         dailyFiber: Double = 30,
         dailyHydrationML: Double = 2000,
         hydrationTypesEnabled: [FluidType.RawValue] = FluidType.allCases.map { $0.rawValue }) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dailyCalories = dailyCalories
        self.dailyCarbs = dailyCarbs
        self.dailyProtein = dailyProtein
        self.dailyFat = dailyFat
        self.dailyFiber = dailyFiber
        self.dailyHydrationML = dailyHydrationML
        self.hydrationTypesEnabled = hydrationTypesEnabled
    }
}
