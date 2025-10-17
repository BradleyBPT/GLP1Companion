import Foundation
import SwiftData

@MainActor
final class AuditManager: ObservableObject {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func log(action: AuditActionType, target: String, details: String? = nil) {
        let entry = AuditLog(actionType: action, timestamp: Date(), targetEntity: target, details: details)
        context.insert(entry)
        do {
            try context.save()
        } catch {
            print("AuditManager.log save error: \(error)")
        }
    }
}
