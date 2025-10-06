import SwiftUI
import Combine

// MARK: - Протоколы и Enum для Speedometer

protocol SpeedometerCalculator {
    func mapSpeedToInterval(_ speed: Double) -> Double
    func mapPercentToAngle(_ percent: Double) -> Double
    func numbersAndPoints(center: CGPoint, radius: CGFloat) -> [(number: Double, point: CGPoint)]
}

enum SpeedometerCalculatorBuilder {
    private static let megaBitNumbers: [Double] = [0, 1, 5, 10, 20, 50, 100, 200, 500]
    private static let megaByteNumbers: [Double] = [0, 1, 5, 10, 15, 20, 25, 30, 40, 50]
    
    static func build(by type: SpeedUnitType) -> SpeedometerCalculator {
        switch type {
        case .megabit:
            return SpeedometerCalculatorImpl(numbers: Self.megaBitNumbers)
        case .megabyte:
            return SpeedometerCalculatorImpl(numbers: Self.megaByteNumbers)
        }
    }
}

private final class SpeedometerCalculatorImpl: SpeedometerCalculator {
    
    private let numbers: [Double]
    
    init(numbers: [Double]) {
        self.numbers = numbers
    }
    
    private let workingAngle = (2 * Double.pi) - (Double.pi / 2)
    
    private lazy var divisionCount = numbers.count - 1
    private lazy var lengthStep: Double = 1 / Double(divisionCount)
    private lazy var angleStep: Double = workingAngle / Double(divisionCount)
    
    private lazy var speedIntervals: [Range<Double>] = {
        var out: [Range<Double>] = []
        for (index, number) in numbers.enumerated() {
            if index + 1 < numbers.count {
                out.append(number..<numbers[index + 1])
            }
        }
        return out
    }()
    
    private lazy var lengthIntervals: [Range<Double>: Range<Double>] = {
        var out: [Range<Double>: Range<Double>] = [:]
        for (index, speedInterval) in speedIntervals.enumerated() {
            let lengthInterval: Range<Double> = (lengthStep * Double(index))..<(lengthStep * Double(index + 1))
            out[speedInterval] = lengthInterval
        }
        return out
    }()
    
    private lazy var angles: [Double] = {
        var out: [Double] = []
        var angle = -Double.pi / 4
        for _ in numbers {
            out.append(angle)
            angle -= angleStep
        }
        return out
    }()
    
    func mapSpeedToInterval(_ speed: Double) -> Double {
        if let last = numbers.last, speed > last { return 1 }
        if let interval = lengthIntervals.first(where: { $0.key.contains(speed) }) {
            let keyShare = (speed - interval.key.lowerBound) / (interval.key.upperBound - interval.key.lowerBound)
            let valueShare = keyShare * (interval.value.upperBound - interval.value.lowerBound)
            return valueShare + interval.value.lowerBound
        }
        return 0
    }
    
    func mapPercentToAngle(_ percent: Double) -> Double {
        -((3 / 4) * Double.pi) + percent * workingAngle
    }
    
    func numbersAndPoints(center: CGPoint, radius: CGFloat) -> [(number: Double, point: CGPoint)] {
        var out: [(number: Double, point: CGPoint)] = []
        for (index, angle) in angles.enumerated() {
            out.append((
                number: numbers[index],
                point: CGPoint(
                    x: center.x + radius * sin(Double(angle)),
                    y: center.y + radius * cos(Double(angle))
                )
            ))
        }
        return out
    }
}
