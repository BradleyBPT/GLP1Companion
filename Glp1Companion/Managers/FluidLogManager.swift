import Foundation
import SwiftData

@MainActor
final class FluidLogManager: ObservableObject {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func log(amountML: Double, type: FluidType, notes: String? = nil) {
        let log = FluidIntakeLog(amountML: amountML, type: type, notes: notes)
        context.insert(log)
        do {
            try context.save()
        } catch {
            print("FluidLogManager.log error: \(error)")
        }
    }

    func entries(for date: Date) -> [FluidIntakeLog] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = #Predicate<FluidIntakeLog> { $0.date >= start && $0.date < end }
        let descriptor = FetchDescriptor<FluidIntakeLog>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
