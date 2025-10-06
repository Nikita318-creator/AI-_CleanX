import SwiftUI
import Foundation

struct SpeedTestView: View {
    @StateObject private var speedometerViewModel = SpeedometerViewModel()
    @Binding var isPaywallPresented: Bool

    @State private var graphDrawProgress: CGFloat = 0.0

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    // В этом свойстве заменены системные цвета статуса
    private var gaugeFillColor: Color {
        let speed = speedometerViewModel.speed
        if speed < 10 {
            // .orange заменен на CMColor.warning
            return CMColor.warning
        } else if speed < 50 {
            // .cyan заменен на CMColor.primaryLight (или другой подходящий "средний" цвет, например, CMColor.secondary)
            return CMColor.secondary
        } else {
            // .green заменен на CMColor.success
            return CMColor.success
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                speedtestHeaderSection
                
                // Переделанная карточка с датчиком скорости
                newSpeedtestGaugeCard
                
                // Переделанная карточка с информацией о соединении и сервере
                newSpeedtestInfoCard
                
                // Обновленный график
                speedtestGraph
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.bottom, 100 * scalingFactor)
            .onAppear {
                self.graphDrawProgress = 0.0
                withAnimation(.easeInOut(duration: 1.5)) {
                    self.graphDrawProgress = 1.0
                }
                
                speedometerViewModel.updateIP()
            }
        }
        // .background(Color.white.ignoresSafeArea()) заменен на CMColor.background
        .background(CMColor.background.ignoresSafeArea())
    }
    
    // MARK: - Секция заголовка для Speedtest
    private var speedtestHeaderSection: some View {
        HStack {
            Text("Speedtest")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            // todo PRO
//            ProBadgeView(isPaywallPresented: $isPaywallPresented)
        }
        .padding(.top, 20 * scalingFactor)
    }
    
    // MARK: - Переделанный датчик скорости и результаты
    private var newSpeedtestGaugeCard: some View {
        VStack(spacing: 24 * scalingFactor) {
            // Центральный датчик
            ZStack {
                // Фоновая серая дуга
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .opacity(0.1)
                    .rotationEffect(.degrees(135))
                    .frame(width: 250 * scalingFactor, height: 250 * scalingFactor)
                    // .foregroundColor(.gray) заменен на CMColor.secondaryText
                    .foregroundColor(CMColor.secondaryText)

                // Заполняющаяся цветная дуга
                Circle()
                    .trim(from: 0.0, to: CGFloat(speedometerViewModel.speed / 100) * 0.75)
                    .stroke(gaugeFillColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: 250 * scalingFactor, height: 250 * scalingFactor)
                    .animation(.spring(), value: speedometerViewModel.speed)
                
                VStack(spacing: 8) {
                    Text(String(format: "%.1f", speedometerViewModel.speed))
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    Text("Mbps")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            .frame(width: 300, height: 300)
            
            // Информация о текущей фазе
            VStack(spacing: 4 * scalingFactor) {
                Text(speedometerViewModel.testPhase.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
                
                // Результаты теста
                HStack(spacing: 24) {
                    // Загрузка
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(CMColor.primaryLight)
                            Text("Download")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(CMColor.primaryText)
                        }
                        Text("\(String(format: "%.1f", speedometerViewModel.finalDownloadSpeed)) Mbps")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(CMColor.primaryText)
                    }
                    
                    // Выгрузка
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(CMColor.success)
                            Text("Upload")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(CMColor.primaryText)
                        }
                        Text("\(String(format: "%.1f", speedometerViewModel.finalUploadSpeed)) Mbps")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(CMColor.primaryText)
                    }
                }
            }
            .padding(.top, 16 * scalingFactor)
            
            // Кнопки действий
            if !speedometerViewModel.isTestInProgress && speedometerViewModel.testPhase == .idle {
                Button(action: {
                    speedometerViewModel.startRealSpeedTest()
                }) {
                    Text("Start Test")
                        .font(.system(size: 18, weight: .bold))
                        // .foregroundColor(.white) заменен на CMColor.white
                        .foregroundColor(CMColor.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(CMColor.primary)
                        .cornerRadius(16)
                }
            } else if speedometerViewModel.testPhase == .completed {
                Button(action: {
                    speedometerViewModel.resetTestData()
                }) {
                    Text("Test Again")
                        .font(.system(size: 18, weight: .bold))
                        // .foregroundColor(.white) заменен на CMColor.white
                        .foregroundColor(CMColor.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(CMColor.primary)
                        .cornerRadius(16)
                }
            } else if speedometerViewModel.isTestInProgress {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(CMColor.primary)
                    .padding()
            }
        }
        .padding(24 * scalingFactor)
        .background(CMColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24 * scalingFactor))
        // .shadow(color: CMColor.primary.opacity(0.08)...) оставлена ваша кастомная тень
        .shadow(color: CMColor.primary.opacity(0.08), radius: 16, x: 0, y: 16)
    }
    
    // MARK: - Переделанная карточка с информацией
    private var newSpeedtestInfoCard: some View {
        HStack(alignment: .top, spacing: 16 * scalingFactor) {
            // Карточка с информацией о соединении
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "network")
                        .font(.system(size: 24))
                        .foregroundColor(CMColor.primaryLight)
                    Text("Connection")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                }
                Text(getConnectionType())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CMColor.tertiaryText)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(CMColor.surface)
            .cornerRadius(16 * scalingFactor)
            .shadow(color: CMColor.primary.opacity(0.08), radius: 8, x: 0, y: 4)
            
            // Карточка с информацией о сервере
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 24))
                        .foregroundColor(CMColor.primaryLight)
                    Text("Server")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                }
                Text(speedometerViewModel.serverInfo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CMColor.tertiaryText)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(CMColor.surface)
            .cornerRadius(16 * scalingFactor)
            .shadow(color: CMColor.primary.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
    
    private func getConnectionType() -> String {
        return "Wi-Fi • \(UIDevice.current.model)"
    }
    
    // MARK: - Переделанный график
    private var speedtestGraph: some View {
        VStack(alignment: .leading, spacing: 16 * scalingFactor) {
            // Заголовок графика
            HStack {
                Text("Testing History")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                Spacer()
            }
            .padding(.horizontal)
            
            // Сам график
            ZStack(alignment: .bottom) {
                // Фоновая сетка
                Path { path in
                    let width: CGFloat = UIScreen.main.bounds.width - 64 * scalingFactor
                    let height: CGFloat = 150 * scalingFactor
                    
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(CMColor.border.opacity(0.3), lineWidth: 0.5)
                .frame(height: 150 * scalingFactor)
                
                // График загрузки
                if speedometerViewModel.downloadSpeed > 0 || speedometerViewModel.finalDownloadSpeed > 0 {
                    createSpeedArea(
                        speed: speedometerViewModel.finalDownloadSpeed > 0 ? speedometerViewModel.finalDownloadSpeed : speedometerViewModel.downloadSpeed,
                        color: CMColor.primaryLight,
                        isUpload: false
                    )
                }
                
                // График выгрузки
                if speedometerViewModel.uploadSpeed > 0 || speedometerViewModel.finalUploadSpeed > 0 {
                    createSpeedArea(
                        speed: speedometerViewModel.finalUploadSpeed > 0 ? speedometerViewModel.finalUploadSpeed : speedometerViewModel.uploadSpeed,
                        color: CMColor.success,
                        isUpload: true
                    )
                }
            }
            .frame(height: 150 * scalingFactor)
            .padding(.horizontal)
            
            // Легенда
            HStack(spacing: 24 * scalingFactor) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(CMColor.primaryLight)
                        .frame(width: 8, height: 8)
                    Text("Loading")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(CMColor.success)
                        .frame(width: 8, height: 8)
                    Text("Uploading")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(24 * scalingFactor)
    }
    
    // Новый метод для создания графика с заливкой
    private func createSpeedArea(speed: Double, color: Color, isUpload: Bool) -> some View {
        ZStack {
            Path { path in
                let width: CGFloat = UIScreen.main.bounds.width - 64 * scalingFactor
                let height: CGFloat = 150 * scalingFactor
                let normalizedSpeed = min(speed / 40.0, 1.0)
                
                let points = createSpeedPoints(width: width, height: height, maxSpeed: normalizedSpeed, isUpload: isUpload)
                
                if let firstPoint = points.first {
                    path.move(to: firstPoint)
                    for i in 1..<points.count {
                        let point = points[i]
                        let previousPoint = points[i - 1]
                        let controlPoint1 = CGPoint(
                            x: previousPoint.x + (point.x - previousPoint.x) / 3,
                            y: previousPoint.y
                        )
                        let controlPoint2 = CGPoint(
                            x: point.x - (point.x - previousPoint.x) / 3,
                            y: point.y
                        )
                        path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
            }
            .fill(color.opacity(0.1))
            .animation(.easeInOut(duration: 0.5), value: speed)
            
            Path { path in
                let width: CGFloat = UIScreen.main.bounds.width - 64 * scalingFactor
                let height: CGFloat = 150 * scalingFactor
                let normalizedSpeed = min(speed / 40.0, 1.0)
                
                let points = createSpeedPoints(width: width, height: height, maxSpeed: normalizedSpeed, isUpload: isUpload)
                
                if let firstPoint = points.first {
                    path.move(to: firstPoint)
                    for i in 1..<points.count {
                        let point = points[i]
                        let previousPoint = points[i - 1]
                        let controlPoint1 = CGPoint(
                            x: previousPoint.x + (point.x - previousPoint.x) / 3,
                            y: previousPoint.y
                        )
                        let controlPoint2 = CGPoint(
                            x: point.x - (point.x - previousPoint.x) / 3,
                            y: point.y
                        )
                        path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                    }
                }
            }
            .trim(from: 0, to: speedometerViewModel.testPhase == .completed ? 1.0 : graphDrawProgress)
            .stroke(color, lineWidth: 2.5)
            .animation(.easeInOut(duration: 0.5), value: speed)
        }
    }
    
    private func createSpeedPoints(width: CGFloat, height: CGFloat, maxSpeed: Double, isUpload: Bool) -> [CGPoint] {
        var points: [CGPoint] = []
        let stepCount = 20
        
        for i in 0...stepCount {
            let x = width * CGFloat(i) / CGFloat(stepCount)
            let progress = Double(i) / Double(stepCount)
            
            var speedAtPoint: Double
            if isUpload {
                speedAtPoint = maxSpeed * (1.0 - exp(-progress * 3))
            } else {
                speedAtPoint = maxSpeed * (1.0 - cos(progress * .pi / 2))
            }
            
            let y = height * (1.0 - speedAtPoint)
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
}
