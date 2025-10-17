import Foundation
import SwiftData

enum MedicationPhase: String, Codable, CaseIterable, Identifiable {
    case titration
    case maintenance
    case pause

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .titration: return "Titration"
        case .maintenance: return "Maintenance"
        case .pause: return "Pause"
        }
    }

    var suggestedFibreTarget: Double {
        switch self {
        case .titration: return 25
        case .maintenance: return 30
        case .pause: return 25
        }
    }

    var suggestedCalorieOffset: Double {
        switch self {
        case .titration: return -200
        case .maintenance: return 0
        case .pause: return 100
        }
    }
}

@Model
final class MedicationSchedule {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var medicationName: String
    var currentDose: String
    var phase: MedicationPhase
    var nextDoseDate: Date?
    var notes: String?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         medicationName: String = "GLP-1",
         currentDose: String = "0.25 mg",
         phase: MedicationPhase = .titration,
         nextDoseDate: Date? = nil,
         notes: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.medicationName = medicationName
        self.currentDose = currentDose
        self.phase = phase
        self.nextDoseDate = nextDoseDate
        self.notes = notes
    }
}
