import SwiftUI
import SwiftData

struct PrivacyDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Consent.dateChanged, order: .forward) private var consents: [Consent]

    var body: some View {
        List {
            Section(header: Text("Privacy & Consent")) {
                Text("All data stays on this device. Toggle consent for categories below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Consents")) {
                ForEach(consents) { c in
                    Toggle(isOn: Binding(get: { c.status }, set: { newVal in
                        c.status = newVal
                        c.dateChanged = Date()
                        do {
                            try context.save()
                            let audit = AuditLog(actionType: .consentChange, timestamp: Date(), targetEntity: "Consent", details: "\(c.category.rawValue):\(newVal)")
                            context.insert(audit)
                            try context.save()
                        } catch {
                            print("PrivacyDashboardView.toggle save error: \(error)")
                        }
                    })) {
                        Text(c.category.rawValue.capitalized)
                    }
                }
            }
        }
        .navigationTitle("Privacy")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    PrivacyDashboardView()
}
