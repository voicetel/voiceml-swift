import Foundation

public struct Application: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String
    public var apiVersion: String
    public var voiceUrl: String
    public var voiceMethod: HttpMethod?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: HttpMethod?
    public var voiceCallerIdLookup: Bool
    public var statusCallback: String?
    public var statusCallbackMethod: HttpMethod?
    public var statusCallbackEvent: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

public struct ApplicationList: Codable, Sendable {
    public var applications: [Application]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var uri: String?
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

    public init(
        friendlyName: String? = nil,
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil,
        voiceFallbackUrl: String? = nil,
        voiceFallbackMethod: HttpMethod? = nil,
        voiceCallerIdLookup: Bool? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: HttpMethod? = nil,
        statusCallbackEvent: String? = nil
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
        ]
    }
}

public typealias CreateApplicationRequest = ApplicationRequest
public typealias UpdateApplicationRequest = ApplicationRequest
