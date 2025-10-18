import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case stones

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kilograms: return "Kilograms"
        case .stones: return "Stones"
        }
    }

    func format(kg: Double) -> String {
        switch self {
        case .kilograms:
            return String(format: "%.1f kg", kg)
        case .stones:
            let stonesValue = kg / 6.35029318
            return String(format: "%.1f st", stonesValue)
        }
    }

    func convertToKG(value: Double) -> Double {
        switch self {
        case .kilograms:
            return value
        case .stones:
            return value * 6.35029318
        }
    }

    func convertFromKG(_ kg: Double) -> Double {
        switch self {
        case .kilograms:
            return kg
        case .stones:
            return kg / 6.35029318
        }
    }
}
