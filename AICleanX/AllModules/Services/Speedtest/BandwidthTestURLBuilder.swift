import Foundation

/// Конструктор URL для тестирования пропускной способности
public final class BandwidthTestURLBuilder {
    private let baseURL: URL
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    /// URL для загрузки данных с сервера
    public var downloadBaseURL: URL {
        return baseURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("download")
    }
    
    /// URL для отправки данных на сервер
    public var uploadURL: URL {
        return baseURL
    }
    
    /// Создает URL для загрузки с указанным размером данных
    public func downloadURL(dataSize: Int) -> URL? {
        guard var components = URLComponents(url: downloadBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.port = 8080
        components.queryItems = [
            URLQueryItem(name: "size", value: String(dataSize))
        ]
        
        return components.url
    }
    
    /// Создает URL для загрузки с дополнительными параметрами
    public func downloadURL(dataSize: Int, additionalParameters: [String: String] = [:]) -> URL? {
        guard var components = URLComponents(url: downloadBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.port = 8080
        
        var queryItems = [URLQueryItem(name: "size", value: String(dataSize))]
        for (key, value) in additionalParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        
        return components.url
    }
    
    /// Проверяет валидность базового URL
    public var isValidBaseURL: Bool {
        return baseURL.scheme != nil && baseURL.host != nil
    }
}
