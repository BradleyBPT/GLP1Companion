import Foundation
import SwiftData

@MainActor
final class PrivacyManager: ObservableObject {
    @Published private(set) var consents: [Consent] = []
    private let context: ModelContext
    private let audit: AuditManager

    init(context: ModelContext, audit: AuditManager) {
        self.context = context
        self.audit = audit
        fetchAll()
        ensureDefaults()
    }

    func fetchAll() {
        let req = FetchDescriptor<Consent>()
        do {
            consents = try context.fetch(req)
        } catch {
            print("PrivacyManager.fetchAll error: \(error)")
            consents = []
        }
    }

    func ensureDefaults() {
        // Ensure there is a consent object for each category
        let categories: [ConsentCategory] = [.meals, .hydration, .symptoms, .medication, .weight, .activity]
        for cat in categories {
            if !consents.contains(where: { $0.category == cat }) {
                let c = Consent(category: cat, status: true)
                context.insert(c)
                audit.log(action: .create, target: "Consent", details: cat.rawValue)
            }
        }
        do { try context.save(); fetchAll() } catch { print("PrivacyManager.ensureDefaults save error: \(error)") }
    }

    func set(_ category: ConsentCategory, enabled: Bool) {
        guard let c = consents.first(where: { $0.category == category }) else { return }
        c.status = enabled
        c.dateChanged = Date()
        do {
            try context.save()
            audit.log(action: .consentChange, target: "Consent", details: "\(category.rawValue):\(enabled)")
            fetchAll()
        } catch {
            print("PrivacyManager.set error: \(error)")
        }
    }

    func isEnabled(_ category: ConsentCategory) -> Bool {
        consents.first(where: { $0.category == category })?.status ?? true
    }
}
