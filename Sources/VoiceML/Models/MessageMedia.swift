import Foundation

/// One MMS media attachment, scoped under `/Messages/{sid}/Media/{sid}.json`.
/// Modelled for fixture-driven conformance; the SDK doesn't currently surface
/// a Messages.Media resource client.
public struct Media: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var parentSid: String
    public var contentType: String
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

/// Envelope for `GET /Messages/{sid}/Media.json`.
public struct MediaList: Codable, Sendable {
    public var mediaList: [Media]
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
