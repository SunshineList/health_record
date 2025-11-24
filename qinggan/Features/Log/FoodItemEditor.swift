import SwiftUI

struct FoodItemEditor: View {
    @EnvironmentObject var vm: LogViewModel
    @Binding var item: FoodItemModel
    let onDelete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("名称").font(.footnote).foregroundColor(.secondary)
                TextField("食物名称", text: $item.name).textFieldStyle(.roundedBorder)
            }
            MetricRow(title: "重量", value: $item.weight, unit: "g", step: 10, range: 0...2000)
            MetricRow(title: "热量", value: $item.kcal, unit: "kcal", step: 10, range: 0...3000)
            MetricRow(title: "蛋白", value: $item.protein, unit: "g", step: 1, range: 0...300)
            MetricRow(title: "脂肪", value: $item.fat, unit: "g", step: 1, range: 0...300)
            MetricRow(title: "碳水", value: $item.carb, unit: "g", step: 1, range: 0...300)
            HStack {
                Button(action: { Task { let r = await vm.estimateForItem(item); item = r } }) { Text(vm.isEstimating ? "估算中..." : "AI估算") }
                    .disabled(vm.isEstimating)
                Spacer()
                Button(action: onDelete) { Text("删除").foregroundColor(.red) }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MetricRow: View {
    let title: String
    @Binding var value: Double
    let unit: String
    let step: Double
    let range: ClosedRange<Double>
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(title).frame(width: 44, alignment: .leading).foregroundColor(.secondary)
                TextField("0", value: $value, format: .number).keyboardType(.numberPad).frame(width: 100).textFieldStyle(.roundedBorder)
                Text(unit).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 16) {
                    Button(action: { value = max(range.lowerBound, value - step) }) { Image(systemName: "minus.circle").foregroundColor(.secondary) }
                    Button(action: { value = min(range.upperBound, value + step) }) { Image(systemName: "plus.circle").foregroundColor(.secondary) }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title).foregroundColor(.secondary)
                HStack(spacing: 12) {
                    TextField("0", value: $value, format: .number).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Text(unit).foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { value = max(range.lowerBound, value - step) }) { Image(systemName: "minus.circle").foregroundColor(.secondary) }
                        Button(action: { value = min(range.upperBound, value + step) }) { Image(systemName: "plus.circle").foregroundColor(.secondary) }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
