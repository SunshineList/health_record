import Foundation
import CoreData

final class DietRepository {
    let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }
    func save(_ record: DietRecordModel) throws {
        let dr = NSEntityDescription.insertNewObject(forEntityName: "DietRecord", into: context)
        dr.setValue(record.id, forKey: "id")
        dr.setValue(record.timestamp, forKey: "timestamp")
        dr.setValue(Int16(record.mealType.rawValue), forKey: "mealType")
        dr.setValue(record.imagePath, forKey: "imagePath")
        dr.setValue(record.aiRawJSON, forKey: "aiRawJSON")
        dr.setValue(record.notes, forKey: "notes")
        var set = Set<NSManagedObject>()
        for it in record.items {
            let fi = NSEntityDescription.insertNewObject(forEntityName: "FoodItem", into: context)
            fi.setValue(it.id, forKey: "id")
            fi.setValue(it.name, forKey: "name")
            fi.setValue(it.weight, forKey: "weight")
            fi.setValue(it.kcal, forKey: "kcal")
            fi.setValue(it.protein, forKey: "protein")
            fi.setValue(it.fat, forKey: "fat")
            fi.setValue(it.carb, forKey: "carb")
            fi.setValue(dr, forKey: "dietRecord")
            set.insert(fi)
        }
        dr.setValue(set, forKey: "items")
        try context.save()
    }
    func fetch(range: ClosedRange<Date>) throws -> [DietRecordModel] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "DietRecord")
        req.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", range.lowerBound as NSDate, range.upperBound as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        let objs = try context.fetch(req)
        var list: [DietRecordModel] = []
        for o in objs {
            let id = o.value(forKey: "id") as? UUID ?? UUID()
            let ts = o.value(forKey: "timestamp") as? Date ?? Date()
            let mt = MealType(rawValue: Int(o.value(forKey: "mealType") as? Int16 ?? 0)) ?? .breakfast
            let ip = o.value(forKey: "imagePath") as? String
            let raw = o.value(forKey: "aiRawJSON") as? Data
            let notes = o.value(forKey: "notes") as? String ?? ""
            var items: [FoodItemModel] = []
            if let set = o.value(forKey: "items") as? NSSet {
                for e in set.allObjects {
                    if let mo = e as? NSManagedObject {
                        let fid = mo.value(forKey: "id") as? UUID ?? UUID()
                        let name = mo.value(forKey: "name") as? String ?? ""
                        let weight = mo.value(forKey: "weight") as? Double ?? 0
                        let kcal = mo.value(forKey: "kcal") as? Double ?? 0
                        let protein = mo.value(forKey: "protein") as? Double ?? 0
                        let fat = mo.value(forKey: "fat") as? Double ?? 0
                        let carb = mo.value(forKey: "carb") as? Double ?? 0
                        items.append(FoodItemModel(id: fid, name: name, weight: weight, kcal: kcal, protein: protein, fat: fat, carb: carb))
                    }
                }
            }
            list.append(DietRecordModel(id: id, timestamp: ts, mealType: mt, imagePath: ip, aiRawJSON: raw, notes: notes, items: items))
        }
        return list
    }
}