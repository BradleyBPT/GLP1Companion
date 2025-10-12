import Foundation
import SwiftData

enum AuditActionType: String, Codable {
    case create
    case update
    case delete
    case consentChange
}

@Model
final class AuditLog {
    @Attribute(.unique) var id: UUID
    var actionType: AuditActionType
    var timestamp: Date
    var targetEntity: String
    var details: String?

    init(id: UUID = UUID(), actionType: AuditActionType, timestamp: Date = Date(), targetEntity: String, details: String? = nil) {
        self.id = id
        self.actionType = actionType
        self.timestamp = timestamp
        self.targetEntity = targetEntity
        self.details = details
    }
}
