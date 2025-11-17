import SwiftUI
import Charts

struct HomeView: View {
    @Binding var selectedTab: Int
    @StateObject var vm = HomeViewModel()
    @State private var showBodyEntry = false
    @State private var weightText: String = ""
    @State private var waistText: String = ""
    @State private var bodyDate: Date = Date()
    @Environment(\.managedObjectContext) private var viewContext
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(chineseHeaderDate(Date())).font(.caption).foregroundColor(.secondary)
                Text("今日概览").font(.largeTitle).fontWeight(.bold)
                BannerCard(icon: "sparkles", title: "AI 观察", text: vm.observationText)
                HStack(spacing: 12) {
                    StatCard(icon: "flame", title: "今日热量", value: "\(Int(vm.todayKcal)) / \(vm.calorieTarget)", subtitle: "还能摄入 \(max(0, vm.calorieTarget - Int(vm.todayKcal))) kcal", tint: .orange)
                    StatCard(icon: "figure.walk", title: "今日步数", value: "\(vm.todaySteps)", subtitle: vm.isGoalMet ? "已达标" : "目标 \(vm.goal)", tint: vm.isGoalMet ? .green : .blue)
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("体重走势").font(.headline)
                            Spacer()
                            Text(vm.currentWeight.map { String(format: "%.1f kg", $0) } ?? "-").foregroundColor(.secondary)
                        }
                        Chart(vm.weightTrend, id: \.0) { it in
                            LineMark(x: .value("date", it.0), y: .value("weight", it.1))
                        }.frame(height: 120)
                    }
                }
                Text("快捷操作").font(.headline)
                HStack(spacing: 12) {
                    PrimaryButton(title: "记录饮食") { selectedTab = 1 }
                    SecondaryButton(title: "记录体重") { showBodyEntry = true }
                }
            }.padding(16)
        }
        .task { await vm.loadDashboardSummary(); await vm.refreshSteps(); await vm.refreshTodayKcal(context: viewContext); vm.loadWeight(context: viewContext); await vm.generateObservation(context: viewContext); await vm.scheduleReminders() }
        .onAppear { vm.startObserveSettingsChanges() }
        .sheet(isPresented: $showBodyEntry) {
            NavigationView {
                Form {
                    Section(header: Text("记录体重与腰围")) {
                        HStack { Text("体重(kg)"); TextField("72.5", text: $weightText).keyboardType(.decimalPad) }
                        HStack { Text("腰围(cm)"); TextField("82.0", text: $waistText).keyboardType(.decimalPad) }
                        DatePicker("日期", selection: $bodyDate, displayedComponents: [.date])
                    }
                    Section { Button("保存") { let repo = BodyRepository(context: viewContext); let rec = BodyRecordModel(date: bodyDate, weight: Double(weightText), waist: Double(waistText)); do { try repo.save(rec) } catch {}; showBodyEntry = false } }
                }
                .navigationTitle("记录体重")
            }
        }
    }
}
private func chineseHeaderDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "M月d日 EEEE"
    return f.string(from: date)
}