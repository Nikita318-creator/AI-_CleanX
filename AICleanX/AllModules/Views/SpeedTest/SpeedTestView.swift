import SwiftUI
import Foundation

struct SpeedTestView: View {
    @StateObject private var speedometerViewModel = SpeedometerViewModel()
    @Binding var isPaywallPresented: Bool

    @State private var animationProgress: CGFloat = 0.0
    @State private var pulseAnimation: Bool = false

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    private var currentStatusColor: Color {
        let speed = speedometerViewModel.speed
        if speed < 10 {
            return CMColor.warning
        } else if speed < 50 {
            return CMColor.accent
        } else {
            return CMColor.success
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20 * scalingFactor) {
                headerSection
                speedIndicatorCard
                metricsCardsRow
                detailedStatsCard
                historyVisualization
            }
            .padding(.horizontal, 20 * scalingFactor)
            .padding(.bottom, 100 * scalingFactor)
            .onAppear {
                animationProgress = 0.0
                withAnimation(.easeOut(duration: 1.2)) {
                    animationProgress = 1.0
                }
                speedometerViewModel.updateIP()
            }
        }
        .background(CMColor.background.ignoresSafeArea())
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Monitor")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Real-time Performance Analysis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CMColor.tertiaryText)
            }
            
            Spacer()
            
            ProBadgeView(isPaywallPresented: $isPaywallPresented)
        }
        .padding(.top, 16 * scalingFactor)
    }
    
    // MARK: - Speed Indicator Card (Полностью новая концепция)
    private var speedIndicatorCard: some View {
        VStack(spacing: 20 * scalingFactor) {
            // Горизонтальный индикатор скорости вместо круглого
            VStack(spacing: 12) {
                HStack {
                    Text("Current Speed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(CMColor.secondaryText)
                    Spacer()
                    Text(speedometerViewModel.testPhase.description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(CMColor.tertiaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CMColor.backgroundSecondary)
                        .cornerRadius(12)
                }
                
                // Большое отображение скорости
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", speedometerViewModel.speed))
                        .font(.system(size: 68, weight: .black))
                        .foregroundColor(currentStatusColor)
                    Text("Mbps")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(CMColor.secondaryText)
                        .offset(y: -8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Горизонтальный прогресс-бар
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Фон
                        RoundedRectangle(cornerRadius: 8)
                            .fill(CMColor.backgroundSecondary)
                            .frame(height: 12)
                        
                        // Заполнение
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [currentStatusColor.opacity(0.6), currentStatusColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * min(CGFloat(speedometerViewModel.speed / 100), 1.0),
                                height: 12
                            )
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: speedometerViewModel.speed)
                    }
                }
                .frame(height: 12)
                
                // Шкала с маркерами
                HStack {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                        if value == 0 {
                            Text("\(value)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(CMColor.tertiaryText)
                        } else {
                            Spacer()
                            Text("\(value)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(CMColor.tertiaryText)
                        }
                    }
                }
            }
            .padding(20)
            .background(CMColor.surface)
            .cornerRadius(20)
            
            // Кнопки действий
            actionButtons
        }
    }
    
    private var actionButtons: some View {
        Group {
            if !speedometerViewModel.isTestInProgress && speedometerViewModel.testPhase == .idle {
                Button(action: {
                    speedometerViewModel.startRealSpeedTest()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                        Text("Begin Analysis")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(CMColor.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [CMColor.primary, CMColor.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
            } else if speedometerViewModel.testPhase == .completed {
                Button(action: {
                    speedometerViewModel.resetTestData()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                        Text("Run New Test")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(CMColor.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [CMColor.accent, CMColor.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
            } else if speedometerViewModel.isTestInProgress {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(CMColor.primary)
                    Text("Analyzing Network...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(CMColor.surface)
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Metrics Cards Row (2 карточки в ряд)
    private var metricsCardsRow: some View {
        HStack(spacing: 12 * scalingFactor) {
            // Download Card
            MetricCardView(
                icon: "arrow.down.to.line.circle.fill",
                title: "Download",
                value: speedometerViewModel.finalDownloadSpeed,
                color: CMColor.primary
            )
            
            // Upload Card
            MetricCardView(
                icon: "arrow.up.to.line.circle.fill",
                title: "Upload",
                value: speedometerViewModel.finalUploadSpeed,
                color: CMColor.success
            )
        }
    }
    
    // MARK: - Detailed Stats Card
    private var detailedStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            VStack(spacing: 12) {
                DetailRow(
                    icon: "wifi.circle.fill",
                    label: "Network Type",
                    value: getConnectionType(),
                    iconColor: CMColor.accent
                )
                
                Divider()
                    .background(CMColor.border)
                
                DetailRow(
                    icon: "server.rack",
                    label: "Test Server",
                    value: speedometerViewModel.serverInfo,
                    iconColor: CMColor.primaryLight
                )
                
                Divider()
                    .background(CMColor.border)
                
                DetailRow(
                    icon: "sensor.fill",
                    label: "Device",
                    value: UIDevice.current.model,
                    iconColor: CMColor.secondary
                )
            }
        }
        .padding(20)
        .background(CMColor.surface)
        .cornerRadius(20)
    }
    
    // MARK: - History Visualization (Новый подход)
    private var historyVisualization: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Graph")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    Text("Real-time speed tracking")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(CMColor.tertiaryText)
                }
                Spacer()
            }
            
            // График с вертикальными барами
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<10) { index in
                    VStack(spacing: 4) {
                        // Столбец для Download
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [CMColor.primary.opacity(0.6), CMColor.primary],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                height: calculateBarHeight(
                                    index: index,
                                    speed: speedometerViewModel.finalDownloadSpeed > 0 ? speedometerViewModel.finalDownloadSpeed : speedometerViewModel.downloadSpeed
                                )
                            )
                        
                        // Столбец для Upload
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [CMColor.success.opacity(0.6), CMColor.success],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                height: calculateBarHeight(
                                    index: index,
                                    speed: speedometerViewModel.finalUploadSpeed > 0 ? speedometerViewModel.finalUploadSpeed : speedometerViewModel.uploadSpeed
                                ) * 0.7
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
            .padding(.vertical, 8)
            
            // Легенда
            HStack(spacing: 20) {
                LegendItem(color: CMColor.primary, label: "Download Speed")
                LegendItem(color: CMColor.success, label: "Upload Speed")
            }
        }
        .padding(20)
        .background(CMColor.surface)
        .cornerRadius(20)
    }
    
    private func calculateBarHeight(index: Int, speed: Double) -> CGFloat {
        let progress = Double(index) / 10.0
        let normalizedSpeed = min(speed / 100.0, 1.0)
        let heightFactor = normalizedSpeed * (1.0 - cos(progress * .pi / 2))
        return CGFloat(heightFactor) * 100 * animationProgress
    }
    
    private func getConnectionType() -> String {
        return "Wi-Fi Connection"
    }
}

// MARK: - Supporting Views

struct MetricCardView: View {
    let icon: String
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CMColor.secondaryText)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    Text("Mbps")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(CMColor.tertiaryText)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CMColor.surface)
        .cornerRadius(16)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
    }
}
