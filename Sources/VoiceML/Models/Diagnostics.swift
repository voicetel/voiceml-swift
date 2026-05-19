import Foundation

/// `GET /health` — composite probe.
///
/// Hard-check failures flip `ok` to false (the server returns 503). Soft-check warnings
/// surface in `warnings` only and don't take the host out of rotation.
public struct HealthStatus: Codable, Sendable {
    public var ok: Bool
    public var warnings: [HealthFailure]
    public var failures: [HealthFailure]?
}
