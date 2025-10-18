import Foundation
import SwiftData

enum RecordType: String, Codable {
    case meal
    case hydration
    case symptom
    case medication
    case weight
    case activity
    case mood
}

@Model
final class Record {
    @Attribute(.unique) var id: UUID
    var type: RecordType
    var date: Date
    var value: String?
    var note: String?
    var calories: Double?
    var carbs: Double?
    var protein: Double?
    var fat: Double?
    var fiber: Double?

    init(id: UUID = UUID(), type: RecordType, date: Date = Date(), value: String? = nil, note: String? = nil, calories: Double? = nil, carbs: Double? = nil, protein: Double? = nil, fat: Double? = nil, fiber: Double? = nil) {
        self.id = id
        self.type = type
        self.date = date
        self.value = value
        self.note = note
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.fiber = fiber
    }
}
