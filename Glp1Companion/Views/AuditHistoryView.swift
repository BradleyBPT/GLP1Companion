import SwiftUI
import SwiftData

struct AuditHistoryView: View {
    @Query(sort: \AuditLog.timestamp, order: .reverse) private var logs: [AuditLog]

    var body: some View {
        List {
            if logs.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No activity yet")
                            .font(.headline)
                        Text("As you add, edit, or delete entries, they will appear here for traceability.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
                }
            } else {
                ForEach(logs) { log in
                    AuditLogRow(log: log)
                }
            }
        }
        .navigationTitle("Activity Log")
        .listStyle(.insetGrouped)
    }
}

private struct AuditLogRow: View {
    let log: AuditLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.actionType.displayName)
                    .font(.headline)
                Spacer()
                Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(log.targetEntity)
                .font(.subheadline.weight(.semibold))
            if let details = log.details, !details.isEmpty {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension AuditActionType {
    var displayName: String {
        switch self {
        case .create:
            return "Created"
        case .update:
            return "Updated"
        case .delete:
            return "Deleted"
        case .consentChange:
            return "Consent Change"
        }
    }
}

#Preview {
    NavigationStack {
        AuditHistoryView()
            .modelContainer(for: [AuditLog.self], inMemory: true)
    }
}
