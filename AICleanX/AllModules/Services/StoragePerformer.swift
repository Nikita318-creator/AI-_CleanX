import CoreData
import os.log

final class StoragePerformer {
    enum CustomError: Error {
        case noContext
        case entityNotFound
    }

    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "StoragePerformer")
    private let queue = DispatchQueue(label: "StoragePerformerQueue", qos: .userInitiated)
    private let persistentContainer: NSPersistentContainer

    init(persistentContainer: NSPersistentContainer = PersistenceController.shared.container) {
        self.persistentContainer = persistentContainer
    }

    func addBlurredCache(_ data: [MediaCacheBlurredData], completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    for (index, item) in data.enumerated() {
                        let entity = MediaCacheBlurredEntity(context: context)
                        entity.id = item.id
                        entity.value = item.value
                        entity.date = item.date
                        print("   \(index + 1). Created entity for ID: \(item.id), value: \(item.value)")
                    }
                    
                    try context.save()
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }
    
    func addDuplicateCache(_ data: [MediaCacheDuplicateData], completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    for item in data {
                        let entity = MediaCacheDuplicateEntity(context: context)
                        entity.id = item.id
                        entity.value = item.value
                        entity.equality = item.equality
                        entity.date = item.date
                    }
                    
                    try context.save()
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }
    
    func addSizeCache(_ data: [MediaCacheSizeData], completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    for item in data {
                        let entity = MediaCacheSizeEntity(context: context)
                        entity.id = item.id
                        entity.value = item.value
                        entity.date = item.date
                    }
                    
                    try context.save()
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }

    func delete<Element: NSManagedObject>(_ object: Element, completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    let objectInContext = try context.existingObject(with: object.objectID)
                    context.delete(objectInContext)
                    
                    try context.save()
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }

    func delete<Element: NSManagedObject>(objects: [Element], completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    for object in objects {
                        let objectInContext = try context.existingObject(with: object.objectID)
                        context.delete(objectInContext)
                    }
                    
                    try context.save()
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }

    func deleteObjects<Element: NSManagedObject>(of type: Element.Type, completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    let entityName = String(describing: type)
                    let fetchRequest = NSFetchRequest<Element>(entityName: entityName)
                    let objects = try context.fetch(fetchRequest)
                    
                    for object in objects {
                        context.delete(object)
                    }
                    
                    try context.save()
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }

    func get<Element: NSManagedObject>(_ type: Element.Type, completion: @escaping ([Element]?) -> Void) {
        let entityName = String(describing: type)
        
        queue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            let context = self.persistentContainer.viewContext
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<Element>(entityName: entityName)
                    let objects = try context.fetch(fetchRequest)
                    completion(objects)
                } catch {
                    completion(nil)
                }
            }
        }
    }

    func get<Element: NSManagedObject>(_ type: Element.Type, id: String, completion: @escaping (Element?) -> Void) {
        let entityName = String(describing: type)
        
        queue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            let context = self.persistentContainer.viewContext
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<Element>(entityName: entityName)
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id)
                    fetchRequest.fetchLimit = 1
                    let objects = try context.fetch(fetchRequest)
                    completion(objects.first)
                } catch {
                    completion(nil)
                }
            }
        }
    }
}

