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
                        HStack {
                            Text("识别结果").font(.headline)
                            if vm.isRecognizing {
                                Spacer()
                                HStack(spacing: 6) { ProgressView(); Text("识别中...").foregroundColor(.secondary) }
                            } else {
                                Spacer()
                                Text("共 \(vm.recognizedTotalKcal) kcal").foregroundColor(.secondary)
                            }
                        }
                        if let err = vm.recognitionError { Text(err).foregroundColor(.red) }
                        VStack(alignment: .leading, spacing: 14) {
                            if vm.recognizedItems.isEmpty { Text("暂无食物，点击下方‘添加食物’或重新识别").foregroundColor(.secondary) }
                            ForEach($vm.recognizedItems) { $item in
                                Card { FoodItemEditor(item: $item) { vm.recognizedItems.removeAll(where: { $0.id == item.id }) } .environmentObject(vm) }
                            }
                        }
                        HStack(spacing: 12) {
                            SecondaryButton(title: "添加食物") { vm.recognizedItems.append(FoodItemModel(name: "", weight: 0, kcal: 0, protein: 0, fat: 0, carb: 0)) }
                            SecondaryButton(title: "清空识别") { vm.recognizedItems.removeAll(); vm.recognitionError = nil; vm.selectedImage = nil; vm.aiRawJSON = nil }
                            PrimaryButton(title: vm.isRecognizing ? "识别中..." : "重试识别") { Task { await vm.runRecognition() } }
                                .disabled(vm.isRecognizing)
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
                        let totalsToday = macroTotals(vm.todayRecords)
                        HStack {
                            Text("今天的记录").font(.headline)
                            Spacer()
                            Text("共 \(totalsToday.kcal) kcal · 蛋白 \(totalsToday.protein)g · 脂肪 \(totalsToday.fat)g · 碳水 \(totalsToday.carb)g").foregroundColor(.secondary)
                        }
                        let groupsToday = vm.mealGroups(for: vm.todayRecords)
                        ForEach(groupsToday, id: \.0) { mt, arr in
                            HStack(alignment: .center) {
                                mealTag(mt)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(arr.map{ $0.items.map{$0.name}.joined(separator: "、") }.joined(separator: "，")).lineLimit(1).foregroundColor(.secondary)
                                    let totals = macroTotals(arr)
                                    Text("共 \(totals.kcal) kcal · 蛋白 \(totals.protein)g · 脂肪 \(totals.fat)g · 碳水 \(totals.carb)g").foregroundColor(.green)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        // HStack(spacing: 8) {
                        //     Text("历史记录").font(.headline)
                        //     Spacer()
                        //     Chip(title: "近7天", selected: vm.historyRangeDays == 7) { vm.historyRangeDays = 7; vm.loadHistory(context: viewContext) }
                        //     Chip(title: "近30天", selected: vm.historyRangeDays == 30) { vm.historyRangeDays = 30; vm.loadHistory(context: viewContext) }
                        //     Chip(title: "近90天", selected: vm.historyRangeDays == 90) { vm.historyRangeDays = 90; vm.loadHistory(context: viewContext) }
                        // }
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
                        let pagedGroups = vm.historyGroups
                        HStack(spacing: 8) {
                            Chip(title: "近7天", selected: vm.searchDays == 7) { vm.searchDays = 7 }
                            Chip(title: "近30天", selected: vm.searchDays == 30) { vm.searchDays = 30 }
                            Chip(title: "近90天", selected: vm.searchDays == 90) { vm.searchDays = 90 }
                        }
                        .padding(.bottom, 4)
                        if pagedGroups.isEmpty {
                            Text("暂无历史饮食记录").foregroundColor(.secondary).padding(.vertical, 16)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(pagedGroups, id: \.0) { day, records in
                                    let totalsDay = macroTotals(records)
                                    HStack {
                                        Text(chineseDay(day)).font(.subheadline).fontWeight(.semibold)
                                        Spacer()
                                        Text("合计 \(totalsDay.kcal) kcal · 蛋白 \(totalsDay.protein)g · 脂肪 \(totalsDay.fat)g · 碳水 \(totalsDay.carb)g").foregroundColor(.secondary)
                                    }
                                    VStack(spacing: 6) {
                                        ForEach(MealType.allCases, id: \.self) { mt in
                                            let arr = records.filter { $0.mealType == mt }.sorted { $0.timestamp < $1.timestamp }
                                            if !arr.isEmpty {
                                                DisclosureGroup {
                                                    VStack(spacing: 4) {
                                                        ForEach(arr) { rec in
                                                            HistoryRecordRow(rec: rec, onDelete: { vm.deleteRecord(context: viewContext, id: rec.id) })
                                                                .onTapGesture { selectedRecord = rec }
                                                        }
                                                    }
                                                } label: {
                                                    HStack(alignment: .center, spacing: 8) {
                                                        mealTag(mt)
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(mealNamesLine(arr)).lineLimit(1).foregroundColor(.secondary)
                                                            let totals = macroTotals(arr)
                                                            Text("共 \(totals.kcal) kcal · 蛋白 \(totals.protein)g · 脂肪 \(totals.fat)g · 碳水 \(totals.carb)g").foregroundColor(.green).font(.caption)
                                                        }
                                                        Spacer()
                                                    }
                                                    .padding(.vertical, 6)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                                HStack {
                                    Spacer()
                                    Button(action: { vm.loadHistoryMore(context: viewContext) }) { Text(vm.historyLoading ? "加载中..." : (vm.historyHasMore ? "加载更多" : "没有更多了")) }
                                    Spacer()
                                }
                            }
                            .animation(nil, value: vm.historyPaged.count)
                            .transaction { $0.disablesAnimations = true }
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
        .task { vm.loadHistoryInitial(context: viewContext) }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.dataDidChange)) { _ in
            vm.loadTodayRecords(context: viewContext)
            vm.loadHistoryInitial(context: viewContext)
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
// 之前的历史列表风格：按日期分组后平铺每条记录
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
private func mealNamesLine(_ records: [DietRecordModel]) -> String {
    var parts: [String] = []
    for r in records {
        let names = r.items.map { $0.name }.joined(separator: "、")
        if !names.isEmpty { parts.append(names) }
    }
    return parts.joined(separator: "，")
}
private func macroTotals(_ records: [DietRecordModel]) -> (kcal: Int, protein: Int, fat: Int, carb: Int) {
    var kcal = 0, protein = 0, fat = 0, carb = 0
    for r in records {
        for it in r.items {
            kcal += Int(it.kcal)
            protein += Int(it.protein)
            fat += Int(it.fat)
            carb += Int(it.carb)
        }
    }
    return (kcal, protein, fat, carb)
}
private func dayTotalKcal(_ records: [DietRecordModel]) -> Int {
    var sum = 0
    for r in records { for it in r.items { sum += Int(it.kcal) } }
    return sum
}
