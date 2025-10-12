import Foundation
import SwiftData

enum ConsentCategory: String, Codable {
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
