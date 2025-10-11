import Foundation

struct Config: Codable {
    let isProSubs: Bool
}

final class ConfigService {
    static let shared = ConfigService()
    
    private(set) var isProSubs: Bool = true

    private let configURL = URL(string: "https://raw.githubusercontent.com/Nikita318-creator/analitics-data/main/AICleanX1.1")

    private init() {
        fetchConfig()
    }
    
    func fetchConfig() {
        guard let configURL else { return }
        let request = URLRequest(url: configURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let config = try? JSONDecoder().decode(Config.self, from: data) else {
                return
            }

            DispatchQueue.main.async {
                self.isProSubs = config.isProSubs
            }
        }.resume()
    }
}

