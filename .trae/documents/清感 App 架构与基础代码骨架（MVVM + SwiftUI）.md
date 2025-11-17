# 架构选择
- 采用 MVVM + SwiftUI。
- 理由：当前工程已集成 Core Data 与 SwiftUI，MVVM无第三方依赖、落地成本最低；各 Feature 的状态与业务逻辑天然适合集成到 ObservableObject。若后续规模扩大、需要更强的可组合性与特性隔离，可平滑演进到 TCA。

# 目录组织（依照现有工程 qinggan/ 扩展）
- 保留：`qingganApp.swift`、`Persistence.swift`、`Assets.xcassets`、`qinggan.xcdatamodeld`。
- 新增目录（均位于 `qinggan/` 下）：
  - `Core/Models`
  - `Core/Protocols`
  - `Core/Utils`
  - `Data/Services`（HealthKit、AI）
  - `Data/Repositories`（Core Data 仓库）
  - `Data/Notifications`
  - `Features/Home`
  - `Features/Log`
  - `Features/Dashboard`
  - `Features/Chat`
  - `Features/Settings`
  - `UI/Components`
- 将 `ContentView.swift` 角色替换为 `AppRootView.swift`，作为 Tab 导航入口。

# 本地存储推荐
- 推荐使用 Core Data（当前工程已内置），支持关系型数据与查询，利于 FoodItem 与 DietRecord 的一对多；支持预取与统计。
- 若更偏向手写 SQL，可选 SQLite/GRDB；但在 iOS 17/18 + SwiftUI 下，Core Data 集成体验更好。

# 关键模型草稿（Entity/DTO）
- Core Data（建议 xcdatamodel 中定义以下实体与关系）：
  - DietRecord: `id: UUID`, `timestamp: Date`, `mealType: Int16`, `imagePath: String`, `aiRawJSON: Data`, `notes: String`
  - FoodItem: `id: UUID`, `name: String`, `weight: Double`, `kcal: Double`, `protein: Double`, `fat: Double`, `carb: Double`, 关系 `dietRecord: DietRecord`
  - BodyRecord: `id: UUID`, `date: Date`, `weight: Double?`, `waist: Double?`
  - StepStat: `id: UUID`, `date: Date`, `steps: Int64`
  - ChatMessage: `id: UUID`, `date: Date`, `role: Int16`, `content: String`
- Domain/DTO（Swift struct，与 Core Data 解耦）：
```swift
// Core/Models/DomainModels.swift
import Foundation

enum MealType: Int, CaseIterable { case breakfast, lunch, dinner, snack }

struct FoodItem: Identifiable, Codable { var id = UUID(); var name: String; var weight: Double; var kcal: Double; var protein: Double; var fat: Double; var carb: Double }

struct DietRecord: Identifiable, Codable { var id = UUID(); var timestamp: Date; var mealType: MealType; var imagePath: String?; var aiRawJSON: Data?; var notes: String; var items: [FoodItem] }

struct BodyRecord: Identifiable, Codable { var id = UUID(); var date: Date; var weight: Double?; var waist: Double? }

struct StepStat: Identifiable, Codable { var id = UUID(); var date: Date; var steps: Int }

struct AIConfig: Codable { var host: String; var textModel: String; var visionModel: String; var allowVision: Bool; var allowSummary: Bool; var dailyStepGoal: Int }

enum AIMessageRole: String, Codable { case system, user, assistant }

struct AIMessage: Identifiable, Codable { var id = UUID(); var role: AIMessageRole; var content: String; var date: Date }

struct HealthSummary: Codable { var totalKcal: Double; var avgSteps: Int; var avgWeight: Double?; var avgWaist: Double? }

struct AIDishRecognitionResponse: Codable { var items: [FoodItem]; var rawJSON: Data }

struct AIChatResponse: Codable { var text: String }
```

# AI Client 接口设计
```swift
// Core/Protocols/AIClientProtocol.swift
import Foundation

protocol AIClientProtocol {
    var host: String { get }
    func analyzeImage(data: Data, config: AIConfig) async throws -> AIDishRecognitionResponse
    func sendChat(messages: [AIMessage], summary: HealthSummary?, config: AIConfig) async throws -> AIChatResponse
}
```
- 实现要点：用 `URLSession`；将 `apiKey` 置于 `Authorization` 头；`host` 与 `model` 来自 Settings；`visionModel` 用于图像识别端点；Respect 用户开关：未允许则不上传图片或统计。
- `apiKey` 使用 Keychain 安全存储，不入 Core Data。

# ViewModel 主要属性与方法
- HomeViewModel
  - 属性：`todaySteps`, `goal`, `isGoalMet`, `recent7Steps`, `recent30Steps`, `todayKcal`, `recentKcal`
  - 方法：`loadDashboardSummary()`, `refreshSteps()`, `scheduleReminders()`
- LogViewModel
  - 属性：`selectedImage`, `recognizedItems`, `notes`, `mealType`, `saving`
  - 方法：`importPhoto()`, `runRecognition()`, `saveRecord()`, `fetchRecords()`
- DashboardViewModel
  - 属性：`range: Int`, `weightTrend`, `waistTrend`, `stepTrend`, `kcalBars`
  - 方法：`load(range:)`
- ChatViewModel
  - 属性：`messages`, `inputText`, `attachSummary`, `sending`
  - 方法：`loadHistory()`, `buildSummary()`, `send()`
- SettingsViewModel
  - 属性：`config: AIConfig`, `apiKeyMasked`
  - 方法：`load()`, `save()`, `updateKeychain(apiKey:)`

# 通知与 HealthKit
- HealthKitService：仅读取步数。提供授权与统计查询（日/区间）。
- NotificationManager：每天 11:30、17:00、21:00 本地通知。策略：在应用前台或定时任务触达前更新通知内容；低于目标比例时发出温和提醒。必要时可引入 BackgroundTasks 优化时机。

# Figma 遵循要点
- 严格遵循布局与交互；避免在一个可点击元素内嵌另一个可点击元素（如 Button 内再放 NavigationLink）。

# 可运行代码骨架（逻辑为空）
```swift
// AppRootView.swift
import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Image(systemName: "house"); Text("首页") }
            LogView().tabItem { Image(systemName: "camera"); Text("记录") }
            DashboardView().tabItem { Image(systemName: "chart.bar"); Text("Dashboard") }
            ChatView().tabItem { Image(systemName: "message"); Text("教练") }
            SettingsView().tabItem { Image(systemName: "gearshape"); Text("设置") }
        }
    }
}
```
```swift
// Data/Services/AIClient.swift
import Foundation

final class AIClient: AIClientProtocol {
    let host: String
    init(host: String) { self.host = host }
    func analyzeImage(data: Data, config: AIConfig) async throws -> AIDishRecognitionResponse {
        return AIDishRecognitionResponse(items: [], rawJSON: Data())
    }
    func sendChat(messages: [AIMessage], summary: HealthSummary?, config: AIConfig) async throws -> AIChatResponse {
        return AIChatResponse(text: "")
    }
}
```
```swift
// Core/Utils/KeychainService.swift
import Foundation

final class KeychainService {
    static let shared = KeychainService()
    private var memoryStore: String = ""
    func setAPIKey(_ key: String) { memoryStore = key }
    func getAPIKey() -> String { memoryStore }
}
```
```swift
// Data/Services/HealthKitService.swift
import Foundation
import HealthKit

final class HealthKitService {
    let store = HKHealthStore()
    func requestAuthorization() async throws {
        let type = HKObjectType.quantityType(forIdentifier: .stepCount)!
        try await store.requestAuthorization(toShare: [], read: [type])
    }
    func steps(for date: Date) async throws -> Int { 0 }
    func steps(last days: Int) async throws -> [StepStat] { [] }
}
```
```swift
// Data/Notifications/NotificationManager.swift
import Foundation
import UserNotifications

final class NotificationManager {
    func requestPermission() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
    func scheduleDailyReminders() {
        let times = [(11,30),(17,0),(21,0)]
        for t in times { schedule(hour: t.0, minute: t.1) }
    }
    private func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "步数提醒"
        content.body = "今天活动稍少，试试散步或拉伸"
        var date = DateComponents()
        date.hour = hour; date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "steps_\(hour)_\(minute)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
```
```swift
// Data/Repositories/DietRepository.swift
import Foundation
import CoreData

final class DietRepository {
    let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }
    func save(_ record: DietRecord) throws {}
    func fetch(range: ClosedRange<Date>) throws -> [DietRecord] { [] }
}
```
```swift
// Features/Home/HomeViewModel.swift
import Foundation

@MainActor final class HomeViewModel: ObservableObject {
    @Published var todaySteps: Int = 0
    @Published var goal: Int = 8000
    @Published var isGoalMet: Bool = false
    @Published var recent7Steps: [StepStat] = []
    @Published var recent30Steps: [StepStat] = []
    @Published var todayKcal: Double = 0
    func loadDashboardSummary() async {}
    func refreshSteps() async {}
}
```
```swift
// Features/Home/HomeView.swift
import SwiftUI
import Charts

struct HomeView: View {
    @StateObject var vm = HomeViewModel()
    var body: some View {
        VStack {
            Text("今日步数 \(vm.todaySteps)/\(vm.goal)")
            Chart(vm.recent7Steps) { item in
                BarMark(x: .value("date", item.date), y: .value("steps", item.steps))
            }
        }.padding()
    }
}
```
```swift
// Features/Log/LogViewModel.swift
import Foundation
import SwiftUI

@MainActor final class LogViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var recognizedItems: [FoodItem] = []
    @Published var notes: String = ""
    @Published var mealType: MealType = .breakfast
    func importPhoto() {}
    func runRecognition() async {}
    func saveRecord() async {}
}
```
```swift
// Features/Log/LogView.swift
import SwiftUI

struct LogView: View {
    @StateObject var vm = LogViewModel()
    var body: some View {
        VStack {
            Text("记录饮食")
            Button("识别") { Task { await vm.runRecognition() } }
        }.padding()
    }
}
```
```swift
// Features/Dashboard/DashboardViewModel.swift
import Foundation

@MainActor final class DashboardViewModel: ObservableObject {
    @Published var range: Int = 7
    @Published var weightTrend: [Double] = []
    @Published var waistTrend: [Double] = []
    @Published var stepTrend: [StepStat] = []
    @Published var kcalBars: [(Date, Double)] = []
    func load(range: Int) async {}
}
```
```swift
// Features/Dashboard/DashboardView.swift
import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject var vm = DashboardViewModel()
    var body: some View {
        VStack {
            Text("Dashboard")
        }.padding()
    }
}
```
```swift
// Features/Chat/ChatViewModel.swift
import Foundation

@MainActor final class ChatViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var inputText: String = ""
    @Published var attachSummary: Bool = false
    @Published var sending: Bool = false
    func loadHistory() async {}
    func buildSummary() async -> HealthSummary { HealthSummary(totalKcal: 0, avgSteps: 0, avgWeight: nil, avgWaist: nil) }
    func send() async {}
}
```
```swift
// Features/Chat/ChatView.swift
import SwiftUI

struct ChatView: View {
    @StateObject var vm = ChatViewModel()
    var body: some View {
        VStack {
            List(vm.messages) { m in Text(m.content) }
            Toggle("附加最近7天摘要", isOn: $vm.attachSummary)
            HStack {
                TextField("输入消息", text: $vm.inputText)
                Button("发送") { Task { await vm.send() } }
            }
        }
    }
}
```
```swift
// Features/Settings/SettingsViewModel.swift
import Foundation

@MainActor final class SettingsViewModel: ObservableObject {
    @Published var config = AIConfig(host: "", textModel: "", visionModel: "", allowVision: true, allowSummary: true, dailyStepGoal: 8000)
    @Published var apiKeyMasked: String = ""
    func load() {}
    func save() { }
    func updateKeychain(apiKey: String) { KeychainService.shared.setAPIKey(apiKey) }
}
```
```swift
// Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @StateObject var vm = SettingsViewModel()
    @State var apiKeyInput: String = ""
    var body: some View {
        Form {
            Section { TextField("Host", text: $vm.config.host) }
            Section { TextField("Text Model", text: $vm.config.textModel) }
            Section { TextField("Vision Model", text: $vm.config.visionModel) }
            Section { Toggle("允许上传食物照片", isOn: $vm.config.allowVision) }
            Section { Toggle("允许发送历史统计", isOn: $vm.config.allowSummary) }
            Section { TextField("API Key", text: $apiKeyInput); Button("保存Key") { vm.updateKeychain(apiKey: apiKeyInput) } }
            Section { Stepper("每日步数目标: \(vm.config.dailyStepGoal)", value: $vm.config.dailyStepGoal, in: 1000...30000, step: 500) }
        }
    }
}
```
```swift
// qingganApp.swift 替换 body 的根视图为 AppRootView
// WindowGroup { AppRootView().environment(\.managedObjectContext, persistenceController.container.viewContext) }
```

# 后续实现要点
- 扩展 xcdatamodeld 实体与关系；为 NSManagedObject 生成类或使用动态访问。
- 仓库层将 Domain <-> Core Data 映射集中管理。
- AI Client 按用户配置动态选择端点与模型；遵守隐私开关。
- Charts 组件按 Figma 规格布局与配色；避免嵌套交互。
- 通知阈值：11:30 目标的 30%，17:00 70%，21:00 100% 为参考可调。

请确认以上结构与骨架，我即可在当前工程中创建文件并接入到可运行状态，随后按 Figma 细化 UI。