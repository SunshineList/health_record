import SwiftUI

struct SettingsView: View {
    @StateObject var vm = SettingsViewModel()
    @State var apiKeyInput: String = ""
    @State var targetWeightText: String = ""
    @State var calorieTargetText: String = ""
    @Environment(\.managedObjectContext) private var viewContext
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(colors: [AppTheme.brand, AppTheme.brand.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.white).frame(width: 64, height: 64)
                            Image(systemName: "person.fill").foregroundColor(AppTheme.brand)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("健康追踪者").foregroundColor(.white).font(.title3).fontWeight(.semibold)
                            Text("当前体重: \(vm.currentWeight.map{ String(format: "%.1f", $0) } ?? "-") kg  目标体重: \(vm.config.targetWeight.map{ String(format: "%.1f", $0) } ?? "-") kg  已减: \(vm.weightLost.map{ String(format: "%.1f", $0) } ?? "-") kg")
                                .foregroundColor(.white.opacity(0.95)).font(.footnote)
                        }
                        Spacer()
                    }
                    .padding(20)
                }.frame(height: 150)
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI 配置").font(.headline)
                        HStack { Text("API Host").frame(width: 100, alignment: .leading); TextField("https://api.example.com", text: $vm.config.host).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).disableAutocorrection(true).keyboardType(.URL) }
                        HStack { Text("API Key").frame(width: 100, alignment: .leading); SecureField("sk-...", text: $apiKeyInput).textFieldStyle(.roundedBorder) }
                        HStack { Text("文本模型").frame(width: 100, alignment: .leading); TextField("gpt-4", text: $vm.config.textModel).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).disableAutocorrection(true) }
                        HStack { Text("视觉模型").frame(width: 100, alignment: .leading); TextField("gpt-4-vision", text: $vm.config.visionModel).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).disableAutocorrection(true) }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("隐私与权限").font(.headline)
                        Toggle("允许上传食物照片", isOn: $vm.config.allowVision)
                        Toggle("允许发送历史统计", isOn: $vm.config.allowSummary)
                        Text("你的 API Key 仅存储在本地设备，不会上传到任何服务器。").foregroundColor(.secondary).font(.footnote)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("目标设置").font(.headline)
                        HStack { Text("目标体重 (kg)").frame(width: 100, alignment: .leading); TextField("68.0", text: $targetWeightText).textFieldStyle(.roundedBorder).keyboardType(.decimalPad) }
                        HStack { Text("每日热量 (kcal)").frame(width: 100, alignment: .leading); TextField("1800", text: $calorieTargetText).textFieldStyle(.roundedBorder).keyboardType(.numberPad) }
                        Stepper("每日步数目标: \(vm.config.dailyStepGoal)", value: $vm.config.dailyStepGoal, in: 1000...30000, step: 100)
                    }
                }
                Card {
                    VStack(spacing: 12) {
                        PrimaryButton(title: "保存Key") { vm.updateKeychain(apiKey: apiKeyInput); apiKeyInput = "" }
                        SecondaryButton(title: "保存配置") {
                            if let tw = Double(targetWeightText) { vm.config.targetWeight = tw }
                            if let ct = Int(calorieTargetText) { vm.config.dailyCalorieTarget = ct }
                            vm.save()
                        }
                        if !vm.apiKeyMasked.isEmpty {
                            Text("API Key: \(vm.apiKeyMasked)").font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }
            }.padding(16)
        }
        .task {
            vm.load()
            vm.loadData(context: viewContext)
            targetWeightText = vm.config.targetWeight.map { String(format: "%.1f", $0) } ?? ""
            calorieTargetText = String(vm.config.dailyCalorieTarget)
        }
    }
}