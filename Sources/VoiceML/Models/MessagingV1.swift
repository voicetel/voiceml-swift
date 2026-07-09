import Foundation

// Twilio Messaging v1 (messaging.twilio.com/v1) — Messaging Service (#16).
//
// A Messaging Service (MG…) shares the /v1/Services path shape with a
// Conversation Service (IS…); the two are disambiguated on the wire by host
// (messaging.voicetel.com vs conversations.voicetel.com). This SDK routes
// `client.messagingV1.*` at the messaging host automatically — see Hosts.swift.
//
// Only the Messaging Service has an `update` verb, so POST /v1/Services/{sid}
// has no path collision with the Conversation Service.

// MARK: - MessagingService

/// A Messaging Service — Twilio `MG…` resource. Feature-toggle fields are
/// accept-and-echo on VoiceML; the service's operative role is gating scheduled
/// sends. Snake_case wire keys map to camelCase via `.convertFromSnakeCase`.
public struct MessagingService: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var friendlyName: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var inboundRequestUrl: String?
    public var inboundMethod: String?
    public var fallbackUrl: String?
    public var fallbackMethod: String?
    public var statusCallback: String?
    public var stickySender: Bool?
    public var mmsConverter: Bool?
    public var smartEncoding: Bool?
    public var scanMessageContent: String?
    public var fallbackToLongCode: Bool?
    public var areaCodeGeomatch: Bool?
    public var synchronousValidation: Bool?
    public var validityPeriod: Int?
    public var url: String?
    public var usecase: String?
    public var useInboundWebhookOnNumber: Bool?
}

public struct MessagingServiceList: Codable, Sendable {
    public var services: [MessagingService]?
    public var meta: V1Meta?
}

// MARK: - Request bodies

/// Body for `POST /v1/Services` (messaging host). `friendlyName` is required.
public struct CreateMessagingServiceRequest: Sendable {
    public var friendlyName: String
    public var inboundRequestUrl: String?
    public var inboundMethod: String?
    public var fallbackUrl: String?
    public var fallbackMethod: String?
    public var statusCallback: String?
    public var stickySender: Bool?
    public var mmsConverter: Bool?
    public var smartEncoding: Bool?
    public var scanMessageContent: String?
    public var fallbackToLongCode: Bool?
    public var areaCodeGeomatch: Bool?
    public var synchronousValidation: Bool?
    public var validityPeriod: Int?
    public var usecase: String?
    public var useInboundWebhookOnNumber: Bool?

    public init(
        friendlyName: String,
        inboundRequestUrl: String? = nil,
        inboundMethod: String? = nil,
        fallbackUrl: String? = nil,
        fallbackMethod: String? = nil,
        statusCallback: String? = nil,
        stickySender: Bool? = nil,
        mmsConverter: Bool? = nil,
        smartEncoding: Bool? = nil,
        scanMessageContent: String? = nil,
        fallbackToLongCode: Bool? = nil,
        areaCodeGeomatch: Bool? = nil,
        synchronousValidation: Bool? = nil,
        validityPeriod: Int? = nil,
        usecase: String? = nil,
        useInboundWebhookOnNumber: Bool? = nil
    ) {
        self.friendlyName = friendlyName
        self.inboundRequestUrl = inboundRequestUrl
        self.inboundMethod = inboundMethod
        self.fallbackUrl = fallbackUrl
        self.fallbackMethod = fallbackMethod
        self.statusCallback = statusCallback
        self.stickySender = stickySender
        self.mmsConverter = mmsConverter
        self.smartEncoding = smartEncoding
        self.scanMessageContent = scanMessageContent
        self.fallbackToLongCode = fallbackToLongCode
        self.areaCodeGeomatch = areaCodeGeomatch
        self.synchronousValidation = synchronousValidation
        self.validityPeriod = validityPeriod
        self.usecase = usecase
        self.useInboundWebhookOnNumber = useInboundWebhookOnNumber
    }

    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("FriendlyName", friendlyName)]
        if let v = inboundRequestUrl { f.append(FormField("InboundRequestUrl", v)) }
        if let v = inboundMethod { f.append(FormField("InboundMethod", v)) }
        if let v = fallbackUrl { f.append(FormField("FallbackUrl", v)) }
        if let v = fallbackMethod { f.append(FormField("FallbackMethod", v)) }
        if let v = statusCallback { f.append(FormField("StatusCallback", v)) }
        if let v = stickySender { f.append(FormField("StickySender", v)) }
        if let v = mmsConverter { f.append(FormField("MmsConverter", v)) }
        if let v = smartEncoding { f.append(FormField("SmartEncoding", v)) }
        if let v = scanMessageContent { f.append(FormField("ScanMessageContent", v)) }
        if let v = fallbackToLongCode { f.append(FormField("FallbackToLongCode", v)) }
        if let v = areaCodeGeomatch { f.append(FormField("AreaCodeGeomatch", v)) }
        if let v = synchronousValidation { f.append(FormField("SynchronousValidation", v)) }
        if let v = validityPeriod { f.append(FormField("ValidityPeriod", v)) }
        if let v = usecase { f.append(FormField("Usecase", v)) }
        if let v = useInboundWebhookOnNumber { f.append(FormField("UseInboundWebhookOnNumber", v)) }
        return f
    }
}

/// Body for `POST /v1/Services/{sid}` (messaging host). All fields optional.
public struct UpdateMessagingServiceRequest: Sendable {
    public var friendlyName: String?
    public var inboundRequestUrl: String?
    public var inboundMethod: String?
    public var fallbackUrl: String?
    public var fallbackMethod: String?
    public var statusCallback: String?
    public var stickySender: Bool?
    public var mmsConverter: Bool?
    public var smartEncoding: Bool?
    public var scanMessageContent: String?
    public var fallbackToLongCode: Bool?
    public var areaCodeGeomatch: Bool?
    public var synchronousValidation: Bool?
    public var validityPeriod: Int?
    public var usecase: String?
    public var useInboundWebhookOnNumber: Bool?

    public init(
        friendlyName: String? = nil,
        inboundRequestUrl: String? = nil,
        inboundMethod: String? = nil,
        fallbackUrl: String? = nil,
        fallbackMethod: String? = nil,
        statusCallback: String? = nil,
        stickySender: Bool? = nil,
        mmsConverter: Bool? = nil,
        smartEncoding: Bool? = nil,
        scanMessageContent: String? = nil,
        fallbackToLongCode: Bool? = nil,
        areaCodeGeomatch: Bool? = nil,
        synchronousValidation: Bool? = nil,
        validityPeriod: Int? = nil,
        usecase: String? = nil,
        useInboundWebhookOnNumber: Bool? = nil
    ) {
        self.friendlyName = friendlyName
        self.inboundRequestUrl = inboundRequestUrl
        self.inboundMethod = inboundMethod
        self.fallbackUrl = fallbackUrl
        self.fallbackMethod = fallbackMethod
        self.statusCallback = statusCallback
        self.stickySender = stickySender
        self.mmsConverter = mmsConverter
        self.smartEncoding = smartEncoding
        self.scanMessageContent = scanMessageContent
        self.fallbackToLongCode = fallbackToLongCode
        self.areaCodeGeomatch = areaCodeGeomatch
        self.synchronousValidation = synchronousValidation
        self.validityPeriod = validityPeriod
        self.usecase = usecase
        self.useInboundWebhookOnNumber = useInboundWebhookOnNumber
    }

    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = inboundRequestUrl { f.append(FormField("InboundRequestUrl", v)) }
        if let v = inboundMethod { f.append(FormField("InboundMethod", v)) }
        if let v = fallbackUrl { f.append(FormField("FallbackUrl", v)) }
        if let v = fallbackMethod { f.append(FormField("FallbackMethod", v)) }
        if let v = statusCallback { f.append(FormField("StatusCallback", v)) }
        if let v = stickySender { f.append(FormField("StickySender", v)) }
        if let v = mmsConverter { f.append(FormField("MmsConverter", v)) }
        if let v = smartEncoding { f.append(FormField("SmartEncoding", v)) }
        if let v = scanMessageContent { f.append(FormField("ScanMessageContent", v)) }
        if let v = fallbackToLongCode { f.append(FormField("FallbackToLongCode", v)) }
        if let v = areaCodeGeomatch { f.append(FormField("AreaCodeGeomatch", v)) }
        if let v = synchronousValidation { f.append(FormField("SynchronousValidation", v)) }
        if let v = validityPeriod { f.append(FormField("ValidityPeriod", v)) }
        if let v = usecase { f.append(FormField("Usecase", v)) }
        if let v = useInboundWebhookOnNumber { f.append(FormField("UseInboundWebhookOnNumber", v)) }
        return f
    }
}
