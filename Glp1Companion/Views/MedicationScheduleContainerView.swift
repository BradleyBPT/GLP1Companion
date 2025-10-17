import SwiftUI
import SwiftData

struct MedicationScheduleContainerView: View {
    @Environment(\.modelContext) private var context
    @Query private var schedules: [MedicationSchedule]

    var body: some View {
        if let schedule = schedules.first {
            MedicationScheduleView(schedule: schedule)
        } else {
            ProgressView()
                .onAppear {
                    let schedule = MedicationSchedule()
                    context.insert(schedule)
                    do {
                        try context.save()
                    } catch {
                        print("MedicationScheduleContainerView seeding error: \(error)")
                    }
                }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: MedicationSchedule.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let schedule = MedicationSchedule()
    container.mainContext.insert(schedule)
    return MedicationScheduleContainerView().modelContainer(container)
}
