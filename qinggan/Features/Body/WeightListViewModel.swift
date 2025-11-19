import Foundation
import CoreData
import Combine

@MainActor final class WeightListViewModel: ObservableObject {
    @Published var records: [BodyRecordModel] = []
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = true
    private var lastDate: Date?
    private let pageSize: Int = 20
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
        do { try repo.save(rec); refresh(context: context) } catch {}
    }
    func update(context: NSManagedObjectContext, record: BodyRecordModel) {
        let repo = BodyRepository(context: context)
        do { try repo.update(record); refresh(context: context) } catch {}
    }
    func delete(context: NSManagedObjectContext, id: UUID) {
        let repo = BodyRepository(context: context)
        do { try repo.delete(id: id); refresh(context: context) } catch {}
    }
    func clearAll(context: NSManagedObjectContext) {
        let repo = BodyRepository(context: context)
        do { try repo.deleteAll(); refresh(context: context) } catch {}
    }
    func loadInitialPaged(context: NSManagedObjectContext) {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let repo = BodyRepository(context: context)
        if let list = try? repo.fetchRecent(limit: pageSize, before: nil) {
            records = list
            lastDate = records.last?.date
            hasMore = (list.count == pageSize)
        }
    }
    func loadMore(context: NSManagedObjectContext) {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        let repo = BodyRepository(context: context)
        if let list = try? repo.fetchRecent(limit: pageSize, before: lastDate) {
            records.append(contentsOf: list)
            lastDate = records.last?.date
            hasMore = (list.count == pageSize)
        }
    }
    func refresh(context: NSManagedObjectContext) {
        // Reset pagination and reload first page
        lastDate = nil
        hasMore = true
        records.removeAll()
        loadInitialPaged(context: context)
    }
}