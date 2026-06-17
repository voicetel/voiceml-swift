import Foundation

/// Twilio routes/v2 Inbound Processing Region binding. SID is `QQ…`.
/// Keyed by SIP domain name (not the SipDomain SID).
public struct RoutesV2SipDomain: Codable, Sendable {
    public var sid: String
    public var sipDomain: String
    public var accountSid: String
    public var friendlyName: String?
    public var voiceRegion: String?
    public var url: String?
    public var dateCreated: String
    public var dateUpdated: String
}

/// Body for `POST /v2/SipDomains/{SipDomain}`. All fields optional.
public struct UpdateRoutesV2SipDomainRequest: Sendable {
    public var voiceRegion: String?
    public var friendlyName: String?
    public init(voiceRegion: String? = nil, friendlyName: String? = nil) {
        self.voiceRegion = voiceRegion; self.friendlyName = friendlyName
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = voiceRegion { f.append(FormField("VoiceRegion", v)) }
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        return f
    }
}
