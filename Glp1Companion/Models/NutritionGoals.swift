import Foundation
import SwiftData

@Model
final class NutritionGoals {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var dailyCalories: Double = 1800
    var dailyCarbs: Double = 130
    var dailyProtein: Double = 90
    var dailyFat: Double = 60
    var dailyFiber: Double = 30
    var dailyHydrationML: Double = 2000
    var hydrationTypesRaw: String = FluidType.allCases.map { $0.rawValue }.joined(separator: ",")
    var preferredWeightUnitRaw: String = WeightUnit.kilograms.rawValue
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
         hydrationTypesRaw: String = FluidType.allCases.map { $0.rawValue }.joined(separator: ","),
         preferredWeightUnitRaw: String = WeightUnit.kilograms.rawValue) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dailyCalories = dailyCalories
        self.dailyCarbs = dailyCarbs
        self.dailyProtein = dailyProtein
        self.dailyFat = dailyFat
        self.dailyFiber = dailyFiber
        self.dailyHydrationML = dailyHydrationML
        self.hydrationTypesRaw = hydrationTypesRaw
        self.preferredWeightUnitRaw = preferredWeightUnitRaw
    }

    var preferredWeightUnit: WeightUnit {
        get { WeightUnit(rawValue: preferredWeightUnitRaw) ?? .kilograms }
        set { preferredWeightUnitRaw = newValue.rawValue }
    }

    var hydrationTypesEnabled: [FluidType] {
        get {
            hydrationTypesRaw.split(separator: ",").compactMap { FluidType(rawValue: String($0)) }
        }
        set {
            hydrationTypesRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }
}
