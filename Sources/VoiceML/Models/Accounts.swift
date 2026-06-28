import Foundation

/// Twilio-compatible Account resource — `/Accounts/{sid}.json`.
///
/// The Account payload differs in shape from per-resource records: there's
/// no `account_sid`/`api_version`, and the owning identifier is
/// `owner_account_sid`. `sid` carries the AC… account SID itself.
/// Modelled to support fixture-driven conformance against Twilio's
/// documented FetchAccount / UpdateAccount responses; the SDK doesn't
/// currently surface an Accounts resource client.
public struct Account: Codable, Sendable {
    public var sid: String
    public var ownerAccountSid: String
    public var friendlyName: String?
    public var status: String?
    /// `Trial`, `Full`, etc. Optional for forward compatibility.
    public var type: String?
    public var authToken: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
    public var subresourceUris: [String: String]?
}
