import Foundation
import SwiftData

enum FluidType: String, Codable, CaseIterable, Identifiable {
    case water
    case tea
    case coffee
    case electrolyte
    case soup
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: return "Water"
        case .tea: return "Tea"
        case .coffee: return "Coffee"
        case .electrolyte: return "Electrolyte"
        case .soup: return "Soup/Broth"
        case .other: return "Other"
        }
    }
}

@Model
final class FluidIntakeLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amountML: Double
    var type: FluidType
    var notes: String?

    init(id: UUID = UUID(), date: Date = Date(), amountML: Double, type: FluidType, notes: String? = nil) {
        self.id = id
        self.date = date
        self.amountML = amountML
        self.type = type
        self.notes = notes
    }
}
