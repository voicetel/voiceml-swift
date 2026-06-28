import Foundation

/// A SIP ingress domain — Twilio-compatible `SD…` resource.
public struct SipDomain: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var domainName: String
    public var apiVersion: String
    public var friendlyName: String?
    public var authType: String?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var voiceStatusCallbackUrl: String?
    public var voiceStatusCallbackMethod: String?
    public var sipRegistration: Bool?
    public var emergencyCallingEnabled: Bool?
    public var secure: Bool?
    public var byocTrunkSid: String?
    public var emergencyCallerSid: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
    public var subresourceUris: [String: String]?
}

public struct SipDomainList: Codable, Sendable {
    public var domains: [SipDomain]
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

public struct SipCredentialList: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
    public var subresourceUris: [String: String]?
}

public struct SipCredentialListList: Codable, Sendable {
    public var credentialLists: [SipCredentialList]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var nextPageUri: String?
    public var uri: String?
}

public struct SipCredential: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var credentialListSid: String
    public var username: String
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

public struct SipCredentialListPage: Codable, Sendable {
    public var credentials: [SipCredential]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var nextPageUri: String?
    public var uri: String?
}

public struct SipIpAccessControlList: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
    public var subresourceUris: [String: String]?
}

public struct SipIpAccessControlListList: Codable, Sendable {
    public var ipAccessControlLists: [SipIpAccessControlList]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var nextPageUri: String?
    public var uri: String?
}

public struct SipIpAddress: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var ipAccessControlListSid: String
    public var friendlyName: String
    public var ipAddress: String
    public var cidrPrefixLength: Int
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

public struct SipIpAddressList: Codable, Sendable {
    public var ipAddresses: [SipIpAddress]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var nextPageUri: String?
    public var uri: String?
}

public struct SipDomainMapping: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String?
    public var domainSid: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

public struct SipCredentialListMappingList: Codable, Sendable {
    public var credentialListMappings: [SipDomainMapping]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var nextPageUri: String?
    public var uri: String?
}

public struct SipIpAccessControlListMappingList: Codable, Sendable {
    public var ipAccessControlListMappings: [SipDomainMapping]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var nextPageUri: String?
    public var uri: String?
}

/// Shape returned by the `/SIP/Domains/{sid}/Auth/Calls/{CredentialListMappings,IpAccessControlListMappings}`
/// and `/SIP/Domains/{sid}/Auth/Registrations/CredentialListMappings` endpoints.
/// Differs from `SipDomainMapping` in that it omits `uri` and `domain_sid` —
/// the auth subresources echo only the mapped-resource sid/account/timestamps.
public struct SipAuthMapping: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String?
    public var dateCreated: String
    public var dateUpdated: String
}

/// Envelope for the `/SIP/Domains/{sid}/Auth/...` mapping list endpoints.
/// Twilio serializes items under the generic `contents` key (vs. the
/// resource-named `credential_list_mappings` / `ip_access_control_list_mappings`
/// used by the non-Auth mapping endpoints).
public struct SipAuthMappingList: Codable, Sendable {
    public var contents: [SipAuthMapping]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

// MARK: - Request bodies

/// Body for `POST /SIP/Domains`. `domainName` is required.
public struct CreateSipDomainRequest: Sendable {
    public var domainName: String
    public var friendlyName: String?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var voiceStatusCallbackUrl: String?
    public var voiceStatusCallbackMethod: String?
    public var sipRegistration: Bool?
    public var secure: Bool?
    public var emergencyCallingEnabled: Bool?
    public var byocTrunkSid: String?
    public var emergencyCallerSid: String?

    public init(domainName: String, friendlyName: String? = nil, voiceUrl: String? = nil,
                voiceMethod: String? = nil, voiceFallbackUrl: String? = nil,
                voiceFallbackMethod: String? = nil, voiceStatusCallbackUrl: String? = nil,
                voiceStatusCallbackMethod: String? = nil, sipRegistration: Bool? = nil,
                secure: Bool? = nil, emergencyCallingEnabled: Bool? = nil,
                byocTrunkSid: String? = nil, emergencyCallerSid: String? = nil) {
        self.domainName = domainName
        self.friendlyName = friendlyName
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
        self.voiceStatusCallbackUrl = voiceStatusCallbackUrl
        self.voiceStatusCallbackMethod = voiceStatusCallbackMethod
        self.sipRegistration = sipRegistration
        self.secure = secure
        self.emergencyCallingEnabled = emergencyCallingEnabled
        self.byocTrunkSid = byocTrunkSid
        self.emergencyCallerSid = emergencyCallerSid
    }

    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("DomainName", domainName)]
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = voiceUrl { f.append(FormField("VoiceUrl", v)) }
        if let v = voiceMethod { f.append(FormField("VoiceMethod", v)) }
        if let v = voiceFallbackUrl { f.append(FormField("VoiceFallbackUrl", v)) }
        if let v = voiceFallbackMethod { f.append(FormField("VoiceFallbackMethod", v)) }
        if let v = voiceStatusCallbackUrl { f.append(FormField("VoiceStatusCallbackUrl", v)) }
        if let v = voiceStatusCallbackMethod { f.append(FormField("VoiceStatusCallbackMethod", v)) }
        if let v = sipRegistration { f.append(FormField("SipRegistration", v)) }
        if let v = secure { f.append(FormField("Secure", v)) }
        if let v = emergencyCallingEnabled { f.append(FormField("EmergencyCallingEnabled", v)) }
        if let v = byocTrunkSid { f.append(FormField("ByocTrunkSid", v)) }
        if let v = emergencyCallerSid { f.append(FormField("EmergencyCallerSid", v)) }
        return f
    }
}

/// Body for `POST /SIP/Domains/{Sid}`. All fields optional.
public struct UpdateSipDomainRequest: Sendable {
    public var friendlyName: String?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var voiceStatusCallbackUrl: String?
    public var voiceStatusCallbackMethod: String?
    public var sipRegistration: Bool?
    public var secure: Bool?
    public var emergencyCallingEnabled: Bool?
    public var byocTrunkSid: String?
    public var emergencyCallerSid: String?

    public init(friendlyName: String? = nil, voiceUrl: String? = nil, voiceMethod: String? = nil,
                voiceFallbackUrl: String? = nil, voiceFallbackMethod: String? = nil,
                voiceStatusCallbackUrl: String? = nil, voiceStatusCallbackMethod: String? = nil,
                sipRegistration: Bool? = nil, secure: Bool? = nil,
                emergencyCallingEnabled: Bool? = nil, byocTrunkSid: String? = nil,
                emergencyCallerSid: String? = nil) {
        self.friendlyName = friendlyName
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
        self.voiceStatusCallbackUrl = voiceStatusCallbackUrl
        self.voiceStatusCallbackMethod = voiceStatusCallbackMethod
        self.sipRegistration = sipRegistration
        self.secure = secure
        self.emergencyCallingEnabled = emergencyCallingEnabled
        self.byocTrunkSid = byocTrunkSid
        self.emergencyCallerSid = emergencyCallerSid
    }

    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = voiceUrl { f.append(FormField("VoiceUrl", v)) }
        if let v = voiceMethod { f.append(FormField("VoiceMethod", v)) }
        if let v = voiceFallbackUrl { f.append(FormField("VoiceFallbackUrl", v)) }
        if let v = voiceFallbackMethod { f.append(FormField("VoiceFallbackMethod", v)) }
        if let v = voiceStatusCallbackUrl { f.append(FormField("VoiceStatusCallbackUrl", v)) }
        if let v = voiceStatusCallbackMethod { f.append(FormField("VoiceStatusCallbackMethod", v)) }
        if let v = sipRegistration { f.append(FormField("SipRegistration", v)) }
        if let v = secure { f.append(FormField("Secure", v)) }
        if let v = emergencyCallingEnabled { f.append(FormField("EmergencyCallingEnabled", v)) }
        if let v = byocTrunkSid { f.append(FormField("ByocTrunkSid", v)) }
        if let v = emergencyCallerSid { f.append(FormField("EmergencyCallerSid", v)) }
        return f
    }
}

public struct CreateSipCredentialListRequest: Sendable {
    public var friendlyName: String
    public init(friendlyName: String) { self.friendlyName = friendlyName }
    public func formFields() -> [FormField] { [FormField("FriendlyName", friendlyName)] }
}

public struct UpdateSipCredentialListRequest: Sendable {
    public var friendlyName: String?
    public init(friendlyName: String? = nil) { self.friendlyName = friendlyName }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        return f
    }
}

public struct CreateSipCredentialRequest: Sendable {
    public var username: String
    public var password: String
    public init(username: String, password: String) { self.username = username; self.password = password }
    public func formFields() -> [FormField] { [FormField("Username", username), FormField("Password", password)] }
}

public struct UpdateSipCredentialRequest: Sendable {
    public var password: String
    public init(password: String) { self.password = password }
    public func formFields() -> [FormField] { [FormField("Password", password)] }
}

public struct CreateSipIpAccessControlListRequest: Sendable {
    public var friendlyName: String
    public init(friendlyName: String) { self.friendlyName = friendlyName }
    public func formFields() -> [FormField] { [FormField("FriendlyName", friendlyName)] }
}

public struct UpdateSipIpAccessControlListRequest: Sendable {
    public var friendlyName: String?
    public init(friendlyName: String? = nil) { self.friendlyName = friendlyName }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        return f
    }
}

public struct CreateSipIpAddressRequest: Sendable {
    public var friendlyName: String
    public var ipAddress: String
    public var cidrPrefixLength: Int?
    public init(friendlyName: String, ipAddress: String, cidrPrefixLength: Int? = nil) {
        self.friendlyName = friendlyName; self.ipAddress = ipAddress; self.cidrPrefixLength = cidrPrefixLength
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("FriendlyName", friendlyName), FormField("IpAddress", ipAddress)]
        if let v = cidrPrefixLength { f.append(FormField("CidrPrefixLength", v)) }
        return f
    }
}

public struct UpdateSipIpAddressRequest: Sendable {
    public var friendlyName: String?
    public var ipAddress: String?
    public var cidrPrefixLength: Int?
    public init(friendlyName: String? = nil, ipAddress: String? = nil, cidrPrefixLength: Int? = nil) {
        self.friendlyName = friendlyName; self.ipAddress = ipAddress; self.cidrPrefixLength = cidrPrefixLength
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = ipAddress { f.append(FormField("IpAddress", v)) }
        if let v = cidrPrefixLength { f.append(FormField("CidrPrefixLength", v)) }
        return f
    }
}

public struct CreateSipCredentialListMappingRequest: Sendable {
    public var credentialListSid: String
    public init(credentialListSid: String) { self.credentialListSid = credentialListSid }
    public func formFields() -> [FormField] { [FormField("CredentialListSid", credentialListSid)] }
}

public struct CreateSipIpAccessControlListMappingRequest: Sendable {
    public var ipAccessControlListSid: String
    public init(ipAccessControlListSid: String) { self.ipAccessControlListSid = ipAccessControlListSid }
    public func formFields() -> [FormField] { [FormField("IpAccessControlListSid", ipAccessControlListSid)] }
}

/// Query params for `/SIP` list endpoints.
public struct ListSipPageParams: Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?
    public init(page: Int? = nil, pageSize: Int? = nil, pageToken: String? = nil) {
        self.page = page; self.pageSize = pageSize; self.pageToken = pageToken
    }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = page { q.append(QueryItem("Page", String(v))) }
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        if let v = pageToken { q.append(QueryItem("PageToken", v)) }
        return q
    }
}
