//
//  Glp1CompanionApp.swift
//  Glp1Companion
//
//  Created by Bradley Coupar on 12/10/2025.
//

import SwiftUI
import SwiftData

@main
struct Glp1CompanionApp: App {
    let container: ModelContainer

    init() {
    // Create a ModelContainer for our app models. For simplicity we use try! here;
    // in production consider handling initialization failures more gracefully.
    container = try! ModelContainer(for: User.self,
                                    Record.self,
                                    Consent.self,
                                    AuditLog.self,
                                    NutritionGoals.self,
                                    FoodProductCache.self,
                                    MedicationSchedule.self,
                                    FluidIntakeLog.self,
                                    GoalHistoryEntry.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
