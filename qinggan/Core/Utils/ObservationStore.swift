import Foundation

final class ObservationStore {
    static let shared = ObservationStore()
    private let keyPrefix = "obs_"
    func load(for date: Date) -> String? {
        let k = keyPrefix + dayKey(date)
        return UserDefaults.standard.string(forKey: k)
    }
    func save(_ text: String, for date: Date) {
        let k = keyPrefix + dayKey(date)
        UserDefaults.standard.set(text, forKey: k)
    }
    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
}