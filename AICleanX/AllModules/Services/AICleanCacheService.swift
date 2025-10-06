import Combine
import CoreData
import Foundation

final class AICleanCacheService {
    static let shared = AICleanCacheService(storageManager: StoragePerformer())
    
    private let storageManager: StoragePerformer

    private let blurredCacheLock = NSLock()
    private let duplicateCacheLock = NSLock()
    private let sizeCacheLock = NSLock()

    private var blurredCache: [String: Bool] = [:]
    private var duplicateCache: [String: (Bool, Double)] = [:]
    private var sizeCache: [String: Double] = [:]

    private let saveBlurredSubject = PassthroughSubject<Void, Never>()
    private let saveDuplicatesSubject = PassthroughSubject<Void, Never>()
    private let saveSizesSubject = PassthroughSubject<Void, Never>()

    private var subscriptions = Set<AnyCancellable>()
    
    private var isSavingBlurred = false
    private var isSavingDuplicates = false
    private var isSavingSizes = false

    init(storageManager: StoragePerformer) {
        self.storageManager = storageManager

        self.loadBlurredCache()
        self.loadDuplicatesCache()
        self.loadSizesCache()

        self.setupSavePipelines()
    }

    // MARK: Public Accessors

    func getBlurred(id: String) -> Bool? {
        blurredCacheLock.lock()
        defer { blurredCacheLock.unlock() }
        return blurredCache[id]
    }

    func getDuplicate(id: String) -> (Bool, Double)? {
        duplicateCacheLock.lock()
        defer { duplicateCacheLock.unlock() }
        return duplicateCache[id]
    }

    func getSize(id: String) -> Double? {
        sizeCacheLock.lock()
        defer { sizeCacheLock.unlock() }
        return sizeCache[id]
    }
    
    func getSwipeDecision(id: String) -> Bool? {
        let swipeId = "swipe_\(id)"
        blurredCacheLock.lock()
        defer { blurredCacheLock.unlock() }
        return blurredCache[swipeId]
    }
    
    func getTotalSwipeDecisionsForDeletion() -> Int {
        blurredCacheLock.lock()
        defer { blurredCacheLock.unlock() }
        return blurredCache.compactMap { (key, value) -> Bool? in
            guard key.hasPrefix("swipe_") else { return nil }
            return value == false ? true : nil
        }.count
    }

    // MARK: Mutators

    func setBlurred(id: String, value: Bool) {
        blurredCacheLock.lock()
        defer { blurredCacheLock.unlock() }
        if blurredCache[id] != value {
            blurredCache[id] = value
            saveBlurredSubject.send(())
        }
    }

    func setDuplicate(id: String, value: Bool, equality: Double) {
        duplicateCacheLock.lock()
        defer { duplicateCacheLock.unlock() }
        let existingTuple = duplicateCache[id]
        let newTuple = (value, equality)
        if existingTuple?.0 != newTuple.0 || existingTuple?.1 != newTuple.1 {
            duplicateCache[id] = newTuple
            saveDuplicatesSubject.send(())
        }
    }

    func setSize(id: String, value: Double) {
        sizeCacheLock.lock()
        defer { sizeCacheLock.unlock() }
        if sizeCache[id] != value {
            sizeCache[id] = value
            saveSizesSubject.send(())
        }
    }
    
    func setSwipeDecision(id: String, ignored: Bool) {
        let swipeId = "swipe_\(id)"
        blurredCacheLock.lock()
        if blurredCache[swipeId] != ignored {
            blurredCache[swipeId] = ignored
            blurredCacheLock.unlock()
            saveSwipeDecision(id: swipeId, ignored: ignored)
        } else {
            blurredCacheLock.unlock()
        }
    }

    // MARK: Deletion

    func deleteBlurred(id: String) {
        storageManager.get(MediaCacheBlurredEntity.self, id: id) { [weak self] object in
            guard let self = self, let object = object else { return }
            self.storageManager.delete(object) { [weak self] error in
                guard let self = self else { return }
                if error == nil {
                    self.deleteSize(id: id)
                    self.blurredCacheLock.lock()
                    self.blurredCache[id] = nil
                    self.blurredCacheLock.unlock()
                }
            }
        }
    }

    func deleteSize(id: String) {
        storageManager.get(MediaCacheSizeEntity.self, id: id) { [weak self] object in
            guard let self = self, let object = object else { return }
            self.storageManager.delete(object) { [weak self] error in
                guard let self = self else { return }
                if error == nil {
                    self.sizeCacheLock.lock()
                    self.sizeCache[id] = nil
                    self.sizeCacheLock.unlock()
                }
            }
        }
    }

    func deleteDuplicate(id: String) {
        storageManager.get(MediaCacheDuplicateEntity.self, id: id) { [weak self] object in
            guard let self = self, let object = object else { return }
            self.storageManager.delete(object) { [weak self] error in
                guard let self = self else { return }
                if error == nil {
                    self.deleteSize(id: id)
                    self.duplicateCacheLock.lock()
                    self.duplicateCache[id] = nil
                    self.duplicateCacheLock.unlock()
                }
            }
        }
    }

    func deleteSwipeDecision(id: String) {
        let swipeId = "swipe_\(id)"
        storageManager.get(MediaCacheBlurredEntity.self, id: swipeId) { [weak self] object in
            guard let self = self, let object = object else { return }
            self.storageManager.delete(object) { [weak self] error in
                guard let self = self else { return }
                if error == nil {
                    self.blurredCacheLock.lock()
                    self.blurredCache[swipeId] = nil
                    self.blurredCacheLock.unlock()
                }
            }
        }
    }

    func deleteAllDuplicates() {
        storageManager.deleteObjects(of: MediaCacheDuplicateEntity.self) { [weak self] error in
            guard let self = self else { return }
            if error == nil {
                self.duplicateCacheLock.lock()
                self.duplicateCache = [:]
                self.duplicateCacheLock.unlock()
            }
        }
    }

    // MARK: Private Helpers

    private func setupSavePipelines() {
        saveBlurredSubject
            .throttle(for: .seconds(18), scheduler: DispatchQueue.main, latest: true)
            .delay(for: .seconds(6), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveBlurredCache()
            }
            .store(in: &subscriptions)

        saveDuplicatesSubject
            .throttle(for: .seconds(18), scheduler: DispatchQueue.main, latest: true)
            .delay(for: .seconds(12), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveDuplicatesCache()
            }
            .store(in: &subscriptions)

        saveSizesSubject
            .throttle(for: .seconds(18), scheduler: DispatchQueue.main, latest: true)
            .delay(for: .seconds(18), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveSizesCache()
            }
            .store(in: &subscriptions)
    }

    private func saveBlurredCache() {
        if isSavingBlurred { return }
        isSavingBlurred = true
        blurredCacheLock.lock()
        let cacheCopy = blurredCache
        blurredCacheLock.unlock()
        defer { self.isSavingBlurred = false }
        guard !cacheCopy.isEmpty else { return }

        storageManager.get(MediaCacheBlurredEntity.self) { [weak self] result in
            guard let self = self else { return }
            let existingIds = Set(result?.compactMap { $0.id } ?? [])
            let itemsToWrite = cacheCopy.filter { !existingIds.contains($0.key) }
            guard !itemsToWrite.isEmpty else { return }

            let data = itemsToWrite.map { (id, value) in
                MediaCacheBlurredData(id: id, value: value)
            }
            self.storageManager.addBlurredCache(data) { _ in }
        }
    }

    private func saveDuplicatesCache() {
        if isSavingDuplicates { return }
        isSavingDuplicates = true
        duplicateCacheLock.lock()
        let cacheCopy = duplicateCache
        duplicateCacheLock.unlock()
        defer { self.isSavingDuplicates = false }
        guard !cacheCopy.isEmpty else { return }

        storageManager.get(MediaCacheDuplicateEntity.self) { [weak self] result in
            guard let self = self else { return }
            let existingIds = Set(result?.compactMap { $0.id } ?? [])
            let itemsToWrite = cacheCopy.filter { !existingIds.contains($0.key) }
            guard !itemsToWrite.isEmpty else { return }

            let data = itemsToWrite.map { (id, tuple) in
                MediaCacheDuplicateData(id: id, value: tuple.0, equality: tuple.1)
            }
            self.storageManager.addDuplicateCache(data) { _ in }
        }
    }

    private func saveSizesCache() {
        if isSavingSizes { return }
        isSavingSizes = true
        sizeCacheLock.lock()
        let cacheCopy = sizeCache
        sizeCacheLock.unlock()
        defer { self.isSavingSizes = false }
        guard !cacheCopy.isEmpty else { return }

        storageManager.get(MediaCacheSizeEntity.self) { [weak self] result in
            guard let self = self else { return }
            let existingIds = Set(result?.compactMap { $0.id } ?? [])
            let itemsToWrite = cacheCopy.filter { !existingIds.contains($0.key) }
            guard !itemsToWrite.isEmpty else { return }

            let data = itemsToWrite.map { (id, value) in
                MediaCacheSizeData(id: id, value: value)
            }
            self.storageManager.addSizeCache(data) { _ in }
        }
    }
    
    private func saveSwipeDecision(id: String, ignored: Bool) {
        storageManager.get(MediaCacheBlurredEntity.self, id: id) { [weak self] existingObject in
            guard let self = self else { return }
            if let existingObject = existingObject {
                self.storageManager.delete(existingObject) { [weak self] error in
                    guard let self = self else { return }
                    if error == nil {
                        self.blurredCacheLock.lock()
                        self.blurredCache[id] = nil
                        self.blurredCacheLock.unlock()
                        self.createSwipeDecision(id: id, ignored: ignored)
                    }
                }
            } else {
                self.createSwipeDecision(id: id, ignored: ignored)
            }
        }
    }
    
    private func createSwipeDecision(id: String, ignored: Bool) {
        let cacheData = [MediaCacheBlurredData(id: id, value: ignored)]
        storageManager.addBlurredCache(cacheData) { [weak self] error in
            if error == nil {
                self?.blurredCacheLock.lock()
                self?.blurredCache[id] = ignored
                self?.blurredCacheLock.unlock()
            }
        }
    }

    // MARK: Cache Loading

    private func loadBlurredCache() {
        storageManager.get(MediaCacheBlurredEntity.self) { [weak self] result in
            guard let self = self, let entities = result else { return }
            let oneMonthAgo = Date().timeIntervalSince1970 - TimeInterval.month
            let (toDelete, toKeep) = entities.reduce(into: ([MediaCacheBlurredEntity](), [MediaCacheBlurredEntity]())) { (result, entity) in
                if entity.date?.timeIntervalSince1970 ?? 0 < oneMonthAgo {
                    result.0.append(entity)
                } else {
                    result.1.append(entity)
                }
            }

            if !toDelete.isEmpty {
                self.storageManager.delete(objects: toDelete) { _ in }
            }
            
            self.blurredCacheLock.lock()
            toKeep.forEach {
                if let id = $0.id { self.blurredCache[id] = $0.value }
            }
            self.blurredCacheLock.unlock()
        }
    }

    private func loadDuplicatesCache() {
        storageManager.get(MediaCacheDuplicateEntity.self) { [weak self] result in
            guard let self = self, let entities = result else { return }
            self.duplicateCacheLock.lock()
            entities.forEach {
                if let id = $0.id { self.duplicateCache[id] = ($0.value, $0.equality) }
            }
            self.duplicateCacheLock.unlock()
        }
    }

    private func loadSizesCache() {
        storageManager.get(MediaCacheSizeEntity.self) { [weak self] result in
            guard let self = self, let entities = result else { return }
            let oneMonthAgo = Date().timeIntervalSince1970 - TimeInterval.month
            let (toDelete, toKeep) = entities.reduce(into: ([MediaCacheSizeEntity](), [MediaCacheSizeEntity]())) { (result, entity) in
                if entity.date?.timeIntervalSince1970 ?? 0 < oneMonthAgo {
                    result.0.append(entity)
                } else {
                    result.1.append(entity)
                }
            }
            
            if !toDelete.isEmpty {
                self.storageManager.delete(objects: toDelete) { _ in }
            }
            
            self.sizeCacheLock.lock()
            toKeep.forEach {
                if let id = $0.id { self.sizeCache[id] = $0.value }
            }
            self.sizeCacheLock.unlock()
        }
    }

    private func cleanAllBlurred() {
        storageManager.deleteObjects(of: MediaCacheBlurredEntity.self) { [weak self] error in
            guard let self = self, error == nil else { return }
            self.blurredCacheLock.lock()
            self.blurredCache = [:]
            self.blurredCacheLock.unlock()
        }
    }
}
