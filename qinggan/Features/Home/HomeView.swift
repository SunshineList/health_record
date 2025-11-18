import SwiftUI
import Charts

struct HomeView: View {
    @Binding var selectedTab: Int
    @StateObject var vm = HomeViewModel()
    @State private var showBodyEntry = false
    @State private var weightText: String = ""
    @State private var bodyDate: Date = Date()
    @Environment(\.managedObjectContext) private var viewContext
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(chineseHeaderDate(Date())).font(.caption).foregroundColor(.secondary)
                Text("今日概览").font(.largeTitle).fontWeight(.bold)
                BannerCard(icon: "sparkles", title: "AI 观察", text: vm.observationText)
                    .onTapGesture { Task { await vm.generateObservation(context: viewContext, force: true) } }
                    .overlay(alignment: .topTrailing) {
                        if vm.isRefreshingObservation {
                            ProgressView().padding(6)
                        } else {
                            Button(action: { Task { await vm.generateObservation(context: viewContext, force: true) } }) {
                                Image(systemName: "arrow.clockwise").foregroundColor(AppTheme.brand)
                            }.padding(6)
                        }
                    }
                HStack(spacing: 12) {
                    StatCard(icon: "flame", title: "今日热量", value: "\(Int(vm.todayKcal)) / \(vm.calorieTarget)", subtitle: "还能摄入 \(max(0, vm.calorieTarget - Int(vm.todayKcal))) kcal", tint: .orange)
                    StatCard(icon: "figure.walk", title: "今日步数", value: "\(vm.todaySteps)", subtitle: vm.isGoalMet ? "已达标" : "目标 \(vm.goal)", tint: vm.isGoalMet ? .green : .blue)
                }
                Card {
                  HStack(spacing: 24) {
                        let kcalProgress = vm.calorieTarget > 0 ? Double(vm.todayKcal) / Double(vm.calorieTarget) : 0
                        RingProgress(progress: kcalProgress, color: .orange, title: "热量完成", valueText: "\(Int(vm.todayKcal))/\(vm.calorieTarget)")
                        let stepProgress = vm.goal > 0 ? Double(vm.todaySteps) / Double(vm.goal) : 0
                        RingProgress(progress: stepProgress, color: .blue, title: "步数完成", valueText: "\(vm.todaySteps)/\(vm.goal)")
                        Spacer()
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("体重走势").font(.headline); Spacer(); Text(vm.currentWeight.map { String(format: "%.1f kg", $0) } ?? "-").foregroundColor(.secondary) }
                        if vm.weightTrend.isEmpty {
                            Text("暂无体重数据").foregroundColor(.secondary).padding(.vertical, 24)
                        } else if vm.weightTrend.count == 1, let p = vm.weightTrend.first {
                            Chart {
                                PointMark(x: .value("日期", p.0), y: .value("体重", p.1)).foregroundStyle(.purple).symbol(.circle).symbolSize(100).annotation(position: .top) { Text(String(format: "%.1f", p.1)).font(.caption).foregroundColor(.purple) }
                            }
                            .frame(height: 120)
                        } else {
                            Chart {
                                ForEach(vm.weightTrend, id: \.0) { it in
                                    LineMark(x: .value("日期", it.0), y: .value("体重", it.1)).foregroundStyle(.purple)
                                    PointMark(x: .value("日期", it.0), y: .value("体重", it.1)).foregroundStyle(.purple).symbol(.circle).symbolSize(80).annotation(position: .top) { Text(String(format: "%.1f", it.1)).font(.caption).foregroundColor(.purple) }
                                }
                            }
                            .frame(height: 120)
                            .chartXAxis {
                                AxisMarks(values: vm.weightTrend.map { $0.0 }) { value in
                                    if let date = value.as(Date.self) { AxisGridLine(); AxisValueLabel(chineseHeaderDate(date)) }
                                }
                            }
                        }
                    }
                }
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("今日记录").font(.headline)
                            Text("已记录 \(vm.todayMealsCount) 条，合计 \(Int(vm.todayKcal)) kcal").foregroundColor(.secondary)
                        }
                        Spacer()
                        PrimaryButton(title: "去记录") { selectedTab = 1 }
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
                    Section(header: Text("记录体重")) {
                        HStack { Text("体重(kg)"); TextField("72.5", text: $weightText).keyboardType(.decimalPad) }
                        DatePicker("日期", selection: $bodyDate, displayedComponents: [.date])
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                    Section { Button("保存") { let repo = BodyRepository(context: viewContext); let rec = BodyRecordModel(date: bodyDate, weight: Double(weightText), waist: nil); do { try repo.save(rec) } catch {}; showBodyEntry = false } }
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