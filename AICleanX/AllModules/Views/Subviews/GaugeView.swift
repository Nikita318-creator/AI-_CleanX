
import SwiftUI
import Combine

// MARK: - Компонент датчика скорости
// Твой GaugeView, который теперь получает данные извне.
// MARK: - Test Phase для изменения цветов
enum GaugePhase {
    case idle
    case findingServer
    case measuringLatency  
    case download
    case upload
    case completed
    
    var color: Color {
        switch self {
        case .idle, .findingServer, .measuringLatency, .completed:
            return CMColor.primaryLight
        case .download:
            return CMColor.primaryLight // Синий для загрузки
        case .upload:
            return Color.green // Зеленый для выгрузки
        }
    }
    
    var phaseText: String {
        switch self {
        case .idle:
            return "Tap to start"
        case .findingServer:
            return "Finding server..."
        case .measuringLatency:
            return "Measuring ping..."
        case .download:
            return "DOWNLOAD Mbps"
        case .upload:
            return "UPLOAD Mbps"
        case .completed:
            return "Test completed"
        }
    }
}

struct GaugeView: View {
    @Binding var speed: Double
    var phase: GaugePhase = .idle

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        ZStack {
            // Фон датчика
            Circle()
                .stroke(CMColor.backgroundSecondary, lineWidth: 10 * scalingFactor)
                .frame(width: 250 * scalingFactor, height: 250 * scalingFactor)
            
            // Динамическая заполняющаяся дуга
            Circle()
                .trim(from: 0.0, to: 0.0 + (speed / 100) * 0.75)
                .stroke(
                    phase.color,
                    style: StrokeStyle(lineWidth: 10 * scalingFactor, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: 250 * scalingFactor, height: 250 * scalingFactor)
                .animation(.easeInOut(duration: 1.5), value: speed)
                .animation(.easeInOut(duration: 0.8), value: phase.color)
            
            // Шкала
            ForEach(Array(stride(from: 0, to: 101, by: 5)), id: \.self) { tick in
                if [0, 5, 10, 15, 20, 30, 50, 75, 100].contains(tick) {
                    Text("\(tick)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(CMColor.tertiaryText)
                        .offset(y: -100 * scalingFactor) // Radius for numbers
                        .rotationEffect(.degrees(Double(tick) * 2.7)) // 270 degrees total range / 100
                        .rotationEffect(.degrees(-180)) // Сдвинули на 90 градусов по часовой стрелке (было -135)
                }
            }
            .frame(width: 250 * scalingFactor, height: 250 * scalingFactor)
            
            // Значение скорости и фаза теста
            VStack(spacing: 4 * scalingFactor) {
                Text("\(String(format: "%.2f", speed))")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                    
                Text(phase.phaseText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(phase == .upload ? Color.green : CMColor.tertiaryText)
                    .animation(.easeInOut(duration: 0.5), value: phase.phaseText)
            }
            .offset(y: 40 * scalingFactor) // Positive y offset to move it down

            // Индикатор-стрелка
            // Расчет угла поворота на основе speed
            let degrees = min(max(speed / 100, 0), 1) * 270
            let rotationAngle: Angle = Angle(degrees: -180 + degrees)
            
            Image("RectangleIndicator")
                .resizable()
                .scaledToFit()
                .frame(width: 85 * scalingFactor, height: 85 * scalingFactor)
                .offset(x: 0, y: -42.5 * scalingFactor)
                .rotationEffect(rotationAngle)
                .animation(.easeInOut(duration: 1.2), value: rotationAngle)
        }
    }
}
