import Foundation

enum MealType: Int, CaseIterable, Codable, Hashable { case breakfast, lunch, dinner, snack }

struct FoodItemModel: Identifiable, Codable { var id = UUID(); var name: String; var weight: Double; var kcal: Double; var protein: Double; var fat: Double; var carb: Double }

struct DietRecordModel: Identifiable, Codable { var id = UUID(); var timestamp: Date; var mealType: MealType; var imagePath: String?; var aiRawJSON: Data?; var notes: String; var items: [FoodItemModel] }

struct BodyRecordModel: Identifiable, Codable { var id = UUID(); var date: Date; var weight: Double?; var waist: Double? }

struct StepStatModel: Identifiable, Codable { var id = UUID(); var date: Date; var steps: Int }

struct AIConfig: Codable { var host: String; var textModel: String; var visionModel: String; var allowVision: Bool; var allowSummary: Bool; var dailyStepGoal: Int; var targetWeight: Double?; var dailyCalorieTarget: Int; var appearance: String?; var heightCm: Double? }
struct AppearanceConfig: Codable { var appearance: String? }

enum AIMessageRole: String, Codable { case system, user, assistant }

struct AIMessage: Identifiable, Codable { var id = UUID(); var role: AIMessageRole; var content: String; var date: Date }

struct ChatThread: Identifiable, Codable { var id: UUID; var lastDate: Date }

struct HealthSummary: Codable {
    var totalKcal: Double
    var avgSteps: Int
    var avgWeight: Double?
    var avgWaist: Double?
    var avgKcalPerDay: Double? = nil
    var minKcalPerDay: Double? = nil
    var maxKcalPerDay: Double? = nil
    var minSteps: Int? = nil
    var maxSteps: Int? = nil
    var minWeight: Double? = nil
    var maxWeight: Double? = nil
    var kcalTrend: String? = nil
    var stepsTrend: String? = nil
    var weightTrend: String? = nil
}

struct AIDishRecognitionResponse: Codable { var items: [FoodItemModel]; var rawJSON: Data }

struct AIChatResponse: Codable { var text: String }
