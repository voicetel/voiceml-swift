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

/// Twilio-shape pagination envelope. Embedded in every list response that supports paging.
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
