import SwiftUI
import PhotosUI

struct LogView: View {
    @StateObject var vm = LogViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showCamera = false
    @State private var selectedRecord: DietRecordModel?
    var groups: [(Date, [DietRecordModel])] { vm.groupedHistory() }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("记录").font(.largeTitle).fontWeight(.bold)
                Text("让每一餐都富有意义").foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button(action: {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showCamera = true
                        } else {
                            vm.recognitionError = "设备不支持相机，请使用相册选择"
                        }
                    }) { PrimaryLabel(title: "拍照记录") }
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
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text("识别结果").font(.headline); Spacer(); Text("共 \(vm.recognizedTotalKcal) kcal").foregroundColor(.secondary) }
                        if let err = vm.recognitionError { Text(err).foregroundColor(.red) }
                        VStack(alignment: .leading, spacing: 14) {
                            if vm.recognizedItems.isEmpty { Text("暂无食物，点击下方‘添加食物’或重新识别").foregroundColor(.secondary) }
                            ForEach($vm.recognizedItems) { $item in
                                Card { FoodItemEditor(item: $item) { vm.recognizedItems.removeAll(where: { $0.id == item.id }) } }
                            }
                        }
                        HStack(spacing: 12) {
                            SecondaryButton(title: "添加食物") { vm.recognizedItems.append(FoodItemModel(name: "", weight: 0, kcal: 0, protein: 0, fat: 0, carb: 0)) }
                            SecondaryButton(title: "清空识别") { vm.recognizedItems.removeAll(); vm.recognitionError = nil; vm.selectedImage = nil; vm.aiRawJSON = nil }
                            PrimaryButton(title: "重试识别") { Task { await vm.runRecognition() } }
                        }
                    }
                }
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $vm.notes)
                        .frame(minHeight: 120)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.25)))
                    if vm.notes.isEmpty { Text("备注").foregroundColor(.secondary).padding(.horizontal, 14).padding(.vertical, 12) }
                }
                PrimaryButton(title: "保存") { Task { await vm.saveRecord(context: viewContext) } }
                Card { Text("拍照后，AI 会自动识别食物并估计热量，你也可以手动编辑调整。").foregroundColor(.secondary) }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("今天的记录").font(.headline); Spacer(); Text("共 \(Int(vm.todayRecords.reduce(0){$0 + $1.items.reduce(0){$0 + $1.kcal}})) kcal").foregroundColor(.secondary) }
                        ForEach(vm.todayRecords) { rec in
                            HStack(alignment: .top) {
                                ZStack { Circle().fill(Color.orange.opacity(0.15)).frame(width: 36, height: 36); Image(systemName: "takeoutbag.and.cup.and.straw.fill").foregroundColor(.orange) }
                                VStack(alignment: .leading, spacing: 4) {
                                    mealTag(rec.mealType)
                                    Text(rec.items.map{ $0.name }.joined(separator: "、")).foregroundColor(.secondary)
                                    Text("\(Int(rec.items.reduce(0){$0 + $1.kcal})) kcal").foregroundColor(.green)
                                }
                                Spacer()
                                Text(timeString(rec.timestamp)).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("历史记录").font(.headline)
                            Spacer()
                            Chip(title: "近7天", selected: vm.historyRangeDays == 7) { vm.historyRangeDays = 7; vm.loadHistory(context: viewContext) }
                            Chip(title: "近30天", selected: vm.historyRangeDays == 30) { vm.historyRangeDays = 30; vm.loadHistory(context: viewContext) }
                            Chip(title: "近90天", selected: vm.historyRangeDays == 90) { vm.historyRangeDays = 90; vm.loadHistory(context: viewContext) }
                        }
                        VStack(spacing: 8) {
                            Picker("餐别", selection: $vm.mealFilter) {
                                Text("全部").tag(MealType?.none)
                                Text("早餐").tag(MealType?.some(.breakfast))
                                Text("午餐").tag(MealType?.some(.lunch))
                                Text("晚餐").tag(MealType?.some(.dinner))
                                Text("加餐").tag(MealType?.some(.snack))
                            }.pickerStyle(.segmented)
                            TextField("搜索食物名或备注", text: $vm.searchQuery).textFieldStyle(.roundedBorder)
                        }
                        if groups.isEmpty {
                            Text("暂无历史饮食记录").foregroundColor(.secondary).padding(.vertical, 16)
                        } else {
                            ForEach(groups, id: \.0) { day, records in
                                VStack(alignment: .leading, spacing: 10) {
                                    let total = records.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.kcal } }
                                    HStack { Text(chineseDay(day)).font(.subheadline).fontWeight(.semibold); Spacer(); Text("合计 \(Int(total)) kcal").foregroundColor(.secondary) }
                                    ForEach(records) { rec in
                                        HistoryRecordRow(rec: rec, onDelete: { vm.deleteRecord(context: viewContext, id: rec.id) })
                                            .onTapGesture { selectedRecord = rec }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                
            }.padding(16)
        }
        .onChange(of: vm.pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { vm.selectedImage = img }
            }
        }
        .onChange(of: vm.recordTime) { _, _ in vm.syncMealTypeWithRecordTime() }
        .task { vm.loadTodayRecords(context: viewContext) }
        .task { vm.loadHistory(context: viewContext) }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.dataDidChange)) { _ in
            vm.loadTodayRecords(context: viewContext)
            vm.loadHistory(context: viewContext)
        }
        .sheet(item: $selectedRecord) { rec in
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
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.dataDidChange)) { _ in vm.loadTodayRecords(context: viewContext) }
        .sheet(isPresented: $showCamera) { CameraPicker { img in vm.selectedImage = img } }
    }
}

private func label(for type: MealType) -> String {
    switch type { case .breakfast: return "早餐"; case .lunch: return "午餐"; case .dinner: return "晚餐"; case .snack: return "加餐" }
}
private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "HH:mm"; return f.string(from: date) }
private func dateTimeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 HH:mm"; return f.string(from: date) }
private func mealTag(_ type: MealType) -> some View {
    let text = label(for: type)
    let color: Color = {
        switch type { case .breakfast: return .yellow; case .lunch: return .orange; case .dinner: return .purple; case .snack: return .gray }
    }()
    return Text(text).font(.footnote).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(color.opacity(0.15))).foregroundColor(color)
}
private func chineseDay(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"; return f.string(from: date) }

struct HistoryRecordRow: View {
    let rec: DietRecordModel
    let onDelete: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let img = decodeImage(rec.imagePath) {
                Image(uiImage: img).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
            } else {
                ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)); Image(systemName: "fork.knife").foregroundColor(.orange) }.frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack { mealTag(rec.mealType); Spacer(); Text(timeString(rec.timestamp)).foregroundColor(.secondary) }
                Text(rec.items.map{ $0.name }.joined(separator: "、")).foregroundColor(.secondary)
                Text("\(Int(rec.items.reduce(0){$0 + $1.kcal})) kcal").foregroundColor(.green)
            }
            Spacer()
            Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red) }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
