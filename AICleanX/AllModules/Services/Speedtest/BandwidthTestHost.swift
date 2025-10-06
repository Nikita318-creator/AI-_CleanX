import Foundation

/// Модель хоста для тестирования пропускной способности
public struct BandwidthTestHost: Codable, Hashable, Identifiable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let country: String
    public let countryCode: String
    public let hostAddress: String
    public let sponsor: String
    public let distanceKm: Int

    private enum CodingKeys: String, CodingKey {
        case url, name, country, sponsor
        case countryCode = "cc"
        case hostAddress = "host"
        case distanceKm = "distance"
    }

    /// Публичный инициализатор для создания экземпляров вручную.
    public init(url: URL, name: String, country: String, countryCode: String, hostAddress: String, sponsor: String, distanceKm: Int) {
        self.url = url
        self.name = name
        self.country = country
        self.countryCode = countryCode
        self.hostAddress = hostAddress
        self.sponsor = sponsor
        self.distanceKm = distanceKm
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        name = try container.decode(String.self, forKey: .name)
        country = try container.decode(String.self, forKey: .country)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        hostAddress = try container.decode(String.self, forKey: .hostAddress)
        sponsor = try container.decode(String.self, forKey: .sponsor)
        distanceKm = try container.decode(Int.self, forKey: .distanceKm)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(name, forKey: .name)
        try container.encode(country, forKey: .country)
        try container.encode(countryCode, forKey: .countryCode)
        try container.encode(hostAddress, forKey: .hostAddress)
        try container.encode(sponsor, forKey: .sponsor)
        try container.encode(distanceKm, forKey: .distanceKm)
    }

    /// URL для HTTP пинга
    public var pingURL: URL? {
        return URL(string: "http://\(hostAddress)")
    }
}
