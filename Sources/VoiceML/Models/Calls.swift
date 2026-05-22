import Foundation

public enum CallStatus: String, Codable, Sendable {
    case queued, ringing
    case inProgress = "in-progress"
    case completed, busy
    case noAnswer = "no-answer"
    case canceled, failed
}

public enum CallDirection: String, Codable, Sendable {
    case inbound
    case outboundApi = "outbound-api"
    case outboundDial = "outbound-dial"
}

public enum AnsweredBy: String, Codable, Sendable {
    case human
    case machineStart = "machine_start"
    case machineEndBeep = "machine_end_beep"
    case machineEndSilence = "machine_end_silence"
    case machineEndOther = "machine_end_other"
    case fax
    case unknown
    case empty = ""
}

public enum MachineDetectionMode: String, Codable, Sendable {
    case enable = "Enable"
    case detectMessageEnd = "DetectMessageEnd"
}

public enum RecordingChannelsLayout: String, Codable, Sendable {
    case mono, dual
}

public enum RecordingTrack: String, Codable, Sendable {
    case inbound, outbound, both
}

public enum TrimMode: String, Codable, Sendable {
    case trimSilence = "trim-silence"
    case doNotTrim = "do-not-trim"
}

public enum CallStatusCallbackEvent: String, Codable, Sendable {
    case initiated, ringing, answered, completed
}

public enum UpdateCallStatus: String, Codable, Sendable {
    case completed, canceled
}

/// A single call resource. Decoded from `GET /Calls/{sid}` and embedded in `CallList`.
public struct Call: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var apiVersion: String
    public var to: String?
    public var toFormatted: String?
    public var from: String?
    public var fromFormatted: String?
    public var parentCallSid: String?
    public var callerName: String?
    public var forwardedFrom: String?
    public var status: CallStatus
    public var direction: CallDirection
    public var answeredBy: AnsweredBy?
    public var startTime: String?
    public var endTime: String?
    public var duration: String?
    public var price: String?
    public var priceUnit: String?
    public var phoneNumberSid: String?
    public var annotation: String?
    public var groupSid: String?
    public var queueTime: String?
    public var trunkSid: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
    public var subresourceUris: [String: String]?
}

/// Page of calls — Twilio shape.
public struct CallList: Codable, Sendable {
    public var calls: [Call]
    public var page: Int?
    public var pageSize: Int?
    public var numPages: Int?
    public var total: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Body for `POST /Calls`. Sent form-urlencoded by default (Twilio convention).
///
/// Set at most one of `url` / `twiml` / `applicationSid`. If `twiml` is set alongside
/// `url`, Twiml wins (Twilio's documented precedence).
public struct CreateCallRequest: Sendable {
    public var to: String
    public var from: String
    public var url: String?
    public var method: HttpMethod?
    public var twiml: String?
    public var applicationSid: String?
    public var fallbackUrl: String?
    public var fallbackMethod: HttpMethod?
    public var statusCallback: String?
    public var statusCallbackMethod: String?
    public var statusCallbackEvent: [CallStatusCallbackEvent]?
    public var machineDetection: MachineDetectionMode?
    public var machineDetectionTimeout: Int?
    public var machineDetectionSpeechThreshold: Int?
    public var machineDetectionSpeechEndThreshold: Int?
    public var machineDetectionSilenceTimeout: Int?
    public var asyncAmdStatusCallback: String?
    public var asyncAmdStatusCallbackMethod: String?
    public var record: Bool?
    public var recordingStatusCallback: String?
    public var recordingStatusCallbackMethod: String?
    public var recordingStatusCallbackEvent: String?
    public var recordingChannels: RecordingChannelsLayout?
    public var recordingTrack: RecordingTrack?
    public var trim: TrimMode?
    public var timeout: Int?
    public var sendDigits: String?
    public var callerId: String?
    public var callReason: String?
    public var sipAuthUsername: String?
    public var sipAuthPassword: String?
    public var byoc: String?
    public var asyncAmd: Bool?
    public var callToken: String?

    public init(
        to: String,
        from: String,
        url: String? = nil,
        method: HttpMethod? = nil,
        twiml: String? = nil,
        applicationSid: String? = nil,
        fallbackUrl: String? = nil,
        fallbackMethod: HttpMethod? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: String? = nil,
        statusCallbackEvent: [CallStatusCallbackEvent]? = nil,
        machineDetection: MachineDetectionMode? = nil,
        machineDetectionTimeout: Int? = nil,
        machineDetectionSpeechThreshold: Int? = nil,
        machineDetectionSpeechEndThreshold: Int? = nil,
        machineDetectionSilenceTimeout: Int? = nil,
        asyncAmdStatusCallback: String? = nil,
        asyncAmdStatusCallbackMethod: String? = nil,
        record: Bool? = nil,
        recordingStatusCallback: String? = nil,
        recordingStatusCallbackMethod: String? = nil,
        recordingStatusCallbackEvent: String? = nil,
        recordingChannels: RecordingChannelsLayout? = nil,
        recordingTrack: RecordingTrack? = nil,
        trim: TrimMode? = nil,
        timeout: Int? = nil,
        sendDigits: String? = nil,
        callerId: String? = nil,
        callReason: String? = nil,
        sipAuthUsername: String? = nil,
        sipAuthPassword: String? = nil,
        byoc: String? = nil,
        asyncAmd: Bool? = nil,
        callToken: String? = nil
    ) {
        self.to = to
        self.from = from
        self.url = url
        self.method = method
        self.twiml = twiml
        self.applicationSid = applicationSid
        self.fallbackUrl = fallbackUrl
        self.fallbackMethod = fallbackMethod
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
        self.statusCallbackEvent = statusCallbackEvent
        self.machineDetection = machineDetection
        self.machineDetectionTimeout = machineDetectionTimeout
        self.machineDetectionSpeechThreshold = machineDetectionSpeechThreshold
        self.machineDetectionSpeechEndThreshold = machineDetectionSpeechEndThreshold
        self.machineDetectionSilenceTimeout = machineDetectionSilenceTimeout
        self.asyncAmdStatusCallback = asyncAmdStatusCallback
        self.asyncAmdStatusCallbackMethod = asyncAmdStatusCallbackMethod
        self.record = record
        self.recordingStatusCallback = recordingStatusCallback
        self.recordingStatusCallbackMethod = recordingStatusCallbackMethod
        self.recordingStatusCallbackEvent = recordingStatusCallbackEvent
        self.recordingChannels = recordingChannels
        self.recordingTrack = recordingTrack
        self.trim = trim
        self.timeout = timeout
        self.sendDigits = sendDigits
        self.callerId = callerId
        self.callReason = callReason
        self.sipAuthUsername = sipAuthUsername
        self.sipAuthPassword = sipAuthPassword
        self.byoc = byoc
        self.asyncAmd = asyncAmd
        self.callToken = callToken
    }

    /// Render as form fields in the Twilio wire order.
    func formFields() -> [FormField] {
        var fields: [FormField] = [
            FormField("To", to),
            FormField("From", from),
            FormField("Url", url),
            FormField("Method", method?.rawValue),
            FormField("Twiml", twiml),
            FormField("ApplicationSid", applicationSid),
            FormField("FallbackUrl", fallbackUrl),
            FormField("FallbackMethod", fallbackMethod?.rawValue),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod),
        ]
        if let events = statusCallbackEvent {
            for e in events {
                fields.append(FormField("StatusCallbackEvent", e.rawValue))
            }
        }
        fields.append(contentsOf: [
            FormField("MachineDetection", machineDetection?.rawValue),
            FormField("MachineDetectionTimeout", machineDetectionTimeout),
            FormField("MachineDetectionSpeechThreshold", machineDetectionSpeechThreshold),
            FormField("MachineDetectionSpeechEndThreshold", machineDetectionSpeechEndThreshold),
            FormField("MachineDetectionSilenceTimeout", machineDetectionSilenceTimeout),
            FormField("AsyncAmdStatusCallback", asyncAmdStatusCallback),
            FormField("AsyncAmdStatusCallbackMethod", asyncAmdStatusCallbackMethod),
            FormField("Record", record),
            FormField("RecordingStatusCallback", recordingStatusCallback),
            FormField("RecordingStatusCallbackMethod", recordingStatusCallbackMethod),
            FormField("RecordingStatusCallbackEvent", recordingStatusCallbackEvent),
            FormField("RecordingChannels", recordingChannels?.rawValue),
            FormField("RecordingTrack", recordingTrack?.rawValue),
            FormField("Trim", trim?.rawValue),
            FormField("Timeout", timeout),
            FormField("SendDigits", sendDigits),
            FormField("CallerId", callerId),
            FormField("CallReason", callReason),
            FormField("SipAuthUsername", sipAuthUsername),
            FormField("SipAuthPassword", sipAuthPassword),
            FormField("Byoc", byoc),
            FormField("AsyncAmd", asyncAmd),
            FormField("CallToken", callToken),
        ])
        return fields
    }
}

/// Body for `POST /Calls/{sid}` — three flows on the same endpoint:
///   - `status=.completed/.canceled` — terminate (wins over any TwiML source).
///   - `twiml=<inline>` — execute inline TwiML on the live call (wins over `url`).
///   - `url=…` — fetch new TwiML and execute it.
public struct UpdateCallRequest: Sendable {
    public var status: UpdateCallStatus?
    public var twiml: String?
    public var url: String?
    public var method: HttpMethod?
    public var fallbackUrl: String?
    public var fallbackMethod: HttpMethod?
    public var statusCallback: String?
    public var statusCallbackMethod: String?
    public var statusCallbackEvent: [CallStatusCallbackEvent]?

    public init(
        status: UpdateCallStatus? = nil,
        twiml: String? = nil,
        url: String? = nil,
        method: HttpMethod? = nil,
        fallbackUrl: String? = nil,
        fallbackMethod: HttpMethod? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: String? = nil,
        statusCallbackEvent: [CallStatusCallbackEvent]? = nil
    ) {
        self.status = status
        self.twiml = twiml
        self.url = url
        self.method = method
        self.fallbackUrl = fallbackUrl
        self.fallbackMethod = fallbackMethod
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
        self.statusCallbackEvent = statusCallbackEvent
    }

    func formFields() -> [FormField] {
        var fields: [FormField] = [
            FormField("Status", status?.rawValue),
            FormField("Twiml", twiml),
            FormField("Url", url),
            FormField("Method", method?.rawValue),
            FormField("FallbackUrl", fallbackUrl),
            FormField("FallbackMethod", fallbackMethod?.rawValue),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod),
        ]
        if let events = statusCallbackEvent {
            for e in events {
                fields.append(FormField("StatusCallbackEvent", e.rawValue))
            }
        }
        return fields
    }
}

/// Filter parameters for `GET /Calls`.
public struct ListCallsParams: Sendable {
    public var to: String?
    public var from: String?
    public var status: CallStatus?
    public var parentCallSid: String?
    /// Twilio wire name `StartTime>=`. Inclusive lower bound.
    public var startTimeGte: String?
    /// Twilio wire name `StartTime<=`. Inclusive upper bound.
    public var startTimeLte: String?
    /// Twilio wire name `StartTime`. Calls started on this UTC date.
    public var startTime: String?
    /// Twilio wire name `StartTime<`.
    public var startTimeLt: String?
    /// Twilio wire name `StartTime>`.
    public var startTimeGt: String?
    /// Twilio wire name `EndTime`. Calls ended on this UTC date.
    public var endTime: String?
    /// Twilio wire name `EndTime<`.
    public var endTimeLt: String?
    /// Twilio wire name `EndTime>`.
    public var endTimeGt: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        to: String? = nil,
        from: String? = nil,
        status: CallStatus? = nil,
        parentCallSid: String? = nil,
        startTimeGte: String? = nil,
        startTimeLte: String? = nil,
        startTime: String? = nil,
        startTimeLt: String? = nil,
        startTimeGt: String? = nil,
        endTime: String? = nil,
        endTimeLt: String? = nil,
        endTimeGt: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.to = to
        self.from = from
        self.status = status
        self.parentCallSid = parentCallSid
        self.startTimeGte = startTimeGte
        self.startTimeLte = startTimeLte
        self.startTime = startTime
        self.startTimeLt = startTimeLt
        self.startTimeGt = startTimeGt
        self.endTime = endTime
        self.endTimeLt = endTimeLt
        self.endTimeGt = endTimeGt
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("To", to),
            QueryItem("From", from),
            QueryItem("Status", status?.rawValue),
            QueryItem("ParentCallSid", parentCallSid),
            QueryItem("StartTime", startTime),
            QueryItem("StartTime<", startTimeLt),
            QueryItem("StartTime>", startTimeGt),
            QueryItem("StartTime>=", startTimeGte),
            QueryItem("StartTime<=", startTimeLte),
            QueryItem("EndTime", endTime),
            QueryItem("EndTime<", endTimeLt),
            QueryItem("EndTime>", endTimeGt),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Pagination params for list endpoints (Notifications, Events, Queues, …).
public struct ListPageParams: Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(page: Int? = nil, pageSize: Int? = nil, pageToken: String? = nil) {
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// `GET /Calls/{sid}/Notifications` — always returns an empty list (compat stub).
public struct NotificationsList: Codable, Sendable {
    public var notifications: [AnyCodableSink]
    public var page: Int
    public var pageSize: Int
    public var total: Int
    public var uri: String?
}

/// `GET /Calls/{sid}/Events` — always returns an empty list (compat stub).
public struct EventsList: Codable, Sendable {
    public var events: [AnyCodableSink]
    public var page: Int
    public var pageSize: Int
    public var total: Int
    public var uri: String?
}

/// Placeholder for `unknown[]` arrays — we decode but don't surface the items.
public struct AnyCodableSink: Codable, Sendable {
    public init(from decoder: Decoder) throws {}
    public func encode(to encoder: Encoder) throws {}
}
