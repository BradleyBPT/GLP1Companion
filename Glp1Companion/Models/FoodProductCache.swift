import Foundation
import SwiftData

@Model
final class FoodProductCache {
    @Attribute(.unique) var barcode: String
    var name: String
    var calories: Double?
    var carbs: Double?
    var protein: Double?
    var fat: Double?
    var fiber: Double?
    var alertSummary: String?
    var updatedAt: Date

    init(barcode: String,
         name: String,
         calories: Double? = nil,
         carbs: Double? = nil,
         protein: Double? = nil,
         fat: Double? = nil,
         fiber: Double? = nil,
         alertSummary: String? = nil,
         updatedAt: Date = Date()) {
        self.barcode = barcode
        self.name = name
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.fiber = fiber
        self.alertSummary = alertSummary
        self.updatedAt = updatedAt
    }
}
