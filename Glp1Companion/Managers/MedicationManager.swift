import Foundation
import SwiftData

@MainActor
final class MedicationManager: ObservableObject {
    private let context: ModelContext
    @Published private(set) var schedule: MedicationSchedule

    init(context: ModelContext) {
        self.context = context
        if let existing = try? context.fetch(FetchDescriptor<MedicationSchedule>()).first {
            schedule = existing
        } else {
            let defaultSchedule = MedicationSchedule()
            context.insert(defaultSchedule)
            do {
                try context.save()
            } catch {
                print("MedicationManager initial save error: \(error)")
            }
            schedule = defaultSchedule
        }
    }

    func update(medicationID: String?, name: String, dose: String, phase: MedicationPhase, nextDose: Date?, notes: String?) {
        schedule.medicationID = medicationID
        schedule.medicationName = name
        schedule.currentDose = dose
        schedule.phase = phase
        schedule.nextDoseDate = nextDose
        schedule.notes = notes
        schedule.updatedAt = Date()
        do {
            try context.save()
        } catch {
            print("MedicationManager update error: \(error)")
        }
        objectWillChange.send()
    }
}
