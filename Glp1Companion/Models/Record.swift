import Foundation
import SwiftData

enum RecordType: String, Codable {
    case meal
    case hydration
    case symptom
    case medication
    case weight
    case activity
}

@Model
final class Record {
    @Attribute(.unique) var id: UUID
    var type: RecordType
    var date: Date
    var value: String?
    var note: String?

    init(id: UUID = UUID(), type: RecordType, date: Date = Date(), value: String? = nil, note: String? = nil) {
        self.id = id
        self.type = type
        self.date = date
        self.value = value
        self.note = note
    }
}
