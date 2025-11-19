import SwiftUI
import Charts

struct HomeView: View {
    @Binding var selectedTab: Int
    @StateObject var vm = HomeViewModel()
    @State private var showBodyEntry = false
    @State private var weightText: String = ""
    @State private var bodyDate: Date = Date()
    @State private var selectedDiet: DietRecordModel?
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84, maximum: 120), spacing: 12)], spacing: 12) {
                        let kcalProgress = vm.calorieTarget > 0 ? Double(vm.todayKcal) / Double(vm.calorieTarget) : 0
                        RingProgress(progress: kcalProgress, color: .orange, title: "热量完成", valueText: "\(Int(vm.todayKcal))/\(vm.calorieTarget)", size: 88)
                        let stepProgress = vm.goal > 0 ? Double(vm.todaySteps) / Double(vm.goal) : 0
                        RingProgress(progress: stepProgress, color: .blue, title: "步数完成", valueText: "\(vm.todaySteps)/\(vm.goal)", size: 88)
                        if let b = vm.bmi {
                            let color: Color = (b < 18.5 ? .blue : (b <= 24.9 ? .green : (b <= 27.9 ? .orange : .red)))
                            let progress = min(b/24.9, 1)
                            VStack(spacing: 4) {
                                RingProgress(progress: progress, color: color, title: "BMI", valueText: String(format: "%.1f", b), size: 88)
                                Text(bmiCategory(b)).font(.caption).foregroundColor(color)
                            }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("今日营养").font(.headline); Spacer(); Text("合计 \(Int(vm.todayKcal)) kcal").foregroundColor(.secondary) }
                        HStack(spacing: 12) {
                            NutrientBadge(name: "蛋白", value: vm.todayProtein, unit: "g", tint: .green)
                            NutrientBadge(name: "脂肪", value: vm.todayFat, unit: "g", tint: .orange)
                            NutrientBadge(name: "碳水", value: vm.todayCarb, unit: "g", tint: .blue)
                        }
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷操作").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84, maximum: 140), spacing: 12)], spacing: 12) {
                            IconAction(icon: "camera.fill", title: "拍照记录", tint: .orange) { selectedTab = 1 }
                            IconAction(icon: "photo.on.rectangle", title: "相册选择", tint: .blue) { selectedTab = 1 }
                            IconAction(icon: "scalemass", title: "记录体重", tint: .purple) { showBodyEntry = true }
                            IconAction(icon: "sparkles", title: "刷新观察", tint: AppTheme.brand) { Task { await vm.generateObservation(context: viewContext, force: true) } }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("饮食图库").font(.headline); Spacer(); Text("最近 \(vm.recentDiet.count) 条").foregroundColor(.secondary) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vm.recentDiet) { rec in
                                    DietThumb(rec: rec)
                                        .frame(width: 108)
                                        .onTapGesture { selectedDiet = rec }
                                        .onAppear {
                                            if vm.recentDietHasMore && !vm.recentDietLoading && rec.id == vm.recentDiet.last?.id { vm.loadRecentDietMore(context: viewContext) }
                                        }
                                }
                            }
                            .animation(nil, value: vm.recentDiet.count)
                            .padding(.vertical, 4)
                        }
                        .transaction { $0.disablesAnimations = true }
                        HStack {
                            Spacer()
                            Button(action: { vm.loadRecentDietMore(context: viewContext) }) { Text(vm.recentDietLoading ? "加载中..." : (vm.recentDietHasMore ? "加载更多" : "没有更多了")) }
                            Spacer()
                        }
                    }
                }
            }.padding(16)
        }
        .task { await vm.loadDashboardSummary(); await vm.refreshSteps(); await vm.refreshTodayKcal(context: viewContext); vm.loadWeight(context: viewContext); vm.loadRecentDietInitial(context: viewContext); await vm.generateObservation(context: viewContext); await vm.scheduleReminders() }
        .sheet(item: $selectedDiet) { rec in
            NavigationView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text(label(for: rec.mealType)).font(.headline); Spacer(); Text(dateTimeString(rec.timestamp)).foregroundColor(.secondary) }
                    if let img = decodeImage(rec.imagePath) { Image(uiImage: img).resizable().scaledToFit().frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12)) }
                    List {
                        ForEach(rec.items) { it in
                            HStack {
                                VStack(alignment: .leading) { Text(it.name).fontWeight(.semibold); Text("\(Int(it.weight))g").foregroundColor(.secondary) }
                                Spacer()
                                VStack(alignment: .trailing) { Text("\(Int(it.kcal)) kcal").foregroundColor(.green); Text("蛋白 \(Int(it.protein))g  脂肪 \(Int(it.fat))g  碳水 \(Int(it.carb))g").foregroundColor(.secondary) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .padding(16)
                .navigationTitle("记录详情")
            }
        }
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
struct DietThumb: View {
    let rec: DietRecordModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                if let img = decodeImageCached(rec.imagePath) {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 88).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)); Image(systemName: "fork.knife").foregroundColor(.orange) }.frame(height: 88).frame(maxWidth: .infinity)
                }
                Text("\(Int(rec.items.reduce(0){ $0 + $1.kcal })) kcal").font(.caption2).foregroundColor(.green).padding(4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemBackground).opacity(0.85)))
                    .offset(x: 6, y: -6)
            }
            Text(timeString(rec.timestamp)).font(.caption2).foregroundColor(.secondary)
            Text(rec.items.map{ $0.name }.joined(separator: "、")).lineLimit(1).truncationMode(.tail).font(.caption2)
        }
    }
}
struct IconAction: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(tint.opacity(0.12)).frame(width: 56, height: 56)
                    Image(systemName: icon).foregroundColor(tint)
                }
                Text(title).font(.footnote).foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.15)))
        }
    }
}
struct NutrientBadge: View {
    let name: String
    let value: Int
    let unit: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint.opacity(0.15)).frame(width: 20, height: 20).overlay(Circle().stroke(tint.opacity(0.3)))
            Text(name).foregroundColor(.primary)
            Text("\(value)\(unit)").foregroundColor(tint)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color(.systemBackground)))
        .overlay(Capsule().stroke(tint.opacity(0.15)))
    }
}
private func decodeImage(_ path: String?) -> UIImage? {
    guard let path else { return nil }
    if path.hasPrefix("base64:") {
        let b64 = String(path.dropFirst(7))
        if let data = Data(base64Encoded: b64) { return UIImage(data: data) }
        return nil
    } else {
        return UIImage(contentsOfFile: path)
    }
}
fileprivate let homeImageCache = NSCache<NSString, UIImage>()
private func decodeImageCached(_ path: String?) -> UIImage? {
    guard let path else { return nil }
    if let cached = homeImageCache.object(forKey: path as NSString) { return cached }
    let img = decodeImage(path)
    if let img { homeImageCache.setObject(img, forKey: path as NSString) }
    return img
}
private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "HH:mm"; return f.string(from: date) }
private func dateTimeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 HH:mm"; return f.string(from: date) }
private func label(for type: MealType) -> String { switch type { case .breakfast: return "早餐"; case .lunch: return "午餐"; case .dinner: return "晚餐"; case .snack: return "加餐" } }
private func bmiCategory(_ b: Double) -> String {
    if b < 18.5 { return "偏瘦" }
    if b <= 24.9 { return "正常" }
    if b <= 27.9 { return "超重" }
    return "肥胖"
}
private func chineseHeaderDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "M月d日 EEEE"
    return f.string(from: date)
}