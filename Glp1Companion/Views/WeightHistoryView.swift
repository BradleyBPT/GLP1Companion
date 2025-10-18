import SwiftUI

struct WeightHistoryView: View {
    let records: [Record]
    let unit: WeightUnit

    var body: some View {
        List(records) { record in
            if let value = record.value, let kg = Double(value) {
                let converted = unit.convertFromKG(kg)
                let formatted = String(format: unit == .kilograms ? "%.2f kg" : "%.2f st", converted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatted)
                        .font(.body.weight(.semibold))
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Weight history")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    let now = Date()
    let records = [
        Record(type: .weight, date: now, value: "72.5"),
        Record(type: .weight, date: now.addingTimeInterval(-86400), value: "73.1")
    ]
    NavigationStack {
        WeightHistoryView(records: records, unit: .kilograms)
    }
}
