import Foundation

struct MediaCacheBlurredData {
    let id: String
    let value: Bool
    let date: Date
    
    init(id: String, value: Bool, date: Date = Date()) {
        self.id = id
        self.value = value
        self.date = date
    }
}

struct MediaCacheDuplicateData {
    let id: String
    let value: Bool
    let equality: Double
    let date: Date
    
    init(id: String, value: Bool, equality: Double, date: Date = Date()) {
        self.id = id
        self.value = value
        self.equality = equality
        self.date = date
    }
}

struct MediaCacheSizeData {
    let id: String
    let value: Double
    let date: Date
    
    init(id: String, value: Double, date: Date = Date()) {
        self.id = id
        self.value = value
        self.date = date
    }
}
