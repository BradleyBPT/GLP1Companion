import SwiftUI
import SwiftData

struct MedicationScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var schedule: MedicationSchedule

    @State private var medicationName: String
    @State private var currentDose: String
    @State private var phase: MedicationPhase
    @State private var nextDoseDate: Date?
    @State private var notes: String

    init(schedule: MedicationSchedule) {
        self._schedule = Bindable(schedule)
        _medicationName = State(initialValue: schedule.medicationName)
        _currentDose = State(initialValue: schedule.currentDose)
        _phase = State(initialValue: schedule.phase)
        _nextDoseDate = State(initialValue: schedule.nextDoseDate)
        _notes = State(initialValue: schedule.notes ?? "")
    }

    var body: some View {
        Form {
            Section(header: Text("Medication")) {
                TextField("Medication name", text: $medicationName)
                TextField("Current dose", text: $currentDose)
                Picker("Phase", selection: $phase) {
                    ForEach(MedicationPhase.allCases) { phase in
                        Text(phase.displayName).tag(phase)
                    }
                }
                Toggle("Schedule next dose", isOn: Binding(
                    get: { nextDoseDate != nil },
                    set: { enabled in nextDoseDate = enabled ? (nextDoseDate ?? Date().addingTimeInterval(60 * 60 * 24 * 7)) : nil }
                ))
                if let _ = nextDoseDate {
                    DatePicker("Next dose", selection: Binding(
                        get: { nextDoseDate ?? Date() },
                        set: { nextDoseDate = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                }
                TextEditor(text: $notes)
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
            }

            Section(header: Text("Phase guidance"), footer: phaseGuidance) {
                Text(phaseGuidanceTitle)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .navigationTitle("Medication schedule")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .disabled(medicationName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var phaseGuidanceTitle: String {
        switch phase {
        case .titration:
            return "Increase fibre slowly and aim for \(Int(phase.suggestedFibreTarget))g per day to reduce GI side effects."
        case .maintenance:
            return "Maintain balanced meals with \(Int(phase.suggestedFibreTarget))g fibre and steady protein intake."
        case .pause:
            return "Monitor appetite and keep fibre near \(Int(phase.suggestedFibreTarget))g while off medication."
        }
    }

    private var phaseGuidance: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fibre target: \(Int(phase.suggestedFibreTarget))g")
            let calorieAdjustment = phase.suggestedCalorieOffset
            if calorieAdjustment > 0 {
                Text("Calorie guidance: +\(Int(calorieAdjustment)) kcal vs baseline.")
            } else if calorieAdjustment < 0 {
                Text("Calorie guidance: \(Int(calorieAdjustment)) kcal vs baseline.")
            } else {
                Text("Calorie guidance: Maintain current baseline.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func saveChanges() {
        schedule.medicationName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        schedule.currentDose = currentDose.trimmingCharacters(in: .whitespacesAndNewlines)
        schedule.phase = phase
        schedule.nextDoseDate = nextDoseDate
        schedule.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        schedule.updatedAt = Date()
        do {
            try context.save()
        } catch {
            print("MedicationScheduleView.save error: \(error)")
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: MedicationSchedule.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let schedule = MedicationSchedule()
    container.mainContext.insert(schedule)
    return NavigationStack {
        MedicationScheduleView(schedule: schedule)
    }.modelContainer(container)
}
