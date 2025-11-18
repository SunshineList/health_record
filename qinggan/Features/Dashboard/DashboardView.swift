import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject var vm = DashboardViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("趋势").font(.largeTitle).fontWeight(.bold)
                Text("数据会说话，坚持就有回报").foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Chip(title: "近7天", selected: vm.range == 7) { vm.range = 7 }
                    Chip(title: "近30天", selected: vm.range == 30) { vm.range = 30 }
                    Chip(title: "近90天", selected: vm.range == 90) { vm.range = 90 }
                }
                Card {
                    VStack(alignment: .leading) {
                        Text("本周总结").font(.headline)
                        Text(vm.summaryText.isEmpty ? "过去 7 天，体重下降，腰围减少，平均步数稳定。继续保持。" : vm.summaryText).foregroundColor(.secondary)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("体重趋势").font(.headline); Spacer(); if let last = vm.weightTrend.last { Text(String(format: "%.1f kg", last.1)).foregroundColor(.secondary) } }
                        if vm.weightTrend.isEmpty {
                            Text("暂无体重数据").foregroundColor(.secondary).padding(.vertical, 24)
                        } else if vm.weightTrend.count == 1, let p = vm.weightTrend.first {
                            Chart {
                                PointMark(x: .value("日期", p.0), y: .value("体重", p.1))
                                    .foregroundStyle(.purple)
                                    .symbol(.circle)
                                    .symbolSize(120)
                                    .annotation(position: .top) { Text(String(format: "%.1f", p.1)).font(.caption).foregroundColor(.purple) }
                            }
                            .frame(height: 180)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .chartYScale(domain: [max(p.1 - 5, 0), p.1 + 5])
                            .chartXAxis {
                                AxisMarks(values: vm.weightTrend.map { $0.0 }) { value in
                                    if let date = value.as(Date.self) {
                                        AxisGridLine()
                                        AxisValueLabel(chineseDay(date))
                                    }
                                }
                            }
                        } else {
                            Chart {
                                ForEach(vm.weightTrend, id: \.0) { it in
                                    LineMark(x: .value("日期", it.0), y: .value("体重", it.1)).foregroundStyle(.purple)
                                    PointMark(x: .value("日期", it.0), y: .value("体重", it.1))
                                        .foregroundStyle(.purple)
                                        .symbol(.circle)
                                        .symbolSize(90)
                                        .annotation(position: .top) { Text(String(format: "%.1f", it.1)).font(.caption).foregroundColor(.purple) }
                                }
                            }
                            .frame(height: 180)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .chartXAxis {
                                AxisMarks(values: vm.weightTrend.map { $0.0 }) { value in
                                    if let date = value.as(Date.self) {
                                        AxisGridLine()
                                        AxisValueLabel(chineseDay(date))
                                    }
                                }
                            }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每日热量摄入").font(.headline)
                        Chart(vm.kcalBars, id: \.0) { it in
                            BarMark(x: .value("date", it.0), y: .value("kcal", it.1)).foregroundStyle(.orange)
                                .annotation(position: .top) { Text("\(Int(it.1))").font(.caption).foregroundColor(.orange) }
                        }
                        .frame(height: 180)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .chartXAxis {
                            AxisMarks(values: vm.kcalBars.map { $0.0 }) { value in
                                if let date = value.as(Date.self) {
                                    AxisGridLine()
                                    AxisValueLabel(chineseDay(date))
                                }
                            }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每日步数").font(.headline)
                        Chart(vm.stepTrend) { item in
                            BarMark(x: .value("date", item.date), y: .value("steps", item.steps)).foregroundStyle(.blue)
                                .annotation(position: .top) { Text("\(item.steps)").font(.caption).foregroundColor(.blue) }
                        }
                        .frame(height: 180)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .chartXAxis {
                            AxisMarks(values: vm.stepTrend.map { $0.date }) { value in
                                if let date = value.as(Date.self) {
                                    AxisGridLine()
                                    AxisValueLabel(chineseDay(date))
                                }
                            }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("体重记录列表").font(.headline); Spacer() }
                        WeightListView()
                            .frame(height: 260)
                    }
                }
            }.padding(16)
        }
        .task { await vm.load(range: vm.range, context: viewContext) }
        .onChange(of: vm.range) { _, r in Task { await vm.load(range: r, context: viewContext) } }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.dataDidChange)) { _ in Task { await vm.load(range: vm.range, context: viewContext) } }
    }
}

private func chineseDay(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"; return f.string(from: date) }