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
    @Published var observationText: String = "今天表现不错！坚持控制热量与活动。"
    @Published var weightTrend: [(Date, Double)] = []
    @Published var currentWeight: Double?
    @Published var calorieTarget: Int = 1800
    private let healthKit = HealthKitService()
    private let notifications = NotificationManager()
    private var settingsObserver: AnyCancellable?
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
            todayKcal = records.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.kcal } }
        }
    }
    func loadWeight(context: NSManagedObjectContext) {
        let bRepo = BodyRepository(context: context)
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        if let bodies = try? bRepo.fetch(range: start...end) {
            weightTrend = bodies.compactMap { rec in if let w = rec.weight { return (rec.date, w) } else { return nil } }
            currentWeight = bodies.last?.weight
        }
    }
    func buildSummary(context: NSManagedObjectContext) async -> HealthSummary {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        let dietRepo = DietRepository(context: context)
        var totalKcal: Double = 0
        if let records = try? dietRepo.fetch(range: start...end) {
            totalKcal = records.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.kcal } }
        }
        var avgSteps = 0
        do {
            try await healthKit.requestAuthorization()
            let steps = try await healthKit.steps(last: 7)
            if !steps.isEmpty { avgSteps = steps.map { $0.steps }.reduce(0, +) / steps.count }
        } catch {}
        let bodyRepo = BodyRepository(context: context)
        var avgWeight: Double?
        var avgWaist: Double?
        if let bodies = try? bodyRepo.fetch(range: start...end) {
            let weights = bodies.compactMap { $0.weight }
            let waists = bodies.compactMap { $0.waist }
            if !weights.isEmpty { avgWeight = weights.reduce(0, +) / Double(weights.count) }
            if !waists.isEmpty { avgWaist = waists.reduce(0, +) / Double(waists.count) }
        }
        return HealthSummary(totalKcal: totalKcal, avgSteps: avgSteps, avgWeight: avgWeight, avgWaist: avgWaist)
    }
    func generateObservation(context: NSManagedObjectContext) async {
        let cfg = ConfigStore.shared.load()
        guard cfg.allowSummary else { return }
        if let cached = ObservationStore.shared.load(for: Date()) { observationText = cached; return }
        let client = AIClient(host: cfg.host)
        let summary = await buildSummary(context: context)
        let msg = AIMessage(role: .user, content: "请根据最近7天的饮食热量、步数、体重与腰围，生成一段中文的今日观察，语气温和、鼓励，控制在两至三句话。", date: Date())
        if let resp = try? await client.sendChat(messages: [msg], summary: summary, config: cfg) { observationText = resp.text; ObservationStore.shared.save(resp.text, for: Date()) }
    }
    func scheduleReminders() async {
        do { try await notifications.requestPermission(); notifications.scheduleDailyReminders(goal: goal, current: todaySteps) } catch {}
    }
    func startObserveSettingsChanges() {
        settingsObserver = NotificationCenter.default.publisher(for: SettingsViewModel.settingsDidChange).sink { [weak self] _ in
            guard let self else { return }
            Task { await self.loadDashboardSummary(); await self.refreshTodayKcal(context: PersistenceController.shared.container.viewContext); self.loadWeight(context: PersistenceController.shared.container.viewContext); await self.generateObservation(context: PersistenceController.shared.container.viewContext) }
        }
    }
}