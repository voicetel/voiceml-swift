import Foundation

/// Twilio-compatible account-balance resource — `GET /Accounts/{sid}/Balance.json`.
/// `balance` is a decimal-formatted string to preserve the Twilio wire shape;
/// `currency` is a 3-letter ISO 4217 code. Modelled for fixture-driven
/// conformance; the SDK doesn't currently surface a Balance resource client.
public struct Balance: Codable, Sendable {
    public var accountSid: String
    public var balance: String
    public var currency: String
}
