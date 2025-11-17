import Foundation
import CoreData

final class BodyRepository {
    let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }
    func save(_ record: BodyRecordModel) throws {
        let br = NSEntityDescription.insertNewObject(forEntityName: "BodyRecord", into: context)
        br.setValue(record.id, forKey: "id")
        br.setValue(record.date, forKey: "date")
        br.setValue(record.weight, forKey: "weight")
        br.setValue(record.waist, forKey: "waist")
        try context.save()
    }
    func fetch(range: ClosedRange<Date>) throws -> [BodyRecordModel] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "BodyRecord")
        req.predicate = NSPredicate(format: "date >= %@ AND date <= %@", range.lowerBound as NSDate, range.upperBound as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let objs = try context.fetch(req)
        var list: [BodyRecordModel] = []
        for o in objs {
            let id = o.value(forKey: "id") as? UUID ?? UUID()
            let date = o.value(forKey: "date") as? Date ?? Date()
            let weight = o.value(forKey: "weight") as? Double
            let waist = o.value(forKey: "waist") as? Double
            list.append(BodyRecordModel(id: id, date: date, weight: weight, waist: waist))
        }
        return list
    }
}