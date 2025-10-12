import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            DailyDashboardView()
                .navigationTitle("Health Companion")
                .toolbar {
                    NavigationLink(destination: PrivacyDashboardView()) {
                        Image(systemName: "shield.lefthalf.fill")
                    }
                }
        }
    }
}

#Preview {
    MainView()
}
