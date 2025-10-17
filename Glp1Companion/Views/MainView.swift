import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            DailyDashboardView()
                .navigationTitle("Health Companion")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        NavigationLink(destination: MedicationScheduleContainerView()) {
                            Image(systemName: "pills.fill")
                        }
                        NavigationLink(destination: AuditHistoryView()) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        NavigationLink(destination: PrivacyDashboardView()) {
                            Image(systemName: "shield.lefthalf.fill")
                        }
                    }
                }
        }
    }
}

#Preview {
    MainView()
}
