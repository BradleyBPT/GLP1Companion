import Foundation

struct DailySummary {
    let date: Date
    let caloriesIn: Double
    let caloriesGoal: Double
    let caloriesOut: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let fiber: Double
    let fiberGoal: Double
    let hydrationML: Double
    let hydrationGoalML: Double
    let medicationPhase: MedicationPhase?
    let moodScores: [Int]
    let latestMood: Int?

    var netCalories: Double { caloriesIn - caloriesOut }
    var remainingCalories: Double { caloriesGoal - netCalories }
    var averageMood: Double? {
        guard !moodScores.isEmpty else { return nil }
        return Double(moodScores.reduce(0, +)) / Double(moodScores.count)
    }
}

struct DailyInsight: Identifiable {
    enum Level {
        case positive
        case neutral
        case warning
    }

    let id = UUID()
    let title: String
    let message: String
    let level: Level
}

enum DailySummaryService {
    static func summarize(records: [Record], fluidLogs: [FluidIntakeLog], goals: NutritionGoals?, schedule: MedicationSchedule?) -> DailySummary {
        var caloriesIn: Double = 0
        var carbs: Double = 0
        var protein: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var hydration: Double = 0
        var caloriesOut: Double = 0
        var moodScores: [Int] = []
        var latestMoodScore: Int?
        var latestMoodDate: Date = .distantPast

        for record in records {
            switch record.type {
            case .meal:
                caloriesIn += record.calories ?? 0
                carbs += record.carbs ?? 0
                protein += record.protein ?? 0
                fat += record.fat ?? 0
                fiber += record.fiber ?? 0
            case .activity:
                caloriesOut += record.calories ?? 0
            case .mood:
                if let value = record.value.flatMap(Int.init) {
                    moodScores.append(value)
                    if record.date > latestMoodDate {
                        latestMoodDate = record.date
                        latestMoodScore = value
                    }
                }
            default:
                continue
            }
        }

        for log in fluidLogs {
            hydration += log.amountML
        }

        let phase = schedule?.phase
        let calorieGoal = (goals?.dailyCalories ?? 1800) + (phase?.suggestedCalorieOffset ?? 0)
        let fiberGoalBase = goals?.dailyFiber ?? 30
        let fiberGoal = schedule?.phase.suggestedFibreTarget ?? fiberGoalBase
        let hydrationGoal = goals?.dailyHydrationML ?? 2000.0

        return DailySummary(
            date: Date(),
            caloriesIn: caloriesIn,
            caloriesGoal: calorieGoal,
            caloriesOut: caloriesOut,
            carbs: carbs,
            protein: protein,
            fat: fat,
            fiber: fiber,
            fiberGoal: fiberGoal,
            hydrationML: hydration,
            hydrationGoalML: hydrationGoal,
            medicationPhase: phase,
            moodScores: moodScores,
            latestMood: latestMoodScore
        )
    }

    static func insights(for summary: DailySummary) -> [DailyInsight] {
        var items: [DailyInsight] = []

        let net = summary.netCalories
        if net < summary.caloriesGoal * 0.75 {
            items.append(
                DailyInsight(
                    title: "Energy gap",
                    message: "You’re \(Int(summary.caloriesGoal - net)) kcal below today’s goal. Consider a balanced snack to stay energised during GLP-1 therapy.",
                    level: .neutral
                )
            )
        } else if net > summary.caloriesGoal {
            items.append(
                DailyInsight(
                    title: "Above calorie goal",
                    message: "Net intake is \(Int(net - summary.caloriesGoal)) kcal over target. Track evening snacks or add a light walk.",
                    level: .warning
                )
            )
        } else {
            items.append(
                DailyInsight(
                    title: "Calories on track",
                    message: "Today’s net calories are within your personalised goal. Great consistency for GLP‑1 progress.",
                    level: .positive
                )
            )
        }

        if summary.fiber >= summary.fiberGoal {
            items.append(
                DailyInsight(
                    title: "Fibre target met",
                    message: "You’ve logged \(Int(summary.fiber))g fibre – ideal for satiety and glucose stability.",
                    level: .positive
                )
            )
        } else {
            let remaining = max(summary.fiberGoal - summary.fiber, 0)
            items.append(
                DailyInsight(
                    title: "Boost fibre",
                    message: "Add \(Int(remaining))g more fibre (vegetables, pulses, oats) to support GLP-1 medication.",
                    level: .warning
                )
            )
        }

        if summary.hydrationML < summary.hydrationGoalML * 0.6 {
            items.append(
                DailyInsight(
                    title: "Hydration low",
                    message: "Only \(Int(summary.hydrationML)) mL logged. Sip water regularly to reduce nausea risk.",
                    level: .warning
                )
            )
        } else if summary.hydrationML >= summary.hydrationGoalML {
            items.append(
                DailyInsight(
                    title: "Hydration on point",
                    message: "Great hydration today. Staying hydrated supports appetite control.",
                    level: .positive
                )
            )
        }

        if let phase = summary.medicationPhase {
            switch phase {
            case .titration:
                items.append(
                    DailyInsight(
                        title: "Titration focus",
                        message: "Keep meals gentle and fibre gradual while doses increase.",
                        level: .neutral
                    )
                )
            case .maintenance:
                items.append(
                    DailyInsight(
                        title: "Maintenance",
                        message: "Consistency is key—log weekly to keep momentum.",
                        level: .neutral
                    )
                )
            case .pause:
                items.append(
                    DailyInsight(
                        title: "Pause week",
                        message: "Without medication, watch hunger cues and keep fibre steady.",
                        level: .neutral
                    )
                )
            }
        }

        if let avgMood = summary.averageMood {
            if avgMood >= 4 {
                items.append(
                    DailyInsight(
                        title: "Positive mood",
                        message: "Mood average is \(String(format: "%.1f", avgMood))/5. Keep reinforcing routines that feel good.",
                        level: .positive
                    )
                )
            } else if avgMood < 3 {
                items.append(
                    DailyInsight(
                        title: "Mood dip",
                        message: "Mood scores are trending low. Consider gentle activity, protein-rich meals, or speaking with your care team if this persists.",
                        level: .warning
                    )
                )
            }
        } else {
            items.append(
                DailyInsight(
                    title: "Log mood",
                    message: "Track how you feel with the mood quick action to see patterns alongside nutrition.",
                    level: .neutral
                )
            )
        }

        return items
    }
}
