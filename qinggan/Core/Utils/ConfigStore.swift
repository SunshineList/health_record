import Foundation

final class ConfigStore {
    static let shared = ConfigStore()
    private let key = "ai_config_v1"
    func load() -> AIConfig {
        if let data = UserDefaults.standard.data(forKey: key), let cfg = try? JSONDecoder().decode(AIConfig.self, from: data) { return cfg }
        return AIConfig(host: "", textModel: "", visionModel: "", allowVision: true, allowSummary: true, dailyStepGoal: 8000, targetWeight: nil, dailyCalorieTarget: 1800, appearance: "system", heightCm: nil)
    }
    func save(_ config: AIConfig) {
        if let data = try? JSONEncoder().encode(config) { UserDefaults.standard.set(data, forKey: key) }
    }
}