import Foundation

/// Twilio-compatible capability matrix for a DID. VoiceML is voice-only, so the wire payload
/// always reports `voice=true` and `sms=mms=fax=false`, but the structure is preserved
/// for Twilio SDK compatibility (e.g. callers writing `number.capabilities.voice`).
public struct IncomingPhoneNumberCapabilities: Codable, Sendable {
    public var voice: Bool
    public var sms: Bool
    public var mms: Bool
    public var fax: Bool?

    public init(voice: Bool, sms: Bool, mms: Bool, fax: Bool? = nil) {
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
///
/// Most fields outside the core (sid/accountSid/phoneNumber/voice routing) are present
/// for Twilio-compat: VoiceML emits documented defaults (empty string, `false`, `null`)
/// so strict-binding SDKs deserialize without errors.
public struct IncomingPhoneNumber: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var phoneNumber: String
    public var friendlyName: String?
    public var apiVersion: String
    public var uri: String
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
    /// DID classification — e.g. `local`, `toll-free`, `mobile` (spec v0.6.2 / D6).
    /// Optional for forward/backward compatibility.
    public var type: String?
    public var dateCreated: String
    public var dateUpdated: String
}

/// `GET /IncomingPhoneNumbers.json` list response — Twilio-compatible pagination envelope
/// plus the `incomingPhoneNumbers` items array (snake_case `incoming_phone_numbers` on
/// the wire, converted by `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`).
public struct IncomingPhoneNumberList: Codable, Sendable {
    public var incomingPhoneNumbers: [IncomingPhoneNumber]
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

/// Query parameters for `GET /IncomingPhoneNumbers.json`.
public struct ListIncomingPhoneNumbersParams: Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var phoneNumber: String?
    public var pageToken: String?

    public init(page: Int? = nil, pageSize: Int? = nil, phoneNumber: String? = nil, pageToken: String? = nil) {
        self.page = page
        self.pageSize = pageSize
        self.phoneNumber = phoneNumber
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PhoneNumber", phoneNumber),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Query params for type-specific `/IncomingPhoneNumbers/{Local,Mobile,TollFree}` list endpoints.
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
/// tenant — re-POSTing rebinds the voice routing rather than erroring. Returns 409
/// when the number is already claimed by a different account.
public struct CreateIncomingPhoneNumberParams: Sendable {
    public var phoneNumber: String
    public var voiceUrl: String?
    public var voiceMethod: HttpMethod?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: HttpMethod?

    public init(
        phoneNumber: String,
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil,
        voiceFallbackUrl: String? = nil,
        voiceFallbackMethod: HttpMethod? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("PhoneNumber", phoneNumber),
            FormField("VoiceUrl", voiceUrl),
            FormField("VoiceMethod", voiceMethod?.rawValue),
            FormField("VoiceFallbackUrl", voiceFallbackUrl),
            FormField("VoiceFallbackMethod", voiceFallbackMethod?.rawValue),
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

    public init(
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil,
        voiceFallbackUrl: String? = nil,
        voiceFallbackMethod: HttpMethod? = nil
    ) {
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("VoiceUrl", voiceUrl),
            FormField("VoiceMethod", voiceMethod?.rawValue),
            FormField("VoiceFallbackUrl", voiceFallbackUrl),
            FormField("VoiceFallbackMethod", voiceFallbackMethod?.rawValue),
        ]
    }
}
