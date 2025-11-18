import Foundation
import SwiftUI
import CoreData
import Combine
import PhotosUI

@MainActor final class LogViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var recognizedItems: [FoodItemModel] = []
    var recognizedTotalKcal: Int { Int(recognizedItems.reduce(0) { $0 + $1.kcal }) }
    @Published var notes: String = ""
    @Published var mealType: MealType = .breakfast
    @Published var pickerItem: PhotosPickerItem?
    @Published var recordTime: Date = Date()
    @Published var aiRawJSON: Data?
    @Published var todayRecords: [DietRecordModel] = []
    @Published var recognitionError: String?
    @Published var historyRecords: [DietRecordModel] = []
    @Published var historyRangeDays: Int = 7
    @Published var mealFilter: MealType? = nil
    @Published var searchQuery: String = ""
    init() {
        mealType = mealType(for: recordTime)
    }
    func importPhoto() {}
    func runRecognition() async {
        recognitionError = nil
        guard let img = selectedImage, ConfigStore.shared.load().allowVision else { recognitionError = "未选择图片或未启用识别"; return }
        let cfg = ConfigStore.shared.load()
        guard !cfg.host.isEmpty, !cfg.visionModel.isEmpty else { recognitionError = "请在设置中配置AI服务地址和视觉模型"; return }
        let client = AIClient(host: cfg.host)
        let data = img.pngData() ?? Data()
        do {
            let resp = try await client.analyzeImage(data: data, config: cfg)
            recognizedItems = resp.items
            aiRawJSON = resp.rawJSON
            if recognizedItems.isEmpty { recognitionError = "未识别到有效食物，请调整拍摄角度后重试" }
        } catch {
            recognitionError = "识别失败，请检查网络或稍后重试"
        }
    }
    func saveRecord(context: NSManagedObjectContext) async {
        let repo = DietRepository(context: context)
        let imagePath: String? = selectedImage.flatMap {
            let data = $0.jpegData(compressionQuality: 0.9) ?? $0.pngData() ?? Data()
            return "base64:" + data.base64EncodedString()
        }
        let record = DietRecordModel(timestamp: recordTime, mealType: mealType, imagePath: imagePath, aiRawJSON: aiRawJSON, notes: notes, items: recognizedItems)
        do { try repo.save(record) } catch {}
    }
    func loadTodayRecords(context: NSManagedObjectContext) {
        let repo = DietRepository(context: context)
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        if let list = try? repo.fetch(range: start...end) {
            let order: [MealType: Int] = [.breakfast: 0, .lunch: 1, .dinner: 2, .snack: 3]
            todayRecords = list.sorted { lhs, rhs in
                if order[lhs.mealType]! == order[rhs.mealType]! { return lhs.timestamp < rhs.timestamp }
                return order[lhs.mealType]! < order[rhs.mealType]!
            }
        }
    }
    func loadHistory(context: NSManagedObjectContext) {
        let repo = DietRepository(context: context)
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(historyRangeDays - 1), to: end) ?? end
        let endPlus = cal.date(byAdding: .day, value: 1, to: end)!
        if let list = try? repo.fetch(range: start...endPlus) { historyRecords = list.reversed() }
    }
    func filteredHistory() -> [DietRecordModel] {
        historyRecords.filter { rec in
            let mealOk = mealFilter.map { rec.mealType == $0 } ?? true
            if !mealOk { return false }
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty { return true }
            let names = rec.items.map { $0.name }.joined(separator: " ")
            return names.localizedCaseInsensitiveContains(q) || rec.notes.localizedCaseInsensitiveContains(q)
        }
    }
    func groupedHistory() -> [(Date, [DietRecordModel])] {
        let cal = Calendar.current
        var dict: [Date: [DietRecordModel]] = [:]
        for rec in filteredHistory() {
            let day = cal.startOfDay(for: rec.timestamp)
            dict[day, default: []].append(rec)
        }
        let order: [MealType: Int] = [.breakfast: 0, .lunch: 1, .dinner: 2, .snack: 3]
        let sortedDays = dict.keys.sorted(by: >)
        return sortedDays.map { day in
            let arr = (dict[day] ?? []).sorted { lhs, rhs in
                if order[lhs.mealType]! == order[rhs.mealType]! { return lhs.timestamp < rhs.timestamp }
                return order[lhs.mealType]! < order[rhs.mealType]!
            }
            return (day, arr)
        }
    }
    func deleteRecord(context: NSManagedObjectContext, id: UUID) {
        let repo = DietRepository(context: context)
        do { try repo.delete(id: id); loadHistory(context: context); loadTodayRecords(context: context) } catch {}
    }
    
    func syncMealTypeWithRecordTime() { mealType = mealType(for: recordTime) }
    private func mealType(for date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5...10: return .breakfast
        case 11...14: return .lunch
        case 17...21: return .dinner
        default: return .snack
        }
    }
}