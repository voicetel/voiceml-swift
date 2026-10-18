import Foundation

public struct Application: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var friendlyName: String?
    public var apiVersion: String?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var voiceCallerIdLookup: Bool?
    public var statusCallback: String?
    public var statusCallbackMethod: String?
    public var statusCallbackEvent: String?
    /// DLR (delivery-receipt) URL fired per-message for outbound SMS sent via this
    /// Application; default target when a message carries no explicit StatusCallback.
    public var messageStatusCallback: String?
    /// Legacy alias of `message_status_callback`.
    public var smsStatusCallback: String?
    /// Inbound-message webhook for numbers bound to this Application.
    public var smsUrl: String?
    public var smsMethod: String?
    public var smsFallbackUrl: String?
    public var smsFallbackMethod: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var uri: String?
}

public struct ApplicationList: Codable, Sendable {
    public var applications: [Application]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Filter parameters for `GET /Applications`.
public struct ListApplicationsParams: Sendable {
    public var friendlyName: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(friendlyName: String? = nil, page: Int? = nil, pageSize: Int? = nil, pageToken: String? = nil) {
        self.friendlyName = friendlyName
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("FriendlyName", friendlyName),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Shared form-body shape for create + update. All fields optional per spec.
public struct ApplicationRequest: Sendable {
    public var friendlyName: String?
    public var voiceUrl: String?
    public var voiceMethod: HttpMethod?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: HttpMethod?
    public var voiceCallerIdLookup: Bool?
    public var statusCallback: String?
    public var statusCallbackMethod: HttpMethod?
    public var statusCallbackEvent: String?
    /// DLR URL for outbound SMS sent via this Application.
    public var messageStatusCallback: String?
    /// Legacy alias of `messageStatusCallback`.
    public var smsStatusCallback: String?

    public init(
        friendlyName: String? = nil,
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil,
        voiceFallbackUrl: String? = nil,
        voiceFallbackMethod: HttpMethod? = nil,
        voiceCallerIdLookup: Bool? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: HttpMethod? = nil,
        statusCallbackEvent: String? = nil,
        messageStatusCallback: String? = nil,
        smsStatusCallback: String? = nil
    ) {
        self.friendlyName = friendlyName
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
        self.voiceCallerIdLookup = voiceCallerIdLookup
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
        self.statusCallbackEvent = statusCallbackEvent
        self.messageStatusCallback = messageStatusCallback
        self.smsStatusCallback = smsStatusCallback
    }

    func formFields() -> [FormField] {
        [
            FormField("FriendlyName", friendlyName),
            FormField("VoiceUrl", voiceUrl),
            FormField("VoiceMethod", voiceMethod?.rawValue),
            FormField("VoiceFallbackUrl", voiceFallbackUrl),
            FormField("VoiceFallbackMethod", voiceFallbackMethod?.rawValue),
            FormField("VoiceCallerIdLookup", voiceCallerIdLookup),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod?.rawValue),
            FormField("StatusCallbackEvent", statusCallbackEvent),
            FormField("MessageStatusCallback", messageStatusCallback),
            FormField("SmsStatusCallback", smsStatusCallback),
        ]
    }
}

public typealias CreateApplicationRequest = ApplicationRequest
public typealias UpdateApplicationRequest = ApplicationRequest
