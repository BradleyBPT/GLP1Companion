import SwiftUI
import SwiftData

struct MedicationScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var schedule: MedicationSchedule

    @State private var selectedMedicationID: String
    @State private var medicationName: String
    @State private var currentDose: String
    @State private var phase: MedicationPhase
    @State private var nextDoseDate: Date?
    @State private var notes: String

    init(schedule: MedicationSchedule) {
        self._schedule = Bindable(schedule)
        let medID = schedule.medicationID ?? GLP1MedicationLibrary.customID
        _selectedMedicationID = State(initialValue: medID)
        _medicationName = State(initialValue: schedule.medicationName)
        _currentDose = State(initialValue: schedule.currentDose)
        _phase = State(initialValue: schedule.phase)
        _nextDoseDate = State(initialValue: schedule.nextDoseDate)
        _notes = State(initialValue: schedule.notes ?? "")
    }

    var body: some View {
        Form {
            Section(header: Text("Medication")) {
                Picker("Brand", selection: $selectedMedicationID) {
                    ForEach(GLP1MedicationLibrary.medications) { medication in
                        Text(medication.brandName).tag(medication.id)
                    }
                    Text("Custom entry").tag(GLP1MedicationLibrary.customID)
                }

                if isCustomMedication {
                    TextField("Medication name", text: $medicationName)
                } else if let medication = currentLibraryMedication {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(medication.brandName)
                            .font(.body.weight(.semibold))
                        Text("Generic: \(medication.genericName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(medication.frequency)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !doseOptions.isEmpty {
                    Picker("Dose", selection: $currentDose) {
                        ForEach(doseOptions, id: \.self) { dose in
                            Text(dose).tag(dose)
                        }
                    }
                    .onChange(of: phase) { _, _ in
                        if !doseOptions.contains(currentDose), let first = doseOptions.first {
                            currentDose = first
                        }
                    }
                    .onChange(of: selectedMedicationID) { _, _ in
                        if !doseOptions.contains(currentDose), let first = doseOptions.first {
                            currentDose = first
                        }
                    }
                } else {
                    TextField("Current dose", text: $currentDose)
                }

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

            if let medication = currentLibraryMedication {
                Section(header: Text("About \(medication.brandName)")) {
                    Text(medication.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
                .disabled(isCustomMedication && medicationName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: selectedMedicationID) { _, _ in
            if let medication = currentLibraryMedication {
                medicationName = medication.brandName
                if let first = doseOptions.first {
                    currentDose = first
                }
            }
        }
        .onAppear {
            if !isCustomMedication, let medication = currentLibraryMedication {
                medicationName = medication.brandName
                if let first = doseOptions.first {
                    currentDose = first
                }
            }
        }
    }

    private var phaseGuidanceTitle: String {
        switch phase {
        case .titration:
            return "Increase fibre slowly to \(Int(phase.suggestedFibreTarget))g per day to reduce GI side effects."
        case .maintenance:
            return "Stay consistent with \(Int(phase.suggestedFibreTarget))g fibre and balanced meals."
        case .pause:
            return "While paused, keep fibre near \(Int(phase.suggestedFibreTarget))g to support appetite control."
        }
    }

    private var phaseGuidance: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fibre target: \(Int(phase.suggestedFibreTarget))g")
            let adjustment = phase.suggestedCalorieOffset
            if adjustment > 0 {
                Text("Calorie guidance: +\(Int(adjustment)) kcal vs baseline.")
            } else if adjustment < 0 {
                Text("Calorie guidance: \(Int(adjustment)) kcal vs baseline.")
            } else {
                Text("Calorie guidance: Maintain current baseline.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func saveChanges() {
        if isCustomMedication {
            schedule.medicationID = nil
            schedule.medicationName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let medication = currentLibraryMedication {
            schedule.medicationID = medication.id
            schedule.medicationName = medication.brandName
        }
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

    private var currentLibraryMedication: GLP1Medication? {
        selectedMedicationID == GLP1MedicationLibrary.customID ? nil : GLP1MedicationLibrary.medication(with: selectedMedicationID)
    }

    private var isCustomMedication: Bool {
        selectedMedicationID == GLP1MedicationLibrary.customID
    }

    private var doseOptions: [String] {
        guard let medication = currentLibraryMedication else { return [] }
        switch phase {
        case .titration:
            return medication.titrationDoses
        case .maintenance, .pause:
            return medication.maintenanceDoses
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: MedicationSchedule.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let schedule = MedicationSchedule()
    container.mainContext.insert(schedule)
    return NavigationStack {
        MedicationScheduleView(schedule: schedule)
    }
    .modelContainer(container)
}
