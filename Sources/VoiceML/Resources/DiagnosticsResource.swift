import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Diagnostic surfaces — `/health` and the OpenAPI doc endpoints. These sit at server root
/// (not under `/2010-04-01/Accounts/{AccountSid}/`) and are intentionally unauthenticated.
public final class DiagnosticsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Deep liveness probe. 200 = hard checks pass; 503 raises a ``ServerError``.
    public func health() async throws -> HealthStatus {
        let url = transport.baseURL.appendingPathComponent("health")
        return try await fetchUnauth(url: url)
    }

    /// Fetch the OpenAPI spec as raw bytes; decode as you see fit.
    public func openapiJson() async throws -> Data {
        let url = transport.baseURL.appendingPathComponent("openapi.json")
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.dataCompat(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ApiError(message: "/openapi.json returned \(http.statusCode)", statusCode: http.statusCode)
        }
        return data
    }

    private func fetchUnauth<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.dataCompat(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ApiError(message: "\(url.path) returned \(http.statusCode)", statusCode: http.statusCode, body: data)
        }
        return try Transport.makeDecoder().decode(T.self, from: data)
    }
}

private extension URLSession {
    /// Async-compat shim that works on both Apple and Linux Foundation.
    func dataCompat(for request: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
        return try await withCheckedThrowingContinuation { cont in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let data = data, let response = response else {
                    cont.resume(throwing: ApiError(message: "empty response", statusCode: 0))
                    return
                }
                cont.resume(returning: (data, response))
            }
            task.resume()
        }
        #else
        return try await data(for: request)
        #endif
    }
}
