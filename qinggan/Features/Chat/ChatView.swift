import SwiftUI

struct ChatView: View {
    @StateObject var vm = ChatViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showDrawer = false
    var body: some View {
        VStack(spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) { Image(systemName: "sparkles").foregroundColor(AppTheme.brand); Text("AI 健康教练").font(.headline); Spacer(); Button("会话") { showDrawer = true } }
                }
            }
            Card { Text("AI 教练仅提供生活方式建议，不提供医疗诊断。如有健康问题，请咨询专业医生。").font(.footnote).foregroundColor(.secondary) }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading) {
                        Button(action: { Task { await vm.loadMoreHistory(context: viewContext) } }) {
                            HStack(spacing: 6) { Image(systemName: "arrow.down.circle"); Text(vm.isLoadingHistory ? "加载中..." : "加载更多") }
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }.padding(.vertical, 8)
                        ForEach(vm.messages) { m in
                            BubbleMessageView(content: m.content, isMe: m.role == .user, timestamp: m.date)
                                .id(m.id)
                        }
                    }.padding(.horizontal, 12)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
                .onChange(of: vm.streamingTick) { _, _ in
                    if let last = vm.messages.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }
            HStack {
                Toggle("发送最近 7 天摘要", isOn: $vm.attachSummary).toggleStyle(.switch)
            }.padding(.horizontal, 16)
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble").foregroundColor(.secondary)
                    TextField("输入你的问题...", text: $vm.inputText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(vm.sending)
                    Spacer(minLength: 0)
                    if vm.sending { ProgressView() }
                    Button(action: { Task { await vm.send(context: viewContext) } }) { Image(systemName: "paperplane.fill").foregroundColor(.white).padding(10).background(Circle().fill(AppTheme.brand)) }
                        .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.sending)
                }
                .padding(10)
                .background(Capsule().fill(Color(.systemGray6)))
            }.padding(.horizontal, 16)
        }
        .task { await vm.loadHistory(context: viewContext) }
        .overlay(alignment: .leading) {
            if showDrawer {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea().onTapGesture { showDrawer = false }
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text("会话").font(.headline); Spacer(); Button("关闭") { showDrawer = false } }
                            HStack(spacing: 8) {
                                Button("新对话") { vm.newThread(context: viewContext) }
                                Button("全部清空") { vm.clearAll(context: viewContext) }
                            }
                            List {
                                ForEach(vm.threads) { th in
                                    Button(action: { vm.switchThread(context: viewContext, threadId: th.id); showDrawer = false }) {
                                        HStack { Text(timeLabel(th.lastDate)); if vm.currentThreadId == th.id { Image(systemName: "checkmark") } }
                                    }
                                }
                                .onDelete { idx in
                                    for i in idx { let th = vm.threads[i]; vm.deleteThread(context: viewContext, threadId: th.id) }
                                }
                            }.listStyle(.plain)
                        }
                        .frame(width: 280)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                        Spacer(minLength: 0)
                    }
                }
                .transition(.move(edge: .leading))
            }
        }
    }
}

private func timeLabel(_ d: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 HH:mm"; return f.string(from: d) }