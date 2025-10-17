import Foundation
import SwiftData

enum GoalChangeReason: String, Codable, CaseIterable, Identifiable {
    case titrationStart
    case titrationIncrease
    case maintenance
    case pauseMedication
    case coachAdvice
    case manual

    var id: String { rawValue }

    var description: String {
        switch self {
        case .titrationStart: return "Titration start"
        case .titrationIncrease: return "Dose increase"
        case .maintenance: return "Maintenance adjustment"
        case .pauseMedication: return "Medication pause"
        case .coachAdvice: return "Coach recommendation"
        case .manual: return "Manual update"
        }
    }
}

@Model
final class GoalHistoryEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var calories: Double
    var carbs: Double
    var protein: Double
    var fat: Double
    var fiber: Double
    var reason: GoalChangeReason
    var notes: String?

    init(id: UUID = UUID(),
         date: Date = Date(),
         calories: Double,
         carbs: Double,
         protein: Double,
         fat: Double,
         fiber: Double,
         reason: GoalChangeReason,
         notes: String? = nil) {
        self.id = id
        self.date = date
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.fiber = fiber
        self.reason = reason
        self.notes = notes
    }
}
