import Foundation
import CoreData
import Combine

@MainActor final class ChatViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var threads: [ChatThread] = []
    @Published var currentThreadId: UUID = UUID()
    @Published var inputText: String = ""
    @Published var attachSummary: Bool = false
    @Published var sending: Bool = false
    @Published var isLoadingHistory: Bool = false
    private var oldestDate: Date?
    private let healthKit = HealthKitService()
    func loadHistory(context: NSManagedObjectContext) async {
        let repo = ChatRepository(context: context)
        if let ts = try? repo.threads(), !ts.isEmpty { threads = ts; currentThreadId = ts.first!.id }
        if let msgs = try? repo.fetchRecent(limit: 50, before: nil, threadId: currentThreadId) {
            messages = msgs
            oldestDate = messages.first?.date
        }
    }
    func loadMoreHistory(context: NSManagedObjectContext) async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        let repo = ChatRepository(context: context)
        if let before = oldestDate, let older = try? repo.fetchRecent(limit: 50, before: before, threadId: currentThreadId), !older.isEmpty {
            messages.insert(contentsOf: older, at: 0)
            oldestDate = messages.first?.date
        }
    }
    func newThread(context: NSManagedObjectContext) {
        currentThreadId = UUID()
        messages = []
        oldestDate = nil
        threads.insert(ChatThread(id: currentThreadId, lastDate: Date()), at: 0)
    }
    func clearCurrentThread(context: NSManagedObjectContext) {
        let repo = ChatRepository(context: context)
        if let _ = try? repo.deleteThread(currentThreadId) { messages = []; oldestDate = nil }
    }
    func deleteThread(context: NSManagedObjectContext, threadId: UUID) {
        let repo = ChatRepository(context: context)
        if let _ = try? repo.deleteThread(threadId) {
            threads.removeAll { $0.id == threadId }
            if currentThreadId == threadId { currentThreadId = threads.first?.id ?? UUID(); messages = []; oldestDate = nil }
        }
    }
    func clearAll(context: NSManagedObjectContext) {
        let repo = ChatRepository(context: context)
        if let _ = try? repo.deleteAll() {
            threads = []
            messages = []
            oldestDate = nil
            currentThreadId = UUID()
        }
    }
    func switchThread(context: NSManagedObjectContext, threadId: UUID) {
        currentThreadId = threadId
        Task { await loadHistory(context: context) }
    }
    func buildSummary(context: NSManagedObjectContext) async -> HealthSummary {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        let dietRepo = DietRepository(context: context)
        var totalKcal: Double = 0
        if let records = try? dietRepo.fetch(range: start...end) {
            totalKcal = records.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.kcal } }
        }
        var avgSteps = 0
        do {
            try await healthKit.requestAuthorization()
            let steps = try await healthKit.steps(last: 7)
            if !steps.isEmpty { avgSteps = steps.map { $0.steps }.reduce(0, +) / steps.count }
        } catch {}
        let bodyRepo = BodyRepository(context: context)
        var avgWeight: Double?
        var avgWaist: Double?
        if let bodies = try? bodyRepo.fetch(range: start...end) {
            let weights = bodies.compactMap { $0.weight }
            let waists = bodies.compactMap { $0.waist }
            if !weights.isEmpty { avgWeight = weights.reduce(0, +) / Double(weights.count) }
            if !waists.isEmpty { avgWaist = waists.reduce(0, +) / Double(waists.count) }
        }
        return HealthSummary(totalKcal: totalKcal, avgSteps: avgSteps, avgWeight: avgWeight, avgWaist: avgWaist)
    }
    func send(context: NSManagedObjectContext) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || sending { return }
        let cfg = ConfigStore.shared.load()
        let client = AIClient(host: cfg.host)
        let userMsg = AIMessage(role: .user, content: trimmed, date: Date())
        messages.append(userMsg)
        if let _ = try? ChatRepository(context: context).save(userMsg, threadId: currentThreadId) {}
        sending = true
        let summary = attachSummary ? await buildSummary(context: context) : nil
        if let resp = try? await client.sendChat(messages: messages, summary: summary, config: cfg) {
            var reply = AIMessage(role: .assistant, content: "", date: Date())
            messages.append(reply)
            if let _ = try? ChatRepository(context: context).save(reply, threadId: currentThreadId) {}
            let id = reply.id
            for ch in resp.text {
                if let lastIndex = messages.indices.last { messages[lastIndex].content.append(ch) }
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            try? ChatRepository(context: context).updateMessage(id: id, newContent: messages.last?.content ?? resp.text)
        }
        sending = false
        inputText = ""
    }
}
