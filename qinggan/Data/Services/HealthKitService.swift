import Foundation
import HealthKit

final class HealthKitService {
    let store = HKHealthStore()
    private func isConfiguredForHealthKit() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        return Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil
    }
    func requestAuthorization() async throws {
        guard isConfiguredForHealthKit() else { return }
        let type = HKObjectType.quantityType(forIdentifier: .stepCount)!
        try await store.requestAuthorization(toShare: [], read: [type])
    }
    func steps(for date: Date) async throws -> Int {
        guard isConfiguredForHealthKit() else { return 0 }
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(value))
            }
            store.execute(q)
        }
    }
    func steps(last days: Int) async throws -> [StepStatModel] {
        guard isConfiguredForHealthKit() else { return [] }
        let cal = Calendar.current
        var stats: [StepStatModel] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            let d = cal.date(byAdding: .day, value: -i, to: Date())!
            let s = try await steps(for: d)
            stats.append(StepStatModel(id: UUID(), date: cal.startOfDay(for: d), steps: s))
        }
        return stats
    }
}