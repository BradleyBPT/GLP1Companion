import Foundation
import HealthKit

final class HealthKitManager {
    private let healthStore = HKHealthStore()

    // Types we will read (one-way)
    private var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { set.insert(water) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(steps) }
        if let energy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { set.insert(energy) }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) { set.insert(heartRate) }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(activeEnergy) }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { set.insert(bodyMass) }
        if let glucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose) { set.insert(glucose) }
        set.insert(HKObjectType.workoutType())
        return set
    }

    // Request HealthKit authorization (read-only)
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    // Import today's samples and map them into your DataManager.
    // This pulls samples from midnight -> now for each supported type and
    // calls appropriate DataManager convenience methods to persist.
    @MainActor
    func importTodayData(into dataManager: DataManager, completion: @escaping (Result<Int, Error>) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        var importedCount = 0
        var firstError: Error?
        let dispatchGroup = DispatchGroup()

        func fetchQuantitySamples(identifier: HKQuantityTypeIdentifier, handler: @MainActor @escaping ([HKQuantitySample]) -> Void) {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
            dispatchGroup.enter()
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samplesOrNil, error in
                Task { @MainActor in
                    if let error = error {
                        firstError = firstError ?? error
                    } else if let samples = samplesOrNil as? [HKQuantitySample], !samples.isEmpty {
                        handler(samples)
                    }
                    dispatchGroup.leave()
                }
            }
            healthStore.execute(query)
        }

        let millilitreUnit = HKUnit.literUnit(with: .milli)
        fetchQuantitySamples(identifier: .dietaryWater) { samples in
            for sample in samples {
                let ml = Int(sample.quantity.doubleValue(for: millilitreUnit))
                dataManager.addHydration(amountML: ml)
                importedCount += 1
            }
        }

        let countUnit = HKUnit.count()
        fetchQuantitySamples(identifier: .stepCount) { samples in
            for sample in samples {
                let steps = Int(sample.quantity.doubleValue(for: countUnit))
                dataManager.addExercise(minutes: 0, description: "steps:\(steps)")
                importedCount += 1
            }
        }

        let kilocalorieUnit = HKUnit.kilocalorie()
        fetchQuantitySamples(identifier: .dietaryEnergyConsumed) { samples in
            for sample in samples {
                let kcal = sample.quantity.doubleValue(for: kilocalorieUnit)
                dataManager.addMeal(description: "Imported calories", calories: kcal, carbs: nil, protein: nil, fat: nil, fiber: nil)
                importedCount += 1
            }
        }

        let kilogramUnit = HKUnit.gramUnit(with: .kilo)
        fetchQuantitySamples(identifier: .bodyMass) { samples in
            for sample in samples {
                let kg = sample.quantity.doubleValue(for: kilogramUnit)
                dataManager.addWeight(kg: kg)
                importedCount += 1
            }
        }

        let glucoseUnit = HKUnit(from: "mg/dL")
        fetchQuantitySamples(identifier: .bloodGlucose) { samples in
            for sample in samples {
                let value = sample.quantity.doubleValue(for: glucoseUnit)
                dataManager.addGlucose(mgPerDL: value)
                importedCount += 1
            }
        }

        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        fetchQuantitySamples(identifier: .heartRate) { samples in
            for sample in samples {
                let bpm = sample.quantity.doubleValue(for: heartRateUnit)
                dataManager.addMood(level: Int(bpm), note: "HR \(Int(bpm)) bpm") // reuse mood/symptom mapping
                importedCount += 1
            }
        }

        dispatchGroup.enter()
        let workoutType = HKObjectType.workoutType()
        let store = healthStore
        let workoutQuery = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samplesOrNil, error in
            Task { @MainActor in
                defer { dispatchGroup.leave() }

                if let error = error {
                    firstError = firstError ?? error
                    return
                }

                guard let workouts = samplesOrNil as? [HKWorkout], !workouts.isEmpty else {
                    return
                }

                for workout in workouts {
                    let durationMinutes = max(Int((workout.duration / 60).rounded()), workout.duration > 0 ? 1 : 0)
                    let calories = await Self.activeCalories(for: workout, store: store)
                    let summary = Self.workoutSummary(for: workout)
                    dataManager.addExercise(minutes: durationMinutes, description: summary, calories: calories)
                    importedCount += 1
                }
            }
        }
        healthStore.execute(workoutQuery)

        dispatchGroup.notify(queue: .main) {
            Task { @MainActor in
                if let error = firstError {
                    completion(.failure(error))
                } else {
                    completion(.success(importedCount))
                }
            }
        }
    }
}

private extension HealthKitManager {
    static func activeCalories(for workout: HKWorkout, store: HKHealthStore) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return legacyTotalEnergy(for: workout)
        }

        let workoutPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [.strictStartDate, .strictEndDate])

        return await withCheckedContinuation { continuation in
            let statisticsQuery = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: workoutPredicate, options: .cumulativeSum) { _, statistics, _ in
                if let quantity = statistics?.sumQuantity() {
                    continuation.resume(returning: quantity.doubleValue(for: HKUnit.kilocalorie()))
                } else if let energy = legacyTotalEnergy(for: workout) {
                    continuation.resume(returning: energy)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(statisticsQuery)
        }
    }

    static func workoutSummary(for workout: HKWorkout) -> String {
        var parts: [String] = []
        let activityName = workout.workoutActivityType.displayName
        parts.append(activityName)

        if let distanceQuantity = workout.totalDistance {
            let kilometers = distanceQuantity.doubleValue(for: HKUnit.meterUnit(with: .kilo))
            if kilometers > 0 {
                parts.append(String(format: "%.2f km", kilometers))
            }
        }

        if let metadata = workout.metadata, let location = metadata[HKMetadataKeyWorkoutBrandName] as? String, !location.isEmpty {
            parts.append(location)
        }

        return parts.joined(separator: " • ")
    }

    static func legacyTotalEnergy(for workout: HKWorkout) -> Double? {
        if #available(iOS 18.0, *) {
            return nil
        } else {
            return workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
        }
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining: return "Strength"
        case .hiking: return "Hike"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        case .functionalStrengthTraining: return "Functional"
        case .highIntensityIntervalTraining: return "HIIT"
        default:
            let description = String(describing: self)
            if let nameComponent = description.split(separator: ".").last {
                return nameComponent.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return description.capitalized
        }
    }
}
