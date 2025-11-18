import Foundation
import CoreData
import Combine

@MainActor final class WeightListViewModel: ObservableObject {
    @Published var records: [BodyRecordModel] = []
    func load(context: NSManagedObjectContext, days: Int = 90) {
        let repo = BodyRepository(context: context)
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        let endPlus = cal.date(byAdding: .day, value: 1, to: end)!
        if let list = try? repo.fetch(range: start...endPlus) { records = list.sorted { $0.date > $1.date } }
    }
    func add(context: NSManagedObjectContext) {
        let repo = BodyRepository(context: context)
        let rec = BodyRecordModel(date: Date(), weight: 70.0, waist: nil)
        do { try repo.save(rec); load(context: context) } catch {}
    }
    func update(context: NSManagedObjectContext, record: BodyRecordModel) {
        let repo = BodyRepository(context: context)
        do { try repo.update(record); load(context: context) } catch {}
    }
    func delete(context: NSManagedObjectContext, id: UUID) {
        let repo = BodyRepository(context: context)
        do { try repo.delete(id: id); load(context: context) } catch {}
    }
    func clearAll(context: NSManagedObjectContext) {
        let repo = BodyRepository(context: context)
        do { try repo.deleteAll(); load(context: context) } catch {}
    }
}