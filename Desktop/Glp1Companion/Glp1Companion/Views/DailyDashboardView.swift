import SwiftUI
import SwiftData

struct DailyDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Record.date, order: .forward) private var records: [Record]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(Date(), style: .date)
                        .font(.title2)
                    Text("Daily overview")
                        .font(.headline)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: {
                        let dm = DataManager(context: context, audit: AuditManager(context: context))
                        dm.addHydration(amountML: 200)
                    }) {
                        Label("200 mL", systemImage: "drop.fill")
                            .padding(10)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        let dm = DataManager(context: context, audit: AuditManager(context: context))
                        dm.addMedication(name: "Metformin", dose: "500mg")
                    }) {
                        Label("Med 500mg", systemImage: "pills.fill")
                            .padding(10)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        let dm = DataManager(context: context, audit: AuditManager(context: context))
                        dm.addGlucose(mgPerDL: 5.6)
                    }) {
                        Label("Glucose", systemImage: "drop.triangle")
                            .padding(10)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        let dm = DataManager(context: context, audit: AuditManager(context: context))
                        dm.addWeight(kg: 72.3)
                    }) {
                        Label("Weight", systemImage: "scalemass")
                            .padding(10)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        let dm = DataManager(context: context, audit: AuditManager(context: context))
                        dm.addExercise(minutes: 30, description: "Walk")
                    }) {
                        Label("Exercise", systemImage: "figure.walk")
                            .padding(10)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        let dm = DataManager(context: context, audit: AuditManager(context: context))
                        dm.addMeal(description: "Lunch: Salad")
                    }) {
                        Label("Meal", systemImage: "fork.knife")
                            .padding(10)
                            .background(Color.yellow.opacity(0.12))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        let dm = DataManager(context: context, audit: AuditManager(context: context))
                        dm.addMood(level: 4)
                    }) {
                        Label("Mood", systemImage: "face.smiling")
                            .padding(10)
                            .background(Color.pink.opacity(0.12))
                            .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            List {
                ForEach(records) { r in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.type.rawValue.capitalized)
                                .font(.headline)
                            if let note = r.note { Text(note).font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text(r.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)

            Spacer()
        }
        .padding()
    }

    private func addHydration() {
        let record = Record(type: .hydration, value: "200", note: "Quick add: 200 mL")
        context.insert(record)
        do {
            try context.save()
            // also log audit entry
            let audit = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: "hydration:200")
            context.insert(audit)
            try context.save()
        } catch {
            print("DailyDashboardView.addHydration save error: \(error)")
        }
    }
}

#Preview {
    DailyDashboardView()
}
