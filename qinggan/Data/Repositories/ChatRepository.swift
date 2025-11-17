import Foundation
import CoreData

final class ChatRepository {
    let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }
    func save(_ message: AIMessage, threadId: UUID) throws {
        let cm = NSEntityDescription.insertNewObject(forEntityName: "ChatMessage", into: context)
        cm.setValue(message.id, forKey: "id")
        cm.setValue(message.date, forKey: "date")
        let role: Int16 = message.role == .system ? 0 : (message.role == .user ? 1 : 2)
        cm.setValue(role, forKey: "role")
        cm.setValue(message.content, forKey: "content")
        cm.setValue(threadId, forKey: "threadId")
        try context.save()
    }
    func fetchRecent(limit: Int, before: Date? = nil, threadId: UUID? = nil) throws -> [AIMessage] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ChatMessage")
        var preds: [NSPredicate] = []
        if let before { preds.append(NSPredicate(format: "date < %@", before as NSDate)) }
        if let tid = threadId { preds.append(NSPredicate(format: "threadId == %@", tid as CVarArg)) }
        if !preds.isEmpty { req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: preds) }
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        req.fetchLimit = limit
        let objs = try context.fetch(req)
        var list: [AIMessage] = []
        for o in objs {
            let id = o.value(forKey: "id") as? UUID ?? UUID()
            let date = o.value(forKey: "date") as? Date ?? Date()
            let roleInt = o.value(forKey: "role") as? Int16 ?? 2
            let role: AIMessageRole = roleInt == 0 ? .system : (roleInt == 1 ? .user : .assistant)
            let content = o.value(forKey: "content") as? String ?? ""
            list.append(AIMessage(id: id, role: role, content: content, date: date))
        }
        return list.sorted { $0.date < $1.date }
    }
    func threads() throws -> [ChatThread] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ChatMessage")
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let objs = try context.fetch(req)
        var map: [UUID: Date] = [:]
        for o in objs {
            let tid = (o.value(forKey: "threadId") as? UUID) ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
            let d = (o.value(forKey: "date") as? Date) ?? Date()
            if let cur = map[tid] { if d > cur { map[tid] = d } } else { map[tid] = d }
        }
        return map.keys.map { ChatThread(id: $0, lastDate: map[$0] ?? Date()) }.sorted { $0.lastDate > $1.lastDate }
    }
    func deleteThread(_ threadId: UUID) throws {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ChatMessage")
        req.predicate = NSPredicate(format: "threadId == %@", threadId as CVarArg)
        let objs = try context.fetch(req)
        for o in objs { context.delete(o) }
        try context.save()
    }
    func deleteAll() throws {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ChatMessage")
        let objs = try context.fetch(req)
        for o in objs { context.delete(o) }
        try context.save()
    }
    func updateMessage(id: UUID, newContent: String) throws {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ChatMessage")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let obj = try context.fetch(req).first {
            obj.setValue(newContent, forKey: "content")
            try context.save()
        }
    }
}