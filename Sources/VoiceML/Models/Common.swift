import Foundation

/// HTTP method names accepted in request bodies (status callback method, voice method,
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

/// One tripped check from the `/health` deep probe.
public struct HealthFailure: Codable, Sendable {
    public var check: String
    public var detail: String
}

/// Standard pagination metadata. Lists carry links and range indexes; no total count
/// or page-count fields are returned.
public struct PageEnvelope: Codable, Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// A scalar JSON value for callers reading unstructured data.
public enum JSONValue: Decodable, Sendable {
    case string(String), int(Int), double(Double), bool(Bool), null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else { self = .string(try c.decode(String.self)) }
    }
}

public typealias JSONObject = [String: JSONValue]
