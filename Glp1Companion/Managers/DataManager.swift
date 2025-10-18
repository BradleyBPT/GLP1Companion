import Foundation
import SwiftData

@MainActor
final class DataManager: ObservableObject {
    @Published private(set) var records: [Record] = []
    private let context: ModelContext
    private let audit: AuditManager

    init(context: ModelContext, audit: AuditManager) {
        self.context = context
        self.audit = audit
        fetchAll()
    }

    func fetchAll() {
        let req = FetchDescriptor<Record>()
        do {
            records = try context.fetch(req)
        } catch {
            print("DataManager.fetchAll error: \(error)")
            records = []
        }
    }

    func add(_ record: Record) {
        context.insert(record)
        do {
            try context.save()
            audit.log(action: .create, target: "Record", details: record.type.rawValue)
            fetchAll()
        } catch {
            print("DataManager.add error: \(error)")
        }
    }

    // Quick-add helpers for common record types. Each creates the Record and an AuditLog
    // then saves the context in one operation.
    func addHydration(amountML: Int) {
        let record = Record(type: .hydration, date: Date(), value: "\(amountML)", note: "Quick add: \(amountML) mL")
        let auditEntry = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: "hydration:\(amountML)")
        context.insert(record)
        context.insert(auditEntry)
        do {
            try context.save()
            fetchAll()
        } catch {
            print("DataManager.addHydration error: \(error)")
        }
    }

    func addMedication(name: String, dose: String) {
        let record = Record(type: .medication, date: Date(), value: dose, note: name)
        let auditEntry = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: "medication:\(name):\(dose)")
        context.insert(record)
        context.insert(auditEntry)
        do {
            try context.save()
            fetchAll()
        } catch {
            print("DataManager.addMedication error: \(error)")
        }
    }

    func addGlucose(mgPerDL: Double) {
        // Map glucose into a generic 'symptom' record type for now.
        let record = Record(type: .symptom, date: Date(), value: String(format: "%.1f", mgPerDL), note: "glucose")
        let auditEntry = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: "glucose:\(mgPerDL)")
        context.insert(record)
        context.insert(auditEntry)
        do {
            try context.save()
            fetchAll()
        } catch {
            print("DataManager.addGlucose error: \(error)")
        }
    }

    func addWeight(kg: Double, note: String? = nil) {
        let record = Record(type: .weight, date: Date(), value: String(format: "%.2f", kg), note: note)
        let auditEntry = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: "weight:\(kg)")
        context.insert(record)
        context.insert(auditEntry)
        do {
            try context.save()
            fetchAll()
        } catch {
            print("DataManager.addWeight error: \(error)")
        }
    }

    func addExercise(minutes: Int, description: String? = nil, calories: Double? = nil) {
        // Use 'activity' for exercise records.
        var noteParts: [String] = []
        if let description, !description.isEmpty {
            noteParts.append(description)
        }
        if let calories, calories > 0 {
            noteParts.append("\(Int(calories)) kcal")
        }
        let note = noteParts.isEmpty ? nil : noteParts.joined(separator: " • ")

        let record = Record(type: .activity, date: Date(), value: "\(minutes)", note: note, calories: calories)
        let auditEntry = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: "exercise:\(minutes)")
        context.insert(record)
        context.insert(auditEntry)
        do {
            try context.save()
            fetchAll()
        } catch {
            print("DataManager.addExercise error: \(error)")
        }
    }

    func addMeal(description: String, calories: Double?, carbs: Double?, protein: Double?, fat: Double?, fiber: Double?) {
        let record = Record(type: .meal,
                            date: Date(),
                            value: nil,
                            note: description,
                            calories: calories,
                            carbs: carbs,
                            protein: protein,
                            fat: fat,
                            fiber: fiber)
        let auditDetails = "meal:\(description):\(Int(calories ?? 0))kcal"
        let auditEntry = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: auditDetails)
        context.insert(record)
        context.insert(auditEntry)
        do {
            try context.save()
            fetchAll()
        } catch {
            print("DataManager.addMeal error: \(error)")
        }
    }

    func addMood(level: Int, note: String? = nil) {
        let record = Record(type: .mood, date: Date(), value: "\(level)", note: note)
        let auditEntry = AuditLog(actionType: .create, timestamp: Date(), targetEntity: "Record", details: "mood:\(level)")
        context.insert(record)
        context.insert(auditEntry)
        do {
            try context.save()
            fetchAll()
        } catch {
            print("DataManager.addMood error: \(error)")
        }
    }

    func update(_ record: Record,
                value: String?,
                note: String?,
                calories: Double? = nil,
                carbs: Double? = nil,
                protein: Double? = nil,
                fat: Double? = nil,
                fiber: Double? = nil) {
        record.value = value?.isEmpty == true ? nil : value
        record.note = note?.isEmpty == true ? nil : note
        record.calories = calories
        record.carbs = carbs
        record.protein = protein
        record.fat = fat
        record.fiber = fiber
        do {
            try context.save()
            audit.log(action: .update, target: "Record", details: record.id.uuidString)
            fetchAll()
        } catch {
            print("DataManager.update error: \(error)")
        }
    }

    func delete(_ record: Record) {
        context.delete(record)
        do {
            try context.save()
            audit.log(action: .delete, target: "Record", details: record.id.uuidString)
            fetchAll()
        } catch {
            print("DataManager.delete error: \(error)")
        }
    }
}
