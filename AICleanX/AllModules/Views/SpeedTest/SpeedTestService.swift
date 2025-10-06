import SwiftUI
import Combine

// MARK: - Сервис для имитации измерения скорости
final class SpeedTestService {
    // Publisher для отправки данных о скорости
    let speedPublisher = PassthroughSubject<SpeedTestSpeed, Never>()
    
    private var timer: Timer?
    private var currentSpeed: Double = 0.0

    func startDownloadTest() {
        self.currentSpeed = 0.0
        var fluctuationCounter = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.currentSpeed < 100 {
                self.currentSpeed += 2.0
            } else {
                fluctuationCounter += 1
                if fluctuationCounter >= 10 {
                    self.currentSpeed += [-2.0, -2.0, 2.0].randomElement() ?? 0
                    if self.currentSpeed >= 115 {
                        self.currentSpeed -= 4.0
                    }
                    fluctuationCounter = 0
                }
            }
            self.speedPublisher.send(SpeedTestSpeed(mBitPs: self.currentSpeed))
        }
    }
    
    func stopTest() {
        timer?.invalidate()
        timer = nil
        speedPublisher.send(SpeedTestSpeed(mBitPs: 0))
    }
    
    // Новые, неиспользуемые пока методы
    func startDownloadTestReal() {
        // Логика реального теста загрузки
    }
    
    func startUploadTestReal() {
        // Логика реального теста выгрузки
    }
    
    func getIp() -> String? {
        // Логика получения IP
        return "192.168.1.1" // Заглушка
    }
}
