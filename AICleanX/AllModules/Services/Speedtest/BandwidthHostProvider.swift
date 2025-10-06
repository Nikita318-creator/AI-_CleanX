import Foundation
import Combine
import os.log

/// Поставщик хостов для тестирования пропускной способности (Speedtest.net API)
public final class BandwidthHostProvider: BandwidthHostProviding {
    private let serviceURL: URL
    private let urlSession: URLSession
    private let logger = Logger(subsystem: "com.cleanme.speedtest", category: "BandwidthHostProvider")
    
    public required init(serviceURL: URL) {
        self.serviceURL = serviceURL
        self.urlSession = URLSession(configuration: .default)
    }
    
    public convenience init() {
        let defaultURL = URL(string: "https://www.speedtest.net/api/js/servers?engine=js&https_functional=true")!
        self.init(serviceURL: defaultURL)
    }
    
    public func fetchHosts(timeout: TimeInterval = 30.0) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
        logger.info("🌐 BandwidthHostProvider: ВОЗВРАЩАЕМ СЕРВЕР ПО УМОЛЧАНИЮ ДЛЯ США")
        
        let usDefaultURL = URL(string: "http://speedtest.tctelco.net:8080/")!
        
        let usDefaultHost = BandwidthTestHost(
            url: usDefaultURL,
            name: "Test Server",
            country: "United States",
            countryCode: "US",
            hostAddress: "speedtest.tctelco.net:8080",
            sponsor: "TCTELCO",
            distanceKm: 0
        )
        
        return Just([usDefaultHost])
            .setFailureType(to: BandwidthTestError.self)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    public func fetchHosts(maxCount: Int, timeout: TimeInterval = 30.0) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
        return fetchHosts(timeout: timeout)
            .map { hosts in
                Array(hosts.prefix(maxCount))
            }
            .eraseToAnyPublisher()
    }
}
