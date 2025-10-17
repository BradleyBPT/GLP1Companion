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

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         dailyCalories: Double = 1800,
         dailyCarbs: Double = 130,
         dailyProtein: Double = 90,
         dailyFat: Double = 60,
         dailyFiber: Double = 30) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dailyCalories = dailyCalories
        self.dailyCarbs = dailyCarbs
        self.dailyProtein = dailyProtein
        self.dailyFat = dailyFat
        self.dailyFiber = dailyFiber
    }
}
