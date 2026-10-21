import Foundation

/// Capability matrix for a DID.
public struct IncomingPhoneNumberCapabilities: Codable, Sendable {
    public var voice: Bool?
    public var sms: Bool?
    public var mms: Bool?
    public var fax: Bool?

    public init(voice: Bool? = nil, sms: Bool? = nil, mms: Bool? = nil, fax: Bool? = nil) {
        self.voice = voice
        self.sms = sms
        self.mms = mms
        self.fax = fax
    }
}

/// Tenant-self-serve view of an assigned DID.
///
/// `sid` is the canonical `PN`-prefixed opaque identifier (`PN` + 32 hex chars).
/// `phoneNumber` carries the E.164 form. These are distinct fields — `phoneNumber` is
/// what end-users see; `sid` is what API calls reference.
public struct IncomingPhoneNumber: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var phoneNumber: String?
    public var friendlyName: String?
    public var apiVersion: String?
    public var uri: String?
    public var origin: String?
    public var beta: Bool?
    public var capabilities: IncomingPhoneNumberCapabilities?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var voiceApplicationSid: String?
    public var voiceCallerIdLookup: Bool?
    public var voiceReceiveMode: String?
    public var smsUrl: String?
    public var smsMethod: String?
    public var smsFallbackUrl: String?
    public var smsFallbackMethod: String?
    public var smsApplicationSid: String?
    public var statusCallback: String?
    public var statusCallbackMethod: String?
    public var trunkSid: String?
    public var addressSid: String?
    public var addressRequirements: String?
    public var identitySid: String?
    public var bundleSid: String?
    public var emergencyStatus: String?
    public var emergencyAddressSid: String?
    public var emergencyAddressStatus: String?
    public var status: String?
    /// DID classification — e.g. `local`, `toll-free`, `mobile`.
    public var type: String?
    public var subresourceUris: [String: String]?
    public var dateCreated: String?
    public var dateUpdated: String?
}

/// `GET /IncomingPhoneNumbers.json` list response in the standard envelope.
public struct IncomingPhoneNumberList: Codable, Sendable {
    public var incomingPhoneNumbers: [IncomingPhoneNumber]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Query parameters for `GET /IncomingPhoneNumbers.json`.
public struct ListIncomingPhoneNumbersParams: Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var phoneNumber: String?
    public var friendlyName: String?
    public var beta: Bool?
    public var origin: String?
    public var pageToken: String?

    public init(
        page: Int? = nil,
        pageSize: Int? = nil,
        phoneNumber: String? = nil,
        friendlyName: String? = nil,
        beta: Bool? = nil,
        origin: String? = nil,
        pageToken: String? = nil
    ) {
        self.page = page
        self.pageSize = pageSize
        self.phoneNumber = phoneNumber
        self.friendlyName = friendlyName
        self.beta = beta
        self.origin = origin
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PhoneNumber", phoneNumber),
            QueryItem("FriendlyName", friendlyName),
            QueryItem("Beta", beta.map { $0 ? "true" : "false" }),
            QueryItem("Origin", origin),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Query params for type-specific `/IncomingPhoneNumbers/{Local,Mobile,TollFree}` list
/// endpoints.
public struct ListTypedIncomingPhoneNumbersParams: Sendable {
    public var phoneNumber: String?
    public var friendlyName: String?
    public var beta: Bool?
    public var origin: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        phoneNumber: String? = nil,
        friendlyName: String? = nil,
        beta: Bool? = nil,
        origin: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.friendlyName = friendlyName
        self.beta = beta
        self.origin = origin
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("PhoneNumber", phoneNumber),
            QueryItem("FriendlyName", friendlyName),
            QueryItem("Beta", beta.map { $0 ? "true" : "false" }),
            QueryItem("Origin", origin),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// `POST /IncomingPhoneNumbers.json` body. Idempotent on `phoneNumber` for the same
/// tenant — re-POSTing rebinds the routing rather than erroring. Returns 409 when the
/// number is already claimed by a different account. Carries both the voice and the
/// inbound-SMS webhook configuration.
public struct CreateIncomingPhoneNumberParams: Sendable {
    public var phoneNumber: String
    public var voiceUrl: String?
    public var voiceMethod: HttpMethod?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: HttpMethod?
    public var smsUrl: String?
    public var smsMethod: HttpMethod?
    public var smsFallbackUrl: String?
    public var smsFallbackMethod: HttpMethod?
    /// Bind inbound-SMS routing to an Application instead of per-number URLs.
    public var smsApplicationSid: String?
    /// Bind voice routing to an Application instead of per-number URLs.
    public var voiceApplicationSid: String?
    /// Number-level lifecycle webhook for inbound calls to this DID.
    public var statusCallback: String?
    /// HTTP method for the status-callback webhook.
    public var statusCallbackMethod: HttpMethod?

    public init(
        phoneNumber: String,
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil,
        voiceFallbackUrl: String? = nil,
        voiceFallbackMethod: HttpMethod? = nil,
        smsUrl: String? = nil,
        smsMethod: HttpMethod? = nil,
        smsFallbackUrl: String? = nil,
        smsFallbackMethod: HttpMethod? = nil,
        smsApplicationSid: String? = nil,
        voiceApplicationSid: String? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: HttpMethod? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
        self.smsUrl = smsUrl
        self.smsMethod = smsMethod
        self.smsFallbackUrl = smsFallbackUrl
        self.smsFallbackMethod = smsFallbackMethod
        self.smsApplicationSid = smsApplicationSid
        self.voiceApplicationSid = voiceApplicationSid
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("PhoneNumber", phoneNumber),
            FormField("VoiceUrl", voiceUrl),
            FormField("VoiceMethod", voiceMethod?.rawValue),
            FormField("VoiceFallbackUrl", voiceFallbackUrl),
            FormField("VoiceFallbackMethod", voiceFallbackMethod?.rawValue),
            FormField("SmsUrl", smsUrl),
            FormField("SmsMethod", smsMethod?.rawValue),
            FormField("SmsFallbackUrl", smsFallbackUrl),
            FormField("SmsFallbackMethod", smsFallbackMethod?.rawValue),
            FormField("SmsApplicationSid", smsApplicationSid),
            FormField("VoiceApplicationSid", voiceApplicationSid),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod?.rawValue),
        ]
    }
}

/// Body for the typed `POST /IncomingPhoneNumbers/{Local,Mobile,TollFree}.json`
/// creates — these declare only `PhoneNumber`, `VoiceUrl` and `VoiceMethod`.
public struct CreateTypedIncomingPhoneNumberParams: Sendable {
    public var phoneNumber: String
    public var voiceUrl: String?
    public var voiceMethod: HttpMethod?

    public init(
        phoneNumber: String,
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("PhoneNumber", phoneNumber),
            FormField("VoiceUrl", voiceUrl),
            FormField("VoiceMethod", voiceMethod?.rawValue),
        ]
    }
}

/// `POST /IncomingPhoneNumbers/{Sid}.json` body. Only-set-fields-touched semantics —
/// `nil` values are omitted from the form payload.
public struct UpdateIncomingPhoneNumberParams: Sendable {
    public var voiceUrl: String?
    public var voiceMethod: HttpMethod?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: HttpMethod?
    public var smsUrl: String?
    public var smsMethod: HttpMethod?
    public var smsFallbackUrl: String?
    public var smsFallbackMethod: HttpMethod?
    public var smsApplicationSid: String?
    /// Bind voice routing to an Application instead of per-number URLs.
    public var voiceApplicationSid: String?
    /// Number-level lifecycle webhook for inbound calls to this DID.
    public var statusCallback: String?
    /// HTTP method for the status-callback webhook.
    public var statusCallbackMethod: HttpMethod?

    public init(
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil,
        voiceFallbackUrl: String? = nil,
        voiceFallbackMethod: HttpMethod? = nil,
        smsUrl: String? = nil,
        smsMethod: HttpMethod? = nil,
        smsFallbackUrl: String? = nil,
        smsFallbackMethod: HttpMethod? = nil,
        smsApplicationSid: String? = nil,
        voiceApplicationSid: String? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: HttpMethod? = nil
    ) {
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
        self.smsUrl = smsUrl
        self.smsMethod = smsMethod
        self.smsFallbackUrl = smsFallbackUrl
        self.smsFallbackMethod = smsFallbackMethod
        self.smsApplicationSid = smsApplicationSid
        self.voiceApplicationSid = voiceApplicationSid
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("VoiceUrl", voiceUrl),
            FormField("VoiceMethod", voiceMethod?.rawValue),
            FormField("VoiceFallbackUrl", voiceFallbackUrl),
            FormField("VoiceFallbackMethod", voiceFallbackMethod?.rawValue),
            FormField("SmsUrl", smsUrl),
            FormField("SmsMethod", smsMethod?.rawValue),
            FormField("SmsFallbackUrl", smsFallbackUrl),
            FormField("SmsFallbackMethod", smsFallbackMethod?.rawValue),
            FormField("SmsApplicationSid", smsApplicationSid),
            FormField("VoiceApplicationSid", voiceApplicationSid),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod?.rawValue),
        ]
    }
}
