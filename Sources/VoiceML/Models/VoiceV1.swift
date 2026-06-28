import Foundation

// Twilio Voice v1 (voice.twilio.com/v1) — six resources (#420):
//   IpRecord, SourceIpMapping, ByocTrunk, ConnectionPolicy,
//   ConnectionPolicyTarget, DialingPermissions Settings.
//
// All /v1 paths bypass the /2010-04-01/Accounts/{Sid}/ prefix — the
// account is resolved from HTTP Basic auth. List responses use the
// `meta` envelope (shared with Conversations v1). Dates are ISO-8601.

// MARK: - Shared list-envelope meta block

/// Twilio v1 pagination envelope, shared by Voice v1 and Conversations v1
/// list responses. Field names match `convertFromSnakeCase` mapping of the
/// wire keys (`first_page_url` → `firstPageUrl`, etc.).
public struct V1Meta: Codable, Sendable {
    public var firstPageUrl: String?
    public var nextPageUrl: String?
    public var previousPageUrl: String?
    public var url: String?
    public var page: Int?
    public var pageSize: Int?
    public var key: String?
}

// MARK: - IpRecord

/// A standalone allowed source IP (Twilio Voice v1). SID is `IL…`.
public struct VoiceV1IpRecord: Codable, Sendable {
    public var accountSid: String?
    public var sid: String?
    public var friendlyName: String?
    public var ipAddress: String?
    public var cidrPrefixLength: Int
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
}

public struct VoiceV1IpRecordList: Codable, Sendable {
    public var ipRecords: [VoiceV1IpRecord]
    public var meta: V1Meta
}

// MARK: - SourceIpMapping

/// Binds an IpRecord to a SIP Domain so inbound calls from the source
/// IP route to that domain. SID is `IB…`.
public struct VoiceV1SourceIpMapping: Codable, Sendable {
    public var sid: String?
    public var ipRecordSid: String?
    public var sipDomainSid: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
}

public struct VoiceV1SourceIpMappingList: Codable, Sendable {
    public var sourceIpMappings: [VoiceV1SourceIpMapping]
    public var meta: V1Meta
}

// MARK: - ByocTrunk

/// Bring-your-own-carrier trunk binding. SID is `BY…`.
public struct VoiceV1ByocTrunk: Codable, Sendable {
    public var accountSid: String?
    public var sid: String?
    public var friendlyName: String?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var statusCallbackUrl: String?
    public var statusCallbackMethod: String?
    public var cnamLookupEnabled: Bool?
    public var connectionPolicySid: String?
    public var fromDomainSid: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
}

public struct VoiceV1ByocTrunkList: Codable, Sendable {
    public var byocTrunks: [VoiceV1ByocTrunk]
    public var meta: V1Meta
}

// MARK: - ConnectionPolicy

/// Named routing policy grouping ConnectionPolicy Targets. SID is `NY…`.
public struct VoiceV1ConnectionPolicy: Codable, Sendable {
    public var accountSid: String?
    public var sid: String?
    public var friendlyName: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
    public var links: [String: String]?
}

public struct VoiceV1ConnectionPolicyList: Codable, Sendable {
    public var connectionPolicies: [VoiceV1ConnectionPolicy]
    public var meta: V1Meta
}

// MARK: - ConnectionPolicyTarget

/// One destination SIP URI under a ConnectionPolicy. SID is `NE…`.
public struct VoiceV1ConnectionPolicyTarget: Codable, Sendable {
    public var accountSid: String?
    public var connectionPolicySid: String?
    public var sid: String?
    public var friendlyName: String?
    public var target: String?
    public var priority: Int
    public var weight: Int
    public var enabled: Bool?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
}

public struct VoiceV1ConnectionPolicyTargetList: Codable, Sendable {
    public var targets: [VoiceV1ConnectionPolicyTarget]
    public var meta: V1Meta
}

// MARK: - DialingPermissions Settings

/// Account-level dialing-permissions inheritance flag (subaccounts).
public struct VoiceV1DialingPermissionsSettings: Codable, Sendable {
    public var dialingPermissionsInheritance: Bool?
    public var url: String?
}

// MARK: - List query params (shared shape — `PageSize` only)

/// Query params for `/v1/...` list endpoints. The Voice v1 list shape
/// only documents `PageSize`; cursor pagination follows from the `meta`
/// envelope's `nextPageUrl`.
public struct ListV1PageParams: Sendable {
    public var pageSize: Int?
    public init(pageSize: Int? = nil) { self.pageSize = pageSize }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        return q
    }
}

// MARK: - Request bodies — IpRecord

public struct CreateVoiceV1IpRecordRequest: Sendable {
    public var ipAddress: String
    public var friendlyName: String?
    public var cidrPrefixLength: Int?
    public init(ipAddress: String, friendlyName: String? = nil, cidrPrefixLength: Int? = nil) {
        self.ipAddress = ipAddress
        self.friendlyName = friendlyName
        self.cidrPrefixLength = cidrPrefixLength
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("IpAddress", ipAddress)]
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = cidrPrefixLength { f.append(FormField("CidrPrefixLength", v)) }
        return f
    }
}

public struct UpdateVoiceV1IpRecordRequest: Sendable {
    public var friendlyName: String?
    public init(friendlyName: String? = nil) { self.friendlyName = friendlyName }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        return f
    }
}

// MARK: - Request bodies — SourceIpMapping

public struct CreateVoiceV1SourceIpMappingRequest: Sendable {
    public var ipRecordSid: String
    public var sipDomainSid: String
    public init(ipRecordSid: String, sipDomainSid: String) {
        self.ipRecordSid = ipRecordSid; self.sipDomainSid = sipDomainSid
    }
    public func formFields() -> [FormField] {
        [FormField("IpRecordSid", ipRecordSid), FormField("SipDomainSid", sipDomainSid)]
    }
}

public struct UpdateVoiceV1SourceIpMappingRequest: Sendable {
    public var sipDomainSid: String
    public init(sipDomainSid: String) { self.sipDomainSid = sipDomainSid }
    public func formFields() -> [FormField] {
        [FormField("SipDomainSid", sipDomainSid)]
    }
}

// MARK: - Request bodies — ByocTrunk

public struct CreateVoiceV1ByocTrunkRequest: Sendable {
    public var friendlyName: String?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var statusCallbackUrl: String?
    public var statusCallbackMethod: String?
    public var cnamLookupEnabled: Bool?
    public var connectionPolicySid: String?
    public var fromDomainSid: String?
    public init(friendlyName: String? = nil, voiceUrl: String? = nil, voiceMethod: String? = nil,
                voiceFallbackUrl: String? = nil, voiceFallbackMethod: String? = nil,
                statusCallbackUrl: String? = nil, statusCallbackMethod: String? = nil,
                cnamLookupEnabled: Bool? = nil, connectionPolicySid: String? = nil,
                fromDomainSid: String? = nil) {
        self.friendlyName = friendlyName
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
        self.statusCallbackUrl = statusCallbackUrl
        self.statusCallbackMethod = statusCallbackMethod
        self.cnamLookupEnabled = cnamLookupEnabled
        self.connectionPolicySid = connectionPolicySid
        self.fromDomainSid = fromDomainSid
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = voiceUrl { f.append(FormField("VoiceUrl", v)) }
        if let v = voiceMethod { f.append(FormField("VoiceMethod", v)) }
        if let v = voiceFallbackUrl { f.append(FormField("VoiceFallbackUrl", v)) }
        if let v = voiceFallbackMethod { f.append(FormField("VoiceFallbackMethod", v)) }
        if let v = statusCallbackUrl { f.append(FormField("StatusCallbackUrl", v)) }
        if let v = statusCallbackMethod { f.append(FormField("StatusCallbackMethod", v)) }
        if let v = cnamLookupEnabled { f.append(FormField("CnamLookupEnabled", v)) }
        if let v = connectionPolicySid { f.append(FormField("ConnectionPolicySid", v)) }
        if let v = fromDomainSid { f.append(FormField("FromDomainSid", v)) }
        return f
    }
}

public typealias UpdateVoiceV1ByocTrunkRequest = CreateVoiceV1ByocTrunkRequest

// MARK: - Request bodies — ConnectionPolicy + Target

public struct CreateVoiceV1ConnectionPolicyRequest: Sendable {
    public var friendlyName: String?
    public init(friendlyName: String? = nil) { self.friendlyName = friendlyName }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        return f
    }
}

public typealias UpdateVoiceV1ConnectionPolicyRequest = CreateVoiceV1ConnectionPolicyRequest

public struct CreateVoiceV1ConnectionPolicyTargetRequest: Sendable {
    public var target: String
    public var friendlyName: String?
    public var priority: Int?
    public var weight: Int?
    public var enabled: Bool?
    public init(target: String, friendlyName: String? = nil, priority: Int? = nil,
                weight: Int? = nil, enabled: Bool? = nil) {
        self.target = target
        self.friendlyName = friendlyName
        self.priority = priority
        self.weight = weight
        self.enabled = enabled
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("Target", target)]
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = priority { f.append(FormField("Priority", v)) }
        if let v = weight { f.append(FormField("Weight", v)) }
        if let v = enabled { f.append(FormField("Enabled", v)) }
        return f
    }
}

public struct UpdateVoiceV1ConnectionPolicyTargetRequest: Sendable {
    public var friendlyName: String?
    public var target: String?
    public var priority: Int?
    public var weight: Int?
    public var enabled: Bool?
    public init(friendlyName: String? = nil, target: String? = nil, priority: Int? = nil,
                weight: Int? = nil, enabled: Bool? = nil) {
        self.friendlyName = friendlyName
        self.target = target
        self.priority = priority
        self.weight = weight
        self.enabled = enabled
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = target { f.append(FormField("Target", v)) }
        if let v = priority { f.append(FormField("Priority", v)) }
        if let v = weight { f.append(FormField("Weight", v)) }
        if let v = enabled { f.append(FormField("Enabled", v)) }
        return f
    }
}

// MARK: - Request bodies — DialingPermissions Settings

public struct UpdateVoiceV1DialingPermissionsSettingsRequest: Sendable {
    public var dialingPermissionsInheritance: Bool?
    public init(dialingPermissionsInheritance: Bool? = nil) {
        self.dialingPermissionsInheritance = dialingPermissionsInheritance
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = dialingPermissionsInheritance { f.append(FormField("DialingPermissionsInheritance", v)) }
        return f
    }
}
