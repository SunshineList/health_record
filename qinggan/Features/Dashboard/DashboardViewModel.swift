import Foundation
import CoreData
import Combine

@MainActor final class DashboardViewModel: ObservableObject {
    @Published var range: Int = 7
    @Published var weightTrend: [(Date, Double)] = []
    @Published var stepTrend: [StepStatModel] = []
    @Published var kcalBars: [(Date, Double)] = []
    private let healthKit = HealthKitService()
    @Published var summaryText: String = ""
    func load(range: Int, context: NSManagedObjectContext) async {
        do {
            try await healthKit.requestAuthorization()
            stepTrend = try await healthKit.steps(last: range)
        } catch {}
        let repo = DietRepository(context: context)
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(range - 1), to: end) ?? end
        let r: ClosedRange<Date> = start...cal.date(byAdding: .day, value: 1, to: end)!
        if let records = try? repo.fetch(range: r) {
            var dict: [Date: Double] = [:]
            for rec in records {
                let day = cal.startOfDay(for: rec.timestamp)
                let sum = rec.items.reduce(0) { $0 + $1.kcal }
                dict[day, default: 0] += sum
            }
            let sorted = dict.keys.sorted()
            kcalBars = sorted.map { ($0, dict[$0] ?? 0) }
        }
        let bRepo = BodyRepository(context: context)
        weightTrend = []
        if let bodies = try? bRepo.fetchAll() {
            let cal = Calendar.current
            var daily: [Date: Double] = [:]
            for rec in bodies {
                if let w = rec.weight {
                    let d = cal.startOfDay(for: rec.date)
                    daily[d] = w
                }
            }
            let days = daily.keys.sorted()
            weightTrend = days.map { ($0, daily[$0] ?? 0) }
            if let firstW = weightTrend.first?.1, let lastW = weightTrend.last?.1, !weightTrend.isEmpty {
                let dw = lastW - firstW
                let avgSteps = Int(stepTrend.map{ $0.steps }.reduce(0, +) / max(1, stepTrend.count))
                summaryText = "过去 \(range) 天，体重变化 \(String(format: "%.1f", dw)) kg，平均步数 \(avgSteps)。"
            }
        }
    }
}