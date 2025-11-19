import SwiftUI
import CoreData

struct WeightListView: View {
    @StateObject var vm = WeightListViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showClearConfirm = false
    @State private var showEntry = false
    @State private var weightText: String = ""
    @State private var entryDate: Date = Date()
    @State private var editing: BodyRecordModel?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PrimaryButton(title: "记录体重") { showEntry = true }
                SecondaryButton(title: "清空全部") { showClearConfirm = true }
            }
            List {
                if vm.records.isEmpty {
                    HStack { Text("暂无体重记录").foregroundColor(.secondary); Spacer() }
                }
                ForEach(Array(vm.records.enumerated()), id: \.element.id) { idx, rec in
                    WeightRow(rec: rec)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = rec; weightText = String(format: "%.1f", rec.weight ?? 0); entryDate = rec.date; showEntry = true }
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { vm.delete(context: viewContext, id: rec.id) } label: { Label("删除", systemImage: "trash") } }
                    .onAppear { if idx == vm.records.count - 1 { vm.loadMore(context: viewContext) } }
                }
                if vm.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
            .environment(\.defaultMinListRowHeight, 64)
        }
        .alert("确认清空全部体重记录？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { vm.clearAll(context: viewContext) }
        } message: { Text("该操作不可恢复") }
        .sheet(isPresented: $showEntry, onDismiss: { editing = nil; weightText = "" }) {
            NavigationView {
                Form {
                    Section(header: Text(editing == nil ? "记录体重" : "编辑体重")) {
                        HStack { Text("体重(kg)"); TextField("72.5", text: $weightText).keyboardType(.decimalPad) }
                        DatePicker("日期", selection: $entryDate, displayedComponents: [.date])
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                    Section {
                        Button("保存") {
                            let repo = BodyRepository(context: viewContext)
                            if let e = editing {
                                var m = e
                                m.weight = Double(weightText)
                                m.date = entryDate
                                try? repo.update(m)
                            } else {
                                let rec = BodyRecordModel(date: entryDate, weight: Double(weightText), waist: nil)
                                try? repo.save(rec)
                            }
                            vm.load(context: viewContext)
                            showEntry = false
                        }
                    }
                }
                .navigationTitle(editing == nil ? "记录体重" : "编辑体重")
                .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("关闭") { showEntry = false } } }
            }
        }
        .onAppear { vm.loadInitialPaged(context: viewContext) }
    }
}

private func chineseDay(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"; return f.string(from: date) }
private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "HH:mm"; return f.string(from: date) }
struct WeightRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let rec: BodyRecordModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 10) {
                    Text(chineseDay(rec.date)).font(.headline).padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(AppTheme.brandLight))
                    Text(timeString(rec.date)).foregroundColor(.secondary).font(.subheadline)
                }
                Spacer()
                Text(rec.weight.map { String(format: "%.1f kg", $0) } ?? "-").font(.title2).fontWeight(.bold).foregroundColor(AppTheme.brandDark)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.gray.opacity(0.1)))
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.02), radius: colorScheme == .dark ? 2 : 3, x: 0, y: colorScheme == .dark ? 1 : 2)
    }
}