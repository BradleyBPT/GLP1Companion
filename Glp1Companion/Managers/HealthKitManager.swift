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
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { set.insert(bodyMass) }
        if let glucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose) { set.insert(glucose) }
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
    func importTodayData(into dataManager: DataManager, completion: @escaping (Result<Int, Error>) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        var importedCount = 0
        var firstError: Error?

        // Helper to fetch a quantity type
        func fetchQuantitySamples(identifier: HKQuantityTypeIdentifier, unit: HKUnit, handler: @escaping (HKQuantitySample) -> Void, finished: @escaping () -> Void) {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { finished(); return }
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samplesOrNil, error in
                if let error = error {
                    firstError = firstError ?? error
                } else if let samples = samplesOrNil as? [HKQuantitySample] {
                    for s in samples {
                        handler(s)
                    }
                }
                finished()
            }
            healthStore.execute(query)
        }

        // Track how many fetches are outstanding
        let dispatchGroup = DispatchGroup()

        // dietaryWater -> hydration (mL)
        dispatchGroup.enter()
        fetchQuantitySamples(identifier: .dietaryWater, unit: HKUnit.literUnit(with: .milli)) { sample in
            let ml = Int(sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli)))
            dataManager.addHydration(amountML: ml)
            importedCount += 1
        } finished: {
            dispatchGroup.leave()
        }

        // stepCount -> activity (steps)
        dispatchGroup.enter()
        fetchQuantitySamples(identifier: .stepCount, unit: HKUnit.count()) { sample in
            let steps = Int(sample.quantity.doubleValue(for: HKUnit.count()))
            // Map as activity minutes roughly or as activity record with steps in note
            dataManager.addExercise(minutes: 0, description: "steps:\(steps)")
            importedCount += 1
        } finished: {
            dispatchGroup.leave()
        }

        // dietaryEnergyConsumed -> meal (calories)
        dispatchGroup.enter()
        fetchQuantitySamples(identifier: .dietaryEnergyConsumed, unit: HKUnit.kilocalorie()) { sample in
            let kcal = Int(sample.quantity.doubleValue(for: HKUnit.kilocalorie()))
            dataManager.addMeal(description: "Calories: \(kcal) kcal")
            importedCount += 1
        } finished: {
            dispatchGroup.leave()
        }

        // bodyMass -> weight
        dispatchGroup.enter()
        fetchQuantitySamples(identifier: .bodyMass, unit: HKUnit.gramUnit(with: .kilo)) { sample in
            let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            dataManager.addWeight(kg: kg)
            importedCount += 1
        } finished: {
            dispatchGroup.leave()
        }

        // bloodGlucose -> glucose (mg/dL). HK typically uses mmol/L; convert if needed.
        dispatchGroup.enter()
        fetchQuantitySamples(identifier: .bloodGlucose, unit: HKUnit(from: "mg/dL")) { sample in
            let v = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
            dataManager.addGlucose(mgPerDL: v)
            importedCount += 1
        } finished: {
            dispatchGroup.leave()
        }

        // heartRate -> record as symptom/observation
        dispatchGroup.enter()
        fetchQuantitySamples(identifier: .heartRate, unit: HKUnit.count().unitDivided(by: HKUnit.minute())) { sample in
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            dataManager.addMood(level: Int(bpm), note: "HR \(Int(bpm)) bpm") // reuse mood/symptom mapping
            importedCount += 1
        } finished: {
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            if let e = firstError {
                completion(.failure(e))
            } else {
                completion(.success(importedCount))
            }
        }
    }
}