import SwiftUI
import SwiftData
import VisionKit

struct DailyDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Record.date, order: .reverse) private var records: [Record]
    @Query private var consents: [Consent]
    @Query private var goalsQuery: [NutritionGoals]
    @State private var editingRecord: Record?
    @State private var recordPendingDeletion: Record?
    @State private var showDeleteConfirmation = false
    @State private var consentPrompt: ConsentCategory?
    @State private var pendingAction: (() -> Void)?
    @State private var flashMessage: String?
    @State private var flashTimer: Timer?
    @State private var showMealSheet = false
    @State private var mealSheetState = MealEntryState()
    @State private var pendingMealAction: ((MealEntryState) -> Void)?
    @State private var showGoalsSheet = false
    @State private var isSyncingHealth = false
    @State private var lastHealthSync: Date?
    @State private var healthSyncError: String?

    private let healthKitManager = HealthKitManager()
    private var goals: NutritionGoals {
        goalsQuery.first ?? NutritionGoals()
    }
    private var summary: DailySummary {
        DailySummaryService.summarize(records: todaysRecords, goals: goals)
    }
    private var insights: [DailyInsight] {
        DailySummaryService.insights(for: summary)
    }

    private let summaryColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                headerSection
                quickActionsSection

                if let disabledBanner = disabledConsentBanner {
                    consentInfoBanner(disabledBanner)
                        .transition(.opacity)
                        .padding(.horizontal, 20)
                }

                if !summaryItems.isEmpty {
                    Text("At a glance")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    LazyVGrid(columns: summaryColumns, spacing: 16) {
                        ForEach(summaryItems) { item in
                            SummaryCard(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if !insights.isEmpty {
                    Text("Daily insights")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    VStack(spacing: 12) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Divider()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 20)

                Text("Today's Log")
                    .font(.headline)
                    .padding(.horizontal, 20)

                if todaysRecords.isEmpty {
                    emptyState
                        .padding(.horizontal, 20)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(todaysRecords.enumerated()), id: \.element.id) { index, record in
                            recordRow(for: record,
                                      isFirst: index == 0,
                                      isLast: index == todaysRecords.count - 1)
                                .contextMenu {
                                    Button("Edit", systemImage: "pencil") {
                                        editingRecord = record
                                    }
                                    Button(role: .destructive) {
                                        recordPendingDeletion = record
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .onTapGesture {
                                    editingRecord = record
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .confirmationDialog("Delete entry?", isPresented: $showDeleteConfirmation, titleVisibility: .visible, presenting: recordPendingDeletion) { record in
            Button("Delete", role: .destructive) {
                deleteRecord(record)
            }
            Button("Cancel", role: .cancel) {
                recordPendingDeletion = nil
            }
        } message: { record in
            Text("Remove the \(record.typeDisplayName.lowercased()) recorded at \(record.date.formatted(date: .omitted, time: .shortened))? This cannot be undone.")
        }
        .sheet(item: $editingRecord) { record in
            RecordEditSheet(record: record) { payload in
                updateRecord(record, with: payload)
            }
        }
        .sheet(isPresented: $showMealSheet, onDismiss: { pendingMealAction = nil }) {
            MealEntrySheet(state: $mealSheetState, onSave: { state in
                pendingMealAction?(state)
                pendingMealAction = nil
                showMealSheet = false
            }, onCancel: {
                pendingMealAction = nil
                showMealSheet = false
            })
        }
        .overlay(alignment: .top) {
            if let flash = flashMessage {
                FlashBanner(message: flash)
                    .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: flashMessage)
        .onDisappear {
            flashTimer?.invalidate()
            flashTimer = nil
        }
        .onAppear {
            ensureConsentsSeededIfNeeded()
            ensureGoalsSeededIfNeeded()
        }
        .alert(item: $consentPrompt) { category in
            Alert(
                title: Text("Enable \(category.permissionTitle)"),
                message: Text("Turn on \(category.permissionTitle.lowercased()) to save new entries."),
                primaryButton: .default(Text("Enable")) {
                    enableConsent(category)
                    pendingAction?()
                    pendingAction = nil
                },
                secondaryButton: .cancel(Text("Not now")) {
                    pendingAction = nil
                }
            )
        }
        .sheet(isPresented: $showGoalsSheet) {
            if let goals = goalsQuery.first {
                GoalsSettingsView(goals: goals)
            } else {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGoalsSheet = true
                } label: {
                    Image(systemName: "target")
                }
                .accessibilityLabel("Edit nutrition goals")
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date(), style: .date)
                .font(.title2.weight(.semibold))
            Text("Daily overview")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: syncHealthData) {
                    if isSyncingHealth {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 16, height: 16)
                        Text("Syncing…")
                    } else {
                        Label("Sync Health Data", systemImage: "arrow.clockwise")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isSyncingHealth)

                if let lastHealthSync {
                    Text("Last sync \(lastHealthSync.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let healthSyncError {
                Text(healthSyncError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
    }

    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(quickActions) { action in
                    Button(action: action.action) {
                        HStack(spacing: 8) {
                            Image(systemName: action.icon)
                                .foregroundStyle(action.tint)
                            Text(action.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(action.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 20)
    }

    private var quickActions: [QuickAction] {
        return [
            QuickAction(label: "200 mL", icon: "drop.fill", tint: .accentColor) {
                performQuickAction(for: .hydration) { $0.addHydration(amountML: 200) }
            },
            QuickAction(label: "Med 500mg", icon: "pills.fill", tint: .green) {
                performQuickAction(for: .medication) { $0.addMedication(name: "Metformin", dose: "500mg") }
            },
            QuickAction(label: "Glucose", icon: "drop.triangle", tint: .orange) {
                performQuickAction(for: .symptoms) { $0.addGlucose(mgPerDL: 5.6) }
            },
            QuickAction(label: "Weight", icon: "scalemass", tint: .blue) {
                performQuickAction(for: .weight) { $0.addWeight(kg: 72.3) }
            },
            QuickAction(label: "Exercise", icon: "figure.walk", tint: .purple) {
                performQuickAction(for: .activity) { $0.addExercise(minutes: 30, description: "Walk") }
            },
            QuickAction(label: "Meal", icon: "fork.knife", tint: Color(.systemYellow)) {
                let presentSheet = {
                    mealSheetState = MealEntryState()
                    pendingMealAction = { state in
                        performQuickAction(for: .meals) { manager in
                            manager.addMeal(description: state.description,
                                            calories: state.calories,
                                            carbs: state.carbs,
                                            protein: state.protein,
                                            fat: state.fat,
                                            fiber: state.fiber)
                        }
                        showFlash("Meal logged")
                    }
                    showMealSheet = true
                }

                if isConsentEnabled(.meals) {
                    presentSheet()
                } else {
                    pendingAction = { presentSheet() }
                    consentPrompt = .meals
                }
            },
            QuickAction(label: "Mood", icon: "face.smiling", tint: .pink) {
                performQuickAction(for: .symptoms) { $0.addMood(level: 4) }
            }
        ]
    }

    private var todaysRecords: [Record] {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.date) }
            .sorted(by: { $0.date > $1.date })
    }

    private var summaryItems: [SummaryItem] {
        let hydrationRecords = todaysRecords.filter { $0.type == .hydration }
        let hydrationTotal = hydrationRecords.compactMap { Int($0.value ?? "") }.reduce(0, +)
        let hydrationSubtitle = hydrationRecords.isEmpty
            ? "No hydration logged yet"
            : "\(hydrationRecords.count) \(hydrationRecords.count == 1 ? "entry" : "entries") recorded"

        let medicationRecords = todaysRecords.filter { $0.type == .medication }
        let medicationSubtitle: String
        if let latestMedication = medicationRecords.first {
            let time = latestMedication.date.formatted(date: .omitted, time: .shortened)
            let name = latestMedication.note ?? "Medication"
            medicationSubtitle = "\(name) at \(time)"
        } else {
            medicationSubtitle = "No medication logged yet"
        }

        let goals = goalsQuery.first ?? NutritionGoals()

        let mealRecords = todaysRecords.filter { $0.type == .meal }
        let totalMealCalories = mealRecords.compactMap { $0.calories }.reduce(0, +)
        let totalMealCaloriesInt = Int(totalMealCalories.rounded())
        let calorieGoal = max(Int(goals.dailyCalories.rounded()), 1)
        let mealCount = mealRecords.count
        let fiberTotal = mealRecords.compactMap { $0.fiber }.reduce(0, +)
        let recommendedFiber: Double = goals.dailyFiber > 0 ? goals.dailyFiber : 30
        let fiberSubtitle: String
        if fiberTotal > 0 {
            fiberSubtitle = String(format: "Fiber %.0fg of %.0fg", fiberTotal, recommendedFiber)
        } else {
            fiberSubtitle = "Log fiber to see progress"
        }

        let activityRecords = todaysRecords.filter { $0.type == .activity }
        let activityMinutes = activityRecords.compactMap { Int($0.value ?? "") }.reduce(0, +)
        let activitySteps = activityRecords.reduce(0) { total, record in
            guard let note = record.note,
                  note.lowercased().hasPrefix("steps:"),
                  let steps = Int(note.split(separator: ":").last ?? "") else { return total }
            return total + steps
        }
        let activityCalories = activityRecords.reduce(0) { total, record in
            let caloriesValue = record.calories ?? Double(calories(from: record))
            return total + Int(caloriesValue)
        }
        var activityValue = activityMinutes > 0 ? "\(activityMinutes) min" : ""
        if activityMinutes == 0 {
            if activitySteps > 0 {
                activityValue = "\(activitySteps) steps"
            } else {
                activityValue = "No activity yet"
            }
        } else if activitySteps > 0 {
            activityValue += " • \(activitySteps) steps"
        }
        if activityCalories > 0 {
            activityValue += activityValue.isEmpty || activityValue == "No activity yet"
                ? "\(activityCalories) kcal"
                : " • \(activityCalories) kcal"
        }
        let activitySubtitle = activityRecords.isEmpty
            ? "Log activity or steps to track progress"
            : {
                var subtitle = "\(activityRecords.count) \(activityRecords.count == 1 ? "entry" : "entries") today"
                if activityCalories > 0 {
                    subtitle += " • \(activityCalories) kcal burned"
                }
                return subtitle
            }()

        let netCalories = totalMealCaloriesInt - activityCalories
        let remainingCalories = calorieGoal - netCalories

        let balanceString: String
        if netCalories == 0 {
            balanceString = "Net even"
        } else if netCalories > 0 {
            balanceString = "+\(netCalories) net"
        } else {
            balanceString = "\(netCalories) net"
        }

        let remainingString: String
        if remainingCalories >= 0 {
            remainingString = "\(remainingCalories) kcal remaining"
        } else {
            remainingString = "\(abs(remainingCalories)) kcal over goal"
        }

        let mealsSubtitle = [fiberSubtitle,
                             "\(mealCount) \(mealCount == 1 ? "meal" : "meals")",
                             balanceString,
                             remainingString]
            .joined(separator: " • ")

        var items: [SummaryItem] = [
            SummaryItem(title: "Hydration", value: "\(hydrationTotal) mL", subtitle: hydrationSubtitle, icon: "drop.fill", tint: .accentColor),
            SummaryItem(title: "Medication", value: "\(medicationRecords.count) \(medicationRecords.count == 1 ? "dose" : "doses")", subtitle: medicationSubtitle, icon: "pills.fill", tint: .green),
            SummaryItem(title: "Nutrition", value: "\(totalMealCaloriesInt) / \(calorieGoal) kcal", subtitle: mealsSubtitle, icon: "fork.knife", tint: Color(.systemOrange)),
            SummaryItem(title: "Activity", value: activityValue, subtitle: activitySubtitle, icon: "figure.walk", tint: .purple)
        ]

        if let weightRecord = todaysRecords.first(where: { $0.type == .weight }) {
            let formattedValue: String
            if let valueString = weightRecord.value, let weightValue = Double(valueString) {
                formattedValue = String(format: "%.1f kg", weightValue)
            } else if let valueString = weightRecord.value {
                formattedValue = "\(valueString) kg"
            } else {
                formattedValue = "--"
            }
            let time = weightRecord.date.formatted(date: .omitted, time: .shortened)
            items.append(
                SummaryItem(
                    title: "Weight",
                    value: formattedValue,
                    subtitle: "Updated \(time)",
                    icon: "scalemass",
                    tint: .blue
                )
            )
        }

        return items
    }

    private func performQuickAction(for category: ConsentCategory, action: @escaping (DataManager) -> Void) {
        if isConsentEnabled(category) {
            withManager(action)
        } else {
            pendingAction = { withManager(action) }
            consentPrompt = category
        }
    }

    private func syncHealthData() {
        guard !isSyncingHealth else { return }
        isSyncingHealth = true
        healthSyncError = nil

        healthKitManager.requestAuthorization { success, error in
            Task { @MainActor in
                guard success else {
                    self.healthSyncError = error?.localizedDescription ?? "Health access denied."
                    self.isSyncingHealth = false
                    return
                }

                let manager = DataManager(context: context, audit: AuditManager(context: context))
                self.healthKitManager.importTodayData(into: manager) { result in
                    Task { @MainActor in
                        self.isSyncingHealth = false
                        switch result {
                        case .success(let count):
                            self.lastHealthSync = Date()
                            self.showFlash("Imported \(count) Health entries")
                        case .failure(let error):
                            self.healthSyncError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    private func isConsentEnabled(_ category: ConsentCategory) -> Bool {
        consents.first(where: { $0.category == category })?.status ?? true
    }

    private func enableConsent(_ category: ConsentCategory) {
        withPrivacyManager { $0.set(category, enabled: true) }
        showFlash("\(category.permissionTitle) enabled")
    }

    private func withPrivacyManager(_ action: @MainActor (PrivacyManager) -> Void) {
        let audit = AuditManager(context: context)
        let manager = PrivacyManager(context: context, audit: audit)
        action(manager)
    }

    private func withManager(_ action: @MainActor (DataManager) -> Void) {
        let audit = AuditManager(context: context)
        let manager = DataManager(context: context, audit: audit)
        action(manager)
    }

    private func deleteRecord(_ record: Record) {
        withManager { $0.delete(record) }
        recordPendingDeletion = nil
    }

    private func updateRecord(_ record: Record, with payload: RecordEditPayload) {
        withManager {
            $0.update(record,
                      value: payload.value,
                      note: payload.note,
                      calories: payload.calories,
                      carbs: payload.carbs,
                      protein: payload.protein,
                      fat: payload.fat,
                      fiber: payload.fiber)
        }
    }

    private func showFlash(_ message: String) {
        withAnimation {
            flashMessage = message
        }
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            withAnimation {
                flashMessage = nil
            }
        }
    }

    private func ensureConsentsSeededIfNeeded() {
        if consents.isEmpty {
            withPrivacyManager { _ in }
        }
    }

    private func ensureGoalsSeededIfNeeded() {
        if goalsQuery.isEmpty {
            let goals = NutritionGoals()
            context.insert(goals)
            do {
                try context.save()
            } catch {
                print("DailyDashboardView.ensureGoalsSeededIfNeeded error: \(error)")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No records yet")
                .font(.headline)
            Text("Use the quick actions above to start logging today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func recordRow(for record: Record, isFirst: Bool, isLast: Bool) -> some View {
        let tintColor = tint(for: record.type)

        HStack(alignment: .top, spacing: 16) {
            TimelineIndicator(color: tintColor, isFirst: isFirst, isLast: isLast)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title(for: record))
                        .font(.headline)
                    if let valueBadge = valueBadge(for: record) {
                        Text(valueBadge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tintColor)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(tintColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(record.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let detail = detail(for: record) {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
    }

    private func iconName(for type: RecordType) -> String {
        switch type {
        case .meal:
            return "fork.knife"
        case .hydration:
            return "drop.fill"
        case .symptom:
            return "waveform.path.ecg"
        case .medication:
            return "pills.fill"
        case .weight:
            return "scalemass"
        case .activity:
            return "figure.walk"
        }
    }

    private func tint(for type: RecordType) -> Color {
        switch type {
        case .meal:
            return Color(.systemOrange)
        case .hydration:
            return .accentColor
        case .symptom:
            return .pink
        case .medication:
            return .green
        case .weight:
            return .blue
        case .activity:
            return .purple
        }
    }

    private func title(for record: Record) -> String {
        switch record.type {
        case .meal:
            return record.note ?? "Meal"
        case .medication:
            return record.note ?? "Medication"
        case .symptom:
            if let note = record.note, !note.isEmpty {
                return note.capitalized
            }
            return "Symptom"
        case .activity:
            if let note = record.note, note.lowercased().hasPrefix("steps:") {
                return "Steps"
            }
            return record.note ?? "Activity"
        case .hydration, .weight:
            return record.type.rawValue.capitalized
        }
    }

    private func detail(for record: Record) -> String? {
        switch record.type {
        case .hydration:
            if let note = record.note, !note.isEmpty {
                return note
            }
            return nil
        case .meal:
            var parts: [String] = []
            if let note = record.note, !note.isEmpty {
                parts.append(note)
            }
            var macros: [String] = []
            if let carbs = record.carbs { macros.append("\(Int(carbs))g carbs") }
            if let protein = record.protein { macros.append("\(Int(protein))g protein") }
            if let fat = record.fat { macros.append("\(Int(fat))g fat") }
            if let fiber = record.fiber { macros.append("\(Int(fiber))g fiber") }
            if !macros.isEmpty {
                parts.append(macros.joined(separator: " • "))
            }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        case .medication:
            return record.note
        case .symptom:
            var parts: [String] = []
            if let note = record.note, !note.isEmpty { parts.append(note) }
            if let value = record.value, !value.isEmpty { parts.append(value) }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        case .weight:
            if let note = record.note, !note.isEmpty {
                return note
            }
            return nil
        case .activity:
            var parts: [String] = []
            if let value = record.value, let minutes = Int(value), minutes > 0 {
                parts.append("\(minutes) min")
            }
            if let note = record.note, note.lowercased().hasPrefix("steps:") {
                let components = note.split(separator: ":")
                if let stepsPart = components.last, let steps = Int(stepsPart) {
                    parts.append("\(steps) steps")
                }
            } else if let note = record.note, !note.isEmpty {
                parts.append(note)
            }
            if let calories = record.calories {
                parts.append("\(Int(calories)) kcal")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        }
    }

    private func valueBadge(for record: Record) -> String? {
        switch record.type {
        case .hydration:
            if let value = record.value, let amount = Int(value) {
                return "\(amount) mL"
            }
        case .meal:
            if let calories = record.calories {
                return "\(Int(calories)) kcal"
            }
        case .medication:
            return record.value
        case .symptom:
            if let value = record.value, !value.isEmpty {
                return value
            }
        case .weight:
            if let value = record.value, let weight = Double(value) {
                return String(format: "%.1f kg", weight)
            }
            return record.value
        case .activity:
            if let value = record.value, let minutes = Int(value), minutes > 0 {
                return "\(minutes) min"
            }
        }
        return nil
    }

    private func calories(from record: Record) -> Int {
        if let calories = record.calories {
            return Int(calories)
        }
        guard let note = record.note else { return 0 }
        let components = note.split(separator: "•")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasSuffix("kcal") {
                let numberPortion = trimmed.lowercased().replacingOccurrences(of: "kcal", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = Int(numberPortion) {
                    return value
                }
            }
        }
        return 0
    }

    private struct QuickAction: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let tint: Color
        let action: () -> Void
    }

private struct SummaryItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
}

private struct SummaryCard: View {
    let item: SummaryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
                Image(systemName: item.icon)
                    .font(.headline)
                    .padding(8)
                    .foregroundStyle(item.tint)
                    .background(item.tint.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(item.value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    private var disabledConsentBanner: DisabledConsentBanner? {
        let disabled = ConsentCategory.allCases.filter { !isConsentEnabled($0) }
        guard !disabled.isEmpty else { return nil }
        if disabled.count == 1, let category = disabled.first {
            return DisabledConsentBanner(
                headline: "\(category.permissionTitle) is off",
                detail: "Enable it to keep new entries."
            )
        }
        return DisabledConsentBanner(
            headline: "\(disabled.count) logging categories are off",
            detail: "Turn them back on in Privacy to keep saving entries."
        )
    }

    private func consentInfoBanner(_ banner: DisabledConsentBanner) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "shield.slash.fill")
                .font(.headline)
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.headline)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(banner.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct InsightCard: View {
    let insight: DailyInsight

    private var accent: Color {
        switch insight.level {
        case .positive: return .green
        case .neutral: return .blue
        case .warning: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text(insight.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var icon: String {
        switch insight.level {
        case .positive: return "checkmark.seal.fill"
        case .neutral: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

private struct DisabledConsentBanner: Equatable {
    let headline: String
    let detail: String
}

private struct FlashBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

private struct TimelineIndicator: View {
    let color: Color
    let isFirst: Bool
    let isLast: Bool

    private var lineColor: Color {
        Color(.tertiaryLabel)
    }

    var body: some View {
        GeometryReader { proxy in
            let lineHeight = max((proxy.size.height - 12) / 2, 0)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(lineColor.opacity(0.6))
                    .frame(width: 2, height: lineHeight)
                    .opacity(isFirst ? 0 : 1)
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                Rectangle()
                    .fill(lineColor.opacity(0.6))
                    .frame(width: 2, height: lineHeight)
                    .opacity(isLast ? 0 : 1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .frame(width: 18)
        .padding(.top, isFirst ? 6 : 0)
        .padding(.bottom, isLast ? 6 : 0)
    }
}

#Preview {
    DailyDashboardView()
}

private struct RecordEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: Record
    let onSave: (RecordEditPayload) -> Void

    @State private var valueText: String
    @State private var noteText: String
    @State private var caloriesText: String
    @State private var carbsText: String
    @State private var proteinText: String
    @State private var fatText: String
    @State private var fiberText: String

    init(record: Record, onSave: @escaping (RecordEditPayload) -> Void) {
        self.record = record
        self.onSave = onSave
        _valueText = State(initialValue: record.value ?? "")
        _noteText = State(initialValue: record.note ?? "")
        _caloriesText = State(initialValue: MealEntryState.formatNumber(record.calories))
        _carbsText = State(initialValue: MealEntryState.formatNumber(record.carbs))
        _proteinText = State(initialValue: MealEntryState.formatNumber(record.protein))
        _fatText = State(initialValue: MealEntryState.formatNumber(record.fat))
        _fiberText = State(initialValue: MealEntryState.formatNumber(record.fiber))
    }

    var body: some View {
        NavigationStack {
            Form {
                if showsValueField {
                    TextField(valueFieldLabel, text: $valueText)
                        .keyboardType(valueKeyboardType)
                }

                TextField(noteFieldLabel, text: $noteText, axis: .vertical)
                    .lineLimit(3...6)

                if record.type == .meal {
                    Section(header: Text("Nutrition")) {
                        NutrientField(title: "Calories", suffix: "kcal", text: $caloriesText)
                        NutrientField(title: "Carbs", suffix: "g", text: $carbsText)
                        NutrientField(title: "Protein", suffix: "g", text: $proteinText)
                        NutrientField(title: "Fat", suffix: "g", text: $fatText)
                        NutrientField(title: "Fiber", suffix: "g", text: $fiberText)
                    }
                }
            }
            .navigationTitle("Edit \(record.typeDisplayName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let payload = RecordEditPayload(
                            value: trimmed(valueText),
                            note: trimmed(noteText),
                            calories: MealEntryState.parseNumber(caloriesText),
                            carbs: MealEntryState.parseNumber(carbsText),
                            protein: MealEntryState.parseNumber(proteinText),
                            fat: MealEntryState.parseNumber(fatText),
                            fiber: MealEntryState.parseNumber(fiberText)
                        )
                        onSave(payload)
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func trimmed(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var showsValueField: Bool {
        switch record.type {
        case .meal:
            return false
        default:
            return true
        }
    }

    private var valueFieldLabel: String {
        switch record.type {
        case .hydration:
            return "Amount (mL)"
        case .medication:
            return "Dose"
        case .meal:
            return ""
        case .symptom:
            return "Reading"
        case .weight:
            return "Weight"
        case .activity:
            return "Duration / Value"
        }
    }

    private var noteFieldLabel: String {
        switch record.type {
        case .meal:
            return "Description"
        case .medication:
            return "Medication name"
        case .hydration:
            return "Note"
        case .symptom:
            return "Note"
        case .weight:
            return "Note"
        case .activity:
            return "Description"
        }
    }

    private var valueKeyboardType: UIKeyboardType {
        switch record.type {
        case .hydration, .symptom, .weight, .activity:
            return .decimalPad
        case .medication, .meal:
            return .default
        }
    }

    private var hasChanges: Bool {
        let currentValue = record.value ?? ""
        let currentNote = record.note ?? ""
        let currentCalories = MealEntryState.formatNumber(record.calories)
        let currentCarbs = MealEntryState.formatNumber(record.carbs)
        let currentProtein = MealEntryState.formatNumber(record.protein)
        let currentFat = MealEntryState.formatNumber(record.fat)
        let currentFiber = MealEntryState.formatNumber(record.fiber)

        return currentValue != valueText ||
            currentNote != noteText ||
            currentCalories != caloriesText ||
            currentCarbs != carbsText ||
            currentProtein != proteinText ||
            currentFat != fatText ||
            currentFiber != fiberText
    }

}

private struct NutrientField: View {
    let title: String
    let suffix: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MealEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Binding var state: MealEntryState
    let onSave: (MealEntryState) -> Void
    let onCancel: () -> Void

    @State private var showScanner = false
    @State private var scannedCode: String?
    @State private var isFetching = false
    @State private var lookupError: String?
    private let lookupService = FoodLookupService()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Meal")) {
                    TextField("Description", text: $state.description)
                }

                Section(header: Text("Nutrition")) {
                    if #available(iOS 16.2, *) {
                        Button {
                            startScan()
                        } label: {
                            Label("Scan barcode", systemImage: "barcode.viewfinder")
                        }
                    }
                    NutrientField(title: "Calories", suffix: "kcal", text: $state.caloriesText)
                    NutrientField(title: "Carbs", suffix: "g", text: $state.carbsText)
                    NutrientField(title: "Protein", suffix: "g", text: $state.proteinText)
                    NutrientField(title: "Fat", suffix: "g", text: $state.fatText)
                    NutrientField(title: "Fiber", suffix: "g", text: $state.fiberText)
                    if isFetching {
                        HStack {
                            ProgressView()
                            Text("Fetching nutrition info…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let lookupError {
                        Text(lookupError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !state.alerts.isEmpty {
                    Section(header: Text("Food Standards Alerts")) {
                        ForEach(state.alerts) { alert in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.title)
                                    .font(.subheadline.weight(.semibold))
                                if let issued = alert.issued {
                                    Text("Issued \(issued.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !alert.allergens.isEmpty {
                                    Text("Allergens: \(alert.allergens.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let link = alert.url {
                                    Link("View alert", destination: link)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Log Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(state)
                    }
                    .disabled(!state.canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showScanner) {
            if #available(iOS 16.2, *) {
                BarcodeScannerView { code in
                    scannedCode = code
                    showScanner = false
                }
            } else {
                Text("Barcode scanning requires iOS 16.2 or later.")
                    .padding()
            }
        }
        .onChange(of: scannedCode) { _, newValue in
            guard let code = newValue else { return }
            performLookup(for: code)
        }
    }

    private func startScan() {
        guard #available(iOS 16.2, *), DataScannerViewController.isSupported else {
            lookupError = "Barcode scanning is not supported on this device."
            return
        }
        lookupError = nil
        scannedCode = nil
        showScanner = true
    }

    private func performLookup(for code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isFetching = true
        lookupError = nil

        Task { @MainActor in
            if let cached = cachedItem(for: trimmed) {
                state.apply(cached)
                lookupError = nil
                isFetching = false
                return
            }

            do {
                let item = try await lookupService.lookupProduct(byBarcode: trimmed)
                state.apply(item)
                lookupError = nil
                isFetching = false
                cache(item, barcode: trimmed)
            } catch let error as FoodLookupError {
                lookupError = error.localizedDescription
                isFetching = false
            } catch {
                lookupError = FoodLookupError.serviceUnavailable.localizedDescription
                isFetching = false
            }
        }
    }

    private func cachedItem(for barcode: String) -> FoodItem? {
        let descriptor = FetchDescriptor<FoodProductCache>(predicate: #Predicate { $0.barcode == barcode })
        if let cache = try? context.fetch(descriptor).first {
            let alerts = cache.alertSummary
                .flatMap { summary -> [FoodAlert] in
                    summary.split(separator: "\n").map { line in
                        FoodAlert(title: String(line), issued: nil, allergens: [], url: nil)
                    }
                } ?? []
            return FoodItem(name: cache.name,
                            calories: cache.calories,
                            carbs: cache.carbs,
                            protein: cache.protein,
                            fat: cache.fat,
                            fiber: cache.fiber,
                            alerts: alerts)
        }
        return nil
    }

    private func cache(_ item: FoodItem, barcode: String) {
        let alertSummary = item.alerts.map { $0.title }.joined(separator: "\n")
        let descriptor = FetchDescriptor<FoodProductCache>(predicate: #Predicate { $0.barcode == barcode })
        if let existing = try? context.fetch(descriptor).first {
            existing.name = item.name
            existing.calories = item.calories
            existing.carbs = item.carbs
            existing.protein = item.protein
            existing.fat = item.fat
            existing.fiber = item.fiber
            existing.alertSummary = alertSummary.isEmpty ? nil : alertSummary
            existing.updatedAt = Date()
        } else {
            let cache = FoodProductCache(barcode: barcode,
                                         name: item.name,
                                         calories: item.calories,
                                         carbs: item.carbs,
                                         protein: item.protein,
                                         fat: item.fat,
                                         fiber: item.fiber,
                                         alertSummary: alertSummary.isEmpty ? nil : alertSummary)
            context.insert(cache)
        }
        do {
            try context.save()
        } catch {
            print("MealEntrySheet.cache error: \(error)")
        }
    }
}

private struct MealEntryState: Equatable {
    var description: String = ""
    var caloriesText: String = ""
    var carbsText: String = ""
    var proteinText: String = ""
    var fatText: String = ""
    var fiberText: String = ""
    var alerts: [FoodAlert] = []

    var calories: Double? { MealEntryState.parseNumber(caloriesText) }
    var carbs: Double? { MealEntryState.parseNumber(carbsText) }
    var protein: Double? { MealEntryState.parseNumber(proteinText) }
    var fat: Double? { MealEntryState.parseNumber(fatText) }
    var fiber: Double? { MealEntryState.parseNumber(fiberText) }

    var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func apply(_ item: FoodItem) {
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            description = item.name
        }
        caloriesText = MealEntryState.formatNumber(item.calories)
        carbsText = MealEntryState.formatNumber(item.carbs)
        proteinText = MealEntryState.formatNumber(item.protein)
        fatText = MealEntryState.formatNumber(item.fat)
        fiberText = MealEntryState.formatNumber(item.fiber)
        alerts = item.alerts
    }

    static func parseNumber(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    static func formatNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

struct RecordEditPayload {
    var value: String?
    var note: String?
    var calories: Double?
    var carbs: Double?
    var protein: Double?
    var fat: Double?
    var fiber: Double?
}

private extension Record {
    var typeDisplayName: String {
        switch type {
        case .meal:
            return "Meal"
        case .hydration:
            return "Hydration"
        case .symptom:
            return "Symptom"
        case .medication:
            return "Medication"
        case .weight:
            return "Weight"
        case .activity:
            return "Activity"
        }
    }
}
