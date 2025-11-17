import Foundation
import CoreData
import Combine

@MainActor final class SettingsViewModel: ObservableObject {
    @Published var config = ConfigStore.shared.load()
    @Published var apiKeyMasked: String = ""
    @Published var currentWeight: Double?
    @Published var weightLost: Double?
    static let settingsDidChange = Notification.Name("SettingsDidChange")
    func load() { config = ConfigStore.shared.load(); loadAPIKeyMasked() }
    func save() { ConfigStore.shared.save(config); NotificationCenter.default.post(name: Self.settingsDidChange, object: nil) }
    func updateKeychain(apiKey: String) { KeychainService.shared.setAPIKey(apiKey); apiKeyMasked = String(repeating: "*", count: max(0, apiKey.count)); NotificationCenter.default.post(name: Self.settingsDidChange, object: nil) }
    func loadData(context: NSManagedObjectContext) {
        let repo = BodyRepository(context: context)
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -90, to: end) ?? end
        if let bodies = try? repo.fetch(range: start...end) {
            currentWeight = bodies.last?.weight
            if let t = config.targetWeight, let c = currentWeight { weightLost = max(0, c - t) }
        }
    }
    private func loadAPIKeyMasked() {
        let key = KeychainService.shared.getAPIKey()
        apiKeyMasked = key.isEmpty ? "" : String(repeating: "*", count: key.count)
    }
}
