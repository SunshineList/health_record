import Foundation
import CoreData
import Combine

@MainActor final class HomeViewModel: ObservableObject {
    @Published var todaySteps: Int = 0
    @Published var goal: Int = 8000
    @Published var isGoalMet: Bool = false
    @Published var recent7Steps: [StepStatModel] = []
    @Published var recent30Steps: [StepStatModel] = []
    @Published var todayKcal: Double = 0
    @Published var todayMealsCount: Int = 0
    @Published var todayProtein: Int = 0
    @Published var todayFat: Int = 0
    @Published var todayCarb: Int = 0
    @Published var observationText: String = "今天表现不错！坚持控制热量与活动。"
    @Published var isRefreshingObservation: Bool = false
    @Published var weightTrend: [(Date, Double)] = []
    @Published var currentWeight: Double?
    @Published var bmi: Double?
    @Published var calorieTarget: Int = 1800
    @Published var recentDiet: [DietRecordModel] = []
    @Published var recentDietLoading: Bool = false
    @Published var recentDietHasMore: Bool = false
    private var recentDietLastDate: Date?
    private let dietPageSize: Int = 12
    private let healthKit = HealthKitService()
    private let notifications = NotificationManager()
    private var settingsObserver: AnyCancellable?
    private var dataObserver: AnyCancellable?
    func loadDashboardSummary() async {
        let cfg = ConfigStore.shared.load()
        goal = cfg.dailyStepGoal
        calorieTarget = cfg.dailyCalorieTarget
    }
    func refreshSteps() async {
        do {
            try await healthKit.requestAuthorization()
            let steps = try await healthKit.steps(for: Date())
            todaySteps = steps
            isGoalMet = steps >= goal
            recent7Steps = try await healthKit.steps(last: 7)
            recent30Steps = try await healthKit.steps(last: 30)
        } catch {}
    }
    func refreshTodayKcal(context: NSManagedObjectContext) async {
        let repo = DietRepository(context: context)
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        if let records = try? repo.fetch(range: start...end) {
            todayMealsCount = records.count
            todayKcal = records.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.kcal } }
            var p = 0, f = 0, c = 0
            for r in records { for it in r.items { p += Int(it.protein); f += Int(it.fat); c += Int(it.carb) } }
            todayProtein = p; todayFat = f; todayCarb = c
        }
    }
    func loadWeight(context: NSManagedObjectContext) {
        let bRepo = BodyRepository(context: context)
        let cal = Calendar.current
        if let bodies = try? bRepo.fetchAll() {
            var daily: [Date: Double] = [:]
            for rec in bodies {
                if let w = rec.weight {
                    let d = cal.startOfDay(for: rec.date)
                    daily[d] = w // 取当天最后一次写入的体重
                }
            }
            let days = daily.keys.sorted()
            weightTrend = days.map { ($0, daily[$0] ?? 0) }
            currentWeight = bodies.last?.weight
            let h = ConfigStore.shared.load().heightCm
            if let cw = currentWeight, let hc = h, hc > 0 { let m = hc/100.0; bmi = cw/(m*m) }
        }
    }
    func loadRecentDietInitial(context: NSManagedObjectContext) {
        guard !recentDietLoading else { return }
        recentDietLoading = true
        defer { recentDietLoading = false }
        let repo = DietRepository(context: context)
        if let list = try? repo.fetchRecent(limit: dietPageSize, before: nil) {
            recentDiet = list
            recentDietLastDate = recentDiet.last?.timestamp
            recentDietHasMore = (list.count == dietPageSize)
        }
    }
    func loadRecentDietMore(context: NSManagedObjectContext) {
        guard !recentDietLoading, recentDietHasMore else { return }
        recentDietLoading = true
        defer { recentDietLoading = false }
        let repo = DietRepository(context: context)
        if let list = try? repo.fetchRecent(limit: dietPageSize, before: recentDietLastDate) {
            recentDiet.append(contentsOf: list)
            recentDietLastDate = recentDiet.last?.timestamp
            recentDietHasMore = (list.count == dietPageSize)
        }
    }
    func buildSummary(context: NSManagedObjectContext) async -> HealthSummary {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        let dietRepo = DietRepository(context: context)
        var totalKcal: Double = 0
        var dailyKcal: [Date: Double] = [:]
        if let records = try? dietRepo.fetch(range: start...end) {
            totalKcal = records.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.kcal } }
            for r in records {
                let day = cal.startOfDay(for: r.timestamp)
                let sum = r.items.reduce(0) { $0 + $1.kcal }
                dailyKcal[day, default: 0] += sum
            }
        }
        var avgSteps = 0
        var minSteps: Int?
        var maxSteps: Int?
        var stepArr: [Int] = []
        do {
            try await healthKit.requestAuthorization()
            let steps = try await healthKit.steps(last: 7)
            if !steps.isEmpty {
                stepArr = steps.map { $0.steps }
                avgSteps = stepArr.reduce(0, +) / stepArr.count
                minSteps = stepArr.min()
                maxSteps = stepArr.max()
            }
        } catch {}
        let bodyRepo = BodyRepository(context: context)
        var avgWeight: Double?
        var avgWaist: Double?
        var minWeight: Double?
        var maxWeight: Double?
        var weightArr: [Double] = []
        if let bodies = try? bodyRepo.fetch(range: start...end) {
            let weights = bodies.compactMap { $0.weight }
            let waists = bodies.compactMap { $0.waist }
            if !weights.isEmpty {
                weightArr = weights
                avgWeight = weights.reduce(0, +) / Double(weights.count)
                minWeight = weights.min()
                maxWeight = weights.max()
            }
            if !waists.isEmpty { avgWaist = waists.reduce(0, +) / Double(waists.count) }
        }
        let kcalSeq = dailyKcal.keys.sorted().map { dailyKcal[$0] ?? 0 }
        let avgKcalPerDay = kcalSeq.isEmpty ? nil : (kcalSeq.reduce(0, +) / Double(kcalSeq.count))
        let minKcalPerDay = kcalSeq.min()
        let maxKcalPerDay = kcalSeq.max()
        func trend(_ arr: [Double]) -> String {
            if arr.count >= 6 {
                let a = arr.prefix(3).reduce(0, +) / Double(min(3, arr.count))
                let b = arr.suffix(3).reduce(0, +) / Double(min(3, arr.count))
                if b - a > 0.5 { return "上升" }
                if a - b > 0.5 { return "下降" }
                return "稳定"
            }
            if let first = arr.first, let last = arr.last {
                if last - first > 0.5 { return "上升" }
                if first - last > 0.5 { return "下降" }
            }
            return "稳定"
        }
        let kcalTrend = trend(kcalSeq)
        let stepsTrend = trend(stepArr.map { Double($0) })
        let weightTrend = trend(weightArr)
        var s = HealthSummary(totalKcal: totalKcal, avgSteps: avgSteps, avgWeight: avgWeight, avgWaist: avgWaist)
        s.avgKcalPerDay = avgKcalPerDay
        s.minKcalPerDay = minKcalPerDay
        s.maxKcalPerDay = maxKcalPerDay
        s.minSteps = minSteps
        s.maxSteps = maxSteps
        s.minWeight = minWeight
        s.maxWeight = maxWeight
        s.kcalTrend = kcalTrend
        s.stepsTrend = stepsTrend
        s.weightTrend = weightTrend
        return s
    }
    func generateObservation(context: NSManagedObjectContext, force: Bool = false) async {
        let cfg = ConfigStore.shared.load()
        guard cfg.allowSummary else { return }
        if !force, let cached = ObservationStore.shared.load(for: Date()) { observationText = cached; return }
        isRefreshingObservation = true
        defer { isRefreshingObservation = false }
        let client = AIClient(host: cfg.host)
        let summary = await buildSummary(context: context)
        let msg = AIMessage(role: .user, content: "请根据最近7天的卡路里、步数、体重的统计（均值/最高/最低）与趋势，输出中文 2–4 句，先简要总结，再给出两条建议（饮食+运动），语气温和、可执行。", date: Date())
        if let resp = try? await client.sendChat(messages: [msg], summary: summary, config: cfg) { observationText = resp.text; ObservationStore.shared.save(resp.text, for: Date()) }
    }
    func scheduleReminders() async {
        do {
            try await notifications.requestPermission()
            notifications.scheduleDailyReminders(goal: goal, current: todaySteps)
            notifications.scheduleMealReminders()
            notifications.scheduleHydrationReminders()
            notifications.scheduleWeightReminder()
        } catch {}
    }
    func startObserveSettingsChanges() {
        settingsObserver = NotificationCenter.default.publisher(for: SettingsViewModel.settingsDidChange).sink { [weak self] _ in
            guard let self else { return }
            Task { await self.loadDashboardSummary(); await self.refreshTodayKcal(context: PersistenceController.shared.container.viewContext); self.loadWeight(context: PersistenceController.shared.container.viewContext); await self.generateObservation(context: PersistenceController.shared.container.viewContext) }
        }
        dataObserver = NotificationCenter.default.publisher(for: AppEvents.dataDidChange).sink { [weak self] _ in
            guard let self else { return }
            Task { await self.refreshTodayKcal(context: PersistenceController.shared.container.viewContext); self.loadWeight(context: PersistenceController.shared.container.viewContext) }
        }
    }
}
