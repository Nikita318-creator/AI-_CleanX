import Photos
import UIKit

struct AICleanServiceSection: Identifiable, Hashable {
    
    // 1. Kind должен быть Hashable
    enum Kind: Hashable {
        case count
        case date(Date?)
        case united(Date?)
    }
    
    let id = UUID() // Identifiable
    let kind: Kind
    var models: [AICleanServiceModel]

    // 2. Реализация Hashable
    // Поскольку все свойства (id, kind) являются Hashable,
    // нам не нужно писать тело func hash(into:), но мы можем явно это сделать.
    // Models исключаем из хэширования, так как их содержимое часто меняется,
    // и нам нужно, чтобы секция была стабильно идентифицируема.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(kind)
    }

    // 3. Реализация Equatable
    static func == (lhs: AICleanServiceSection, rhs: AICleanServiceSection) -> Bool {
        // Сравнение по ID является самым быстрым и надежным.
        return lhs.id == rhs.id
    }
}
