import SwiftUI
import SwiftData

struct PrivacyDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Consent.dateChanged, order: .forward) private var consents: [Consent]

    var body: some View {
        List {
            Section(header: Text("Privacy & Consent")) {
                Text("Choose which logs you want to keep on this device. You can change these anytime.")
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.category.permissionTitle)
                                .font(.body.weight(.semibold))
                            Text(c.category.permissionDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
