import Foundation

extension URLResponse {
    private var httpURLResponse: HTTPURLResponse? {
        return self as? HTTPURLResponse
    }

    var isSuccessful: Bool {
        if let response = httpURLResponse, (200...299).contains(response.statusCode) {
            return true
        }
        return false
    }

    var isJSONContentType: Bool {
        if let response = httpURLResponse,
           let contentType = response.allHeaderFields["Content-Type"] as? String,
           contentType.lowercased().contains("application/json") {
            return true
        }
        return false
    }
}
