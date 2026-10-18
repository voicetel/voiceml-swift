import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Diagnostic surfaces — `/health` and the OpenAPI doc endpoints. These sit at server
/// root (not under `/2010-04-01/Accounts/{AccountSid}/`) and are unauthenticated, so
/// they also work through the credential-less standalone helpers below. All requests
/// go through the configured session, timeout and retry policy.
public final class DiagnosticsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Deep liveness probe. 200 = hard checks pass; 503 raises a ``ServerError``.
    public func health() async throws -> HealthStatus {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/health",
            authenticated: false
        ))
    }

    /// Fetch the OpenAPI spec (JSON) as raw bytes; decode as you see fit.
    public func openapiJson() async throws -> Data {
        try await fetchDoc("/openapi.json")
    }

    /// Fetch the OpenAPI spec (YAML) as raw bytes.
    public func openapiYaml() async throws -> Data {
        try await fetchDoc("/openapi.yaml")
    }

    /// Fetch the OpenAPI spec (`.yml` alias) as raw bytes.
    public func openapiYml() async throws -> Data {
        try await fetchDoc("/openapi.yml")
    }

    private func fetchDoc(_ rawPath: String) async throws -> Data {
        let (data, status, _) = try await transport.sendUnauthDoc(rawPath)
        if !(200..<300).contains(status) {
            throw errorFromResponse(
                statusCode: status,
                code: nil,
                body: data,
                message: "\(rawPath) returned \(status)"
            )
        }
        return data
    }

    // MARK: - Standalone (credential-less) helpers

    /// Call `GET /health` without constructing a client — diagnostics are
    /// unauthenticated, so no credentials are needed or sent. Uses the supplied (or a
    /// default) `URLSession` and timeout.
    public static func health(
        baseURL: URL = URL(string: "https://voiceml.voicetel.com")!,
        session: URLSession? = nil,
        timeout: TimeInterval = 30
    ) async throws -> HealthStatus {
        let transport = try Transport(
            diagnosticsBaseURL: baseURL,
            timeout: timeout,
            resourceTimeout: timeout,
            maxRetries: 2,
            userAgent: "voiceml-swift/\(voiceMLVersion)",
            session: session
        )
        let resource = DiagnosticsResource(transport: transport)
        return try await resource.health()
    }

    /// Call `GET /openapi.json` without constructing a client.
    public static func openapiJson(
        baseURL: URL = URL(string: "https://voiceml.voicetel.com")!,
        session: URLSession? = nil,
        timeout: TimeInterval = 30
    ) async throws -> Data {
        let transport = try Transport(
            diagnosticsBaseURL: baseURL,
            timeout: timeout,
            resourceTimeout: timeout,
            maxRetries: 2,
            userAgent: "voiceml-swift/\(voiceMLVersion)",
            session: session
        )
        let resource = DiagnosticsResource(transport: transport)
        return try await resource.openapiJson()
    }
}
