import Foundation

/// HTTP method names accepted in the Twilio surface (status callback method, voice method,
/// etc.) — only GET or POST.
public enum HttpMethod: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
}

/// Which audio track(s) a media subresource (stream / siprec / transcription) should consume.
public enum TrackSelector: String, Codable, Sendable {
    case inboundTrack = "inbound_track"
    case outboundTrack = "outbound_track"
    case bothTracks = "both_tracks"
}

/// Twilio-compatible pagination envelope. Embedded in every list response that supports paging.
public struct PageEnvelope: Codable, Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var numPages: Int?
    public var total: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// One tripped check from the `/health` deep probe.
public struct HealthFailure: Codable, Sendable {
    public var check: String
    public var detail: String
}

/// Scalar JSON value for untyped compat-stub payloads (e.g. notification fetch).
public enum JSONValue: Decodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unsupported JSON scalar"
            )
        }
    }
}

/// Untyped JSON object for compat stub endpoints.
public typealias JSONObject = [String: JSONValue]
