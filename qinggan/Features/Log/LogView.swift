import SwiftUI
import PhotosUI

struct LogView: View {
    @StateObject var vm = LogViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showCamera = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("记录").font(.largeTitle).fontWeight(.bold)
                Text("让每一餐都富有意义").foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button(action: { showCamera = true }) { PrimaryLabel(title: "拍照记录") }
                    PhotosPicker(selection: $vm.pickerItem, matching: .images) { SecondaryLabel(title: "从相册选择") }
                }
                Picker("餐别", selection: $vm.mealType) {
                    Text("早餐").tag(MealType.breakfast)
                    Text("午餐").tag(MealType.lunch)
                    Text("晚餐").tag(MealType.dinner)
                    Text("加餐").tag(MealType.snack)
                }.pickerStyle(.segmented)
                DatePicker("时间", selection: $vm.recordTime, displayedComponents: [.hourAndMinute])
                if let img = vm.selectedImage {
                    Image(uiImage: img).resizable().scaledToFit().frame(height: 180)
                    PrimaryButton(title: "识别") { Task { await vm.runRecognition() } }
                }
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("识别结果").font(.headline); Spacer(); Text("共 \(Int(vm.recognizedItems.reduce(0){$0 + $1.kcal})) kcal").foregroundColor(.secondary) }
                        if let err = vm.recognitionError { Text(err).foregroundColor(.red) }
                        List {
                            ForEach($vm.recognizedItems) { $item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack { Text("名称"); TextField("", text: $item.name).textFieldStyle(.roundedBorder) }
                                    HStack {
                                        HStack { Text("重量"); Stepper("\(Int(item.weight))g", value: $item.weight, in: 0...2000, step: 10) }
                                        HStack { Text("热量"); Stepper("\(Int(item.kcal))kcal", value: $item.kcal, in: 0...3000, step: 10) }
                                    }
                                    HStack {
                                        HStack { Text("蛋白"); Stepper("\(Int(item.protein))g", value: $item.protein, in: 0...300, step: 1) }
                                        HStack { Text("脂肪"); Stepper("\(Int(item.fat))g", value: $item.fat, in: 0...300, step: 1) }
                                        HStack { Text("碳水"); Stepper("\(Int(item.carb))g", value: $item.carb, in: 0...300, step: 1) }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .onDelete { idx in vm.recognizedItems.remove(atOffsets: idx) }
                            .onMove { indices, newOffset in vm.recognizedItems.move(fromOffsets: indices, toOffset: newOffset) }
                        }
                        HStack(spacing: 12) {
                            SecondaryButton(title: "添加食物") { vm.recognizedItems.append(FoodItemModel(name: "", weight: 0, kcal: 0, protein: 0, fat: 0, carb: 0)) }
                            PrimaryButton(title: "重试识别") { Task { await vm.runRecognition() } }
                        }
                    }
                }
                TextField("备注", text: $vm.notes).textFieldStyle(.roundedBorder)
                PrimaryButton(title: "保存") { Task { await vm.saveRecord(context: viewContext) } }
                Card { Text("拍照后，AI 会自动识别食物并估计热量，你也可以手动编辑调整。").foregroundColor(.secondary) }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("今天的记录").font(.headline); Spacer(); Text("共 \(Int(vm.todayRecords.reduce(0){$0 + $1.items.reduce(0){$0 + $1.kcal}})) kcal").foregroundColor(.secondary) }
                        ForEach(vm.todayRecords) { rec in
                            HStack(alignment: .top) {
                                ZStack { Circle().fill(Color.orange.opacity(0.15)).frame(width: 36, height: 36); Image(systemName: "takeoutbag.and.cup.and.straw.fill").foregroundColor(.orange) }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(label(for: rec.mealType)).fontWeight(.semibold)
                                    Text(rec.items.map{ $0.name }.joined(separator: "、")).foregroundColor(.secondary)
                                    Text("\(Int(rec.items.reduce(0){$0 + $1.kcal})) kcal").foregroundColor(.green)
                                }
                                Spacer()
                                Text(timeString(rec.timestamp)).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }.padding(16)
        }
        .onChange(of: vm.pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { vm.selectedImage = img }
            }
        }
        .task { vm.loadTodayRecords(context: viewContext) }
        .sheet(isPresented: $showCamera) { CameraPicker { img in vm.selectedImage = img } }
    }
}

private func label(for type: MealType) -> String {
    switch type { case .breakfast: return "早餐"; case .lunch: return "午餐"; case .dinner: return "晚餐"; case .snack: return "加餐" }
}
private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "HH:mm"; return f.string(from: date) }
