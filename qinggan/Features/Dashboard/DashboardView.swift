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
                        Text("体重与腰围").font(.headline)
                        Chart {
                            ForEach(vm.weightTrend, id: \.0) { it in
                                LineMark(x: .value("date", it.0), y: .value("weight", it.1)).foregroundStyle(.purple)
                            }
                            ForEach(vm.waistTrend, id: \.0) { it in
                                LineMark(x: .value("date", it.0), y: .value("waist", it.1)).foregroundStyle(.orange)
                            }
                        }.frame(height: 180)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每日热量摄入").font(.headline)
                        Chart(vm.kcalBars, id: \.0) { it in
                            BarMark(x: .value("date", it.0), y: .value("kcal", it.1)).foregroundStyle(.orange)
                        }.frame(height: 180)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每日步数").font(.headline)
                        Chart(vm.stepTrend) { item in
                            BarMark(x: .value("date", item.date), y: .value("steps", item.steps)).foregroundStyle(.blue)
                        }.frame(height: 180)
                    }
                }
            }.padding(16)
        }
        .task { await vm.load(range: vm.range, context: viewContext) }
        .onChange(of: vm.range) { r in Task { await vm.load(range: r, context: viewContext) } }
    }
}