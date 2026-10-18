import Foundation

/// Twilio-compatible verified outgoing caller ID — `/OutgoingCallerIds/{sid}.json`.
public struct OutgoingCallerId: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var phoneNumber: String?
    public var friendlyName: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var uri: String?
}

/// Envelope for `GET /OutgoingCallerIds.json`.
public struct OutgoingCallerIdList: Codable, Sendable {
    public var outgoingCallerIds: [OutgoingCallerId]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// One-shot validation request issued by `POST /OutgoingCallerIds.json`.
/// Twilio returns the validation code rather than a finalized caller-id sid;
/// there's no `sid` field on this payload.
public struct ValidationRequest: Codable, Sendable {
    public var accountSid: String?
    public var callSid: String?
    public var phoneNumber: String?
    public var friendlyName: String?
    public var validationCode: String?
}
