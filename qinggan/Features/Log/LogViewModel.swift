import Foundation
import SwiftUI
import CoreData
import Combine
import PhotosUI

@MainActor final class LogViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var recognizedItems: [FoodItemModel] = []
    @Published var notes: String = ""
    @Published var mealType: MealType = .breakfast
    @Published var pickerItem: PhotosPickerItem?
    @Published var recordTime: Date = Date()
    @Published var aiRawJSON: Data?
    @Published var todayRecords: [DietRecordModel] = []
    @Published var recognitionError: String?
    func importPhoto() {}
    func runRecognition() async {
        recognitionError = nil
        guard let img = selectedImage, ConfigStore.shared.load().allowVision else { recognitionError = "未选择图片或未启用识别"; return }
        let cfg = ConfigStore.shared.load()
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
        let imagePath: String? = selectedImage.flatMap { ImageStore.saveImage($0) }
        let record = DietRecordModel(timestamp: recordTime, mealType: mealType, imagePath: imagePath, aiRawJSON: aiRawJSON, notes: notes, items: recognizedItems)
        do { try repo.save(record) } catch {}
    }
    func loadTodayRecords(context: NSManagedObjectContext) {
        let repo = DietRepository(context: context)
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        if let list = try? repo.fetch(range: start...end) { todayRecords = list }
    }
}