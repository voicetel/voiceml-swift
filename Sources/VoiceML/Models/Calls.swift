import Foundation

/// Call lifecycle status. Open enum — an unknown wire value decodes as-is instead of
/// failing the whole payload.
public struct CallStatus: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let queued = CallStatus(rawValue: "queued")
    public static let ringing = CallStatus(rawValue: "ringing")
    public static let inProgress = CallStatus(rawValue: "in-progress")
    public static let completed = CallStatus(rawValue: "completed")
    public static let busy = CallStatus(rawValue: "busy")
    public static let noAnswer = CallStatus(rawValue: "no-answer")
    public static let canceled = CallStatus(rawValue: "canceled")
    public static let failed = CallStatus(rawValue: "failed")
}

/// Direction a call was originated in. Open enum — tolerant of `""` and new values.
public struct CallDirection: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let inbound = CallDirection(rawValue: "inbound")
    public static let outboundApi = CallDirection(rawValue: "outbound-api")
    public static let outboundDial = CallDirection(rawValue: "outbound-dial")
}

/// AMD outcome on a call. Open enum.
public struct AnsweredBy: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let human = AnsweredBy(rawValue: "human")
    public static let machineStart = AnsweredBy(rawValue: "machine_start")
    public static let machineEndBeep = AnsweredBy(rawValue: "machine_end_beep")
    public static let machineEndSilence = AnsweredBy(rawValue: "machine_end_silence")
    public static let machineEndOther = AnsweredBy(rawValue: "machine_end_other")
    public static let fax = AnsweredBy(rawValue: "fax")
    public static let unknown = AnsweredBy(rawValue: "unknown")
    public static let empty = AnsweredBy(rawValue: "")
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
/// Fields the spec marks nullable are optional here so a null never fails the page.
public struct Call: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var apiVersion: String?
    public var to: String?
    public var toFormatted: String?
    public var from: String?
    public var fromFormatted: String?
    public var parentCallSid: String?
    public var callerName: String?
    public var forwardedFrom: String?
    public var status: CallStatus?
    public var direction: CallDirection?
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
    public var dateCreated: String?
    public var dateUpdated: String?
    public var uri: String?
    public var subresourceUris: [String: String]?
}

/// Page of calls. The envelope carries `page`, `page_size`, `start`, `end`,
/// `first_page_uri`, `previous_page_uri`, `next_page_uri` and `uri`; `total` and
/// `num_pages` are no longer emitted by the server.
public struct CallList: Codable, Sendable {
    public var calls: [Call]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Body for `POST /Calls`. Sent form-urlencoded by default (wire convention).
///
/// Set at most one of `url` / `twiml` / `applicationSid`. If `twiml` is set alongside
/// `url`, Twiml wins (the documented precedence).
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

    /// Render as form fields in the wire order.
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

/// Filter parameters for `GET /Calls`. The spec declares `StartTime`, `StartTime<`
/// and `StartTime>` (same shape for `EndTime`).
public struct ListCallsParams: Sendable {
    public var to: String?
    public var from: String?
    public var status: CallStatus?
    public var parentCallSid: String?
    /// Wire name `StartTime`. Calls started on this UTC date.
    public var startTime: String?
    /// Wire name `StartTime<`.
    public var startTimeLt: String?
    /// Wire name `StartTime>`.
    public var startTimeGt: String?
    /// Wire name `EndTime`. Calls ended on this UTC date.
    public var endTime: String?
    /// Wire name `EndTime<`.
    public var endTimeLt: String?
    /// Wire name `EndTime>`.
    public var endTimeGt: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        to: String? = nil,
        from: String? = nil,
        status: CallStatus? = nil,
        parentCallSid: String? = nil,
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

/// Query params for `GET /Notifications` and `GET /Calls/{sid}/Notifications`.
public struct ListNotificationsParams: Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?
    public var log: Int?
    public var messageDate: String?
    public var messageDateLt: String?
    public var messageDateGt: String?

    public init(
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil,
        log: Int? = nil,
        messageDate: String? = nil,
        messageDateLt: String? = nil,
        messageDateGt: String? = nil
    ) {
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.log = log
        self.messageDate = messageDate
        self.messageDateLt = messageDateLt
        self.messageDateGt = messageDateGt
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
            QueryItem("Log", log.map(String.init)),
            QueryItem("MessageDate", messageDate),
            QueryItem("MessageDate<", messageDateLt),
            QueryItem("MessageDate>", messageDateGt),
        ]
    }
}

/// Twilio-compatible alert-log entry. Rows are emitted when a TwiML document fetch or
/// parse fails; `error_code`/`more_info` follow the documented error dictionary.
public struct Notification: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var callSid: String?
    public var apiVersion: String?
    /// Numeric error code rendered as a string on the wire (e.g. `"11200"`).
    public var errorCode: String?
    /// `"0"` or `"1"`, as a string.
    public var log: String?
    public var messageDate: String?
    public var messageText: String?
    public var moreInfo: String?
    public var requestMethod: String?
    public var requestUrl: String?
    public var uri: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

/// Page of notifications, in the standard list envelope.
public struct NotificationsList: Codable, Sendable {
    public var notifications: [Notification]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// One leg of a per-call lifecycle event: the recorded REST request or response.
public struct CallEventRequest: Codable, Sendable {
    public var method: String?
    public var parameters: [String: String]?
    public var url: String?
}

public struct CallEventResponse: Codable, Sendable {
    public var contentType: String?
    public var dateCreated: String?
    public var requestDuration: Int?
    public var responseBody: String?
    public var responseCode: Int?
}

/// Twilio-compatible per-call lifecycle event — one row per REST request/response
/// against a call. List-only; the Events resource has no fetch-by-id operation.
public struct CallEvent: Codable, Sendable {
    public var request: CallEventRequest?
    public var response: CallEventResponse?
}

/// Page of call events, in the standard list envelope.
public struct EventsList: Codable, Sendable {
    public var events: [CallEvent]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}
