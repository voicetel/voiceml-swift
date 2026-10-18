import Foundation

/// Twilio-compatible account-balance resource — `GET /Accounts/{sid}/Balance.json`.
/// `balance` is a decimal-formatted string to preserve the wire shape;
/// `currency` is a 3-letter ISO 4217 code.
public struct Balance: Codable, Sendable {
    public var accountSid: String?
    public var balance: String?
    public var currency: String?
}
