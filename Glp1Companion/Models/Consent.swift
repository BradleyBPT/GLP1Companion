import Foundation
import SwiftData

enum ConsentCategory: String, Codable, CaseIterable {
    case meals
    case hydration
    case symptoms
    case medication
    case weight
    case activity
}

@Model
final class Consent {
    @Attribute(.unique) var id: UUID
    var category: ConsentCategory
    var status: Bool
    var dateChanged: Date

    init(id: UUID = UUID(), category: ConsentCategory, status: Bool = true, dateChanged: Date = Date()) {
        self.id = id
        self.category = category
        self.status = status
        self.dateChanged = dateChanged
    }
}

extension ConsentCategory: Identifiable {
    var id: String { rawValue }
}

extension ConsentCategory {
    var permissionTitle: String {
        switch self {
        case .meals:
            return "Meal logging"
        case .hydration:
            return "Hydration tracking"
        case .symptoms:
            return "Symptom logging"
        case .medication:
            return "Medication logging"
        case .weight:
            return "Weight tracking"
        case .activity:
            return "Activity tracking"
        }
    }

    var permissionDescription: String {
        switch self {
        case .meals:
            return "Saves meal descriptions and calories you add."
        case .hydration:
            return "Keeps a history of water intake entries."
        case .symptoms:
            return "Stores symptom notes, glucose readings, and mood logs."
        case .medication:
            return "Tracks medications, doses, and reminders you record."
        case .weight:
            return "Logs weight readings for daily trends."
        case .activity:
            return "Stores exercise sessions and imported step counts."
        }
    }
}
