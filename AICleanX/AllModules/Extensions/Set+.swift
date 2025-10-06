import Foundation

extension Set where Element == AICleanServiceModel {

    var dateSections: [AICleanServiceSection] {
        makeDateSections(sortedByIndex)
    }

    var equalitySections: [AICleanServiceSection] {
        makeEqualitySections(sortedByEquality)
    }

    var similaritySections: [AICleanServiceSection] {
        makeSimilaritySections(sortedBySimilarity)
    }

    private var sortedByIndex: [Element] {
        sorted(by: { $0.index < $1.index })
    }

    private var sortedByEquality: [Element] {
        sorted(by: { $0.equality > $1.equality })
    }

    private var sortedBySimilarity: [Element] {
        sorted(by: { $0.similarity < $1.similarity })
    }

    private func makeDateSections(_ sorted: [AICleanServiceModel]) -> [AICleanServiceSection] {
        var out: [AICleanServiceSection] = []
        var models: [AICleanServiceModel] = []
        var prevDate = sorted.first(where: { $0.asset.creationDate != nil })?.asset.creationDate ??  Date(timeIntervalSince1970: 0)
        for (index, model) in sorted.enumerated() {
            if let curDate = model.asset.creationDate {
                if abs(prevDate.timeIntervalSince1970 - curDate.timeIntervalSince1970) > 86400 {
                    if !models.isEmpty {
                        out.append(.init(kind: .date(prevDate == Date(timeIntervalSince1970: 0) ? nil : prevDate), models: models))
                    }
                    models = []
                    prevDate = curDate
                }
            }
            models.append(model)
            if index == sorted.count - 1 && !models.isEmpty {
                out.append(.init(kind: .date(prevDate == Date(timeIntervalSince1970: 0) ? nil : prevDate), models: models))
            }
        }
        return out
    }

    private func makeEqualitySections(_ sorted: [AICleanServiceModel]) -> [AICleanServiceSection] {
        var out: [AICleanServiceSection] = []
        var models: [AICleanServiceModel] = []
        var prevProximity: Double = 0
        for (index, model) in sorted.enumerated() {
            if model.equality != prevProximity {
                if models.count > 1 {
                    out.append(.init(kind: .count, models: models))
                }
                models = []
                prevProximity = model.equality
            }
            models.append(model)
            if index == sorted.count - 1 && models.count > 1 {
                out.append(.init(kind: .count, models: models))
            }
        }
        return out
    }

    private func makeSimilaritySections(_ sorted: [AICleanServiceModel]) -> [AICleanServiceSection] {
        var out: [AICleanServiceSection] = []
        var models: [AICleanServiceModel] = []
        var prevProximity = Int.min
        for (index, model) in sorted.enumerated() {
            if model.similarity > prevProximity {
                if models.count > 1 {
                    out.append(.init(kind: .count, models: models))
                }
                models = []
                prevProximity = model.similarity
            }
            models.append(model)
            if index == sorted.count - 1 && models.count > 1 {
                out.append(.init(kind: .count, models: models))
            }
        }
        return out
    }
}
