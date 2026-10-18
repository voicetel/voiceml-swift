import Foundation

/// Recording lifecycle status. Open enum — `failed` is deliberately not a documented
/// wire value (an outbound-recording failure surfaces as `absent`), but the SDK keeps
/// tolerating anything the server sends.
public struct RecordingStatus: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let inProgress = RecordingStatus(rawValue: "in-progress")
    public static let paused = RecordingStatus(rawValue: "paused")
    public static let stopped = RecordingStatus(rawValue: "stopped")
    public static let processing = RecordingStatus(rawValue: "processing")
    public static let completed = RecordingStatus(rawValue: "completed")
    public static let absent = RecordingStatus(rawValue: "absent")
    public static let deleted = RecordingStatus(rawValue: "deleted")
    public static let failed = RecordingStatus(rawValue: "failed")
}

/// What produced a recording. Open enum.
public struct RecordingSource: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let outboundAPI = RecordingSource(rawValue: "OutboundAPI")
    public static let recordVerb = RecordingSource(rawValue: "RecordVerb")
    public static let dialVerb = RecordingSource(rawValue: "DialVerb")
    public static let conference = RecordingSource(rawValue: "Conference")
    public static let trunking = RecordingSource(rawValue: "Trunking")
    public static let startCallRecordingAPI = RecordingSource(rawValue: "StartCallRecordingAPI")
    public static let startConferenceRecordingAPI = RecordingSource(rawValue: "StartConferenceRecordingAPI")
}

public enum RecordingUpdateStatus: String, Codable, Sendable {
    case stopped, paused
    case inProgress = "in-progress"
}

/// How a paused span is represented once recording resumes (`Status=paused` updates).
public enum PauseBehavior: String, Codable, Sendable {
    /// Leave the paused span out of the recording.
    case skip
    /// Keep the paused span as silence (the server default).
    case silence
}

public struct Recording: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var callSid: String?
    public var conferenceSid: String?
    public var status: RecordingStatus?
    public var source: RecordingSource?
    public var channels: Int?
    public var duration: String?
    /// The recorded track (`both`); present only in the response that starts a recording.
    public var track: String?
    public var apiVersion: String?
    public var uri: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var startTime: String?
    public var price: String?
    public var priceUnit: String?
    /// Reserved for SSE-KMS metadata when encryption details are exposed.
    public var encryptionDetails: [String: String]?
    public var subresourceUris: [String: String]?
    /// Twilio-compatible pre-signed download URL for the recording audio.
    public var mediaUrl: String?
    /// Error code for failed recordings; `null` (or absent) means no error.
    public var errorCode: Int?
}

/// Recordings list response in the standard envelope (`total`/`num_pages` are no
/// longer emitted).
public struct RecordingList: Codable, Sendable {
    public var recordings: [Recording]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Filter parameters for the account-scoped recording list endpoint.
public struct ListRecordingsParams: Sendable {
    public var dateCreated: String?
    public var dateCreatedLt: String?
    public var dateCreatedGt: String?
    public var callSid: String?
    public var conferenceSid: String?
    public var includeSoftDeleted: Bool?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        dateCreated: String? = nil,
        dateCreatedLt: String? = nil,
        dateCreatedGt: String? = nil,
        callSid: String? = nil,
        conferenceSid: String? = nil,
        includeSoftDeleted: Bool? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.dateCreated = dateCreated
        self.dateCreatedLt = dateCreatedLt
        self.dateCreatedGt = dateCreatedGt
        self.callSid = callSid
        self.conferenceSid = conferenceSid
        self.includeSoftDeleted = includeSoftDeleted
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("DateCreated", dateCreated),
            QueryItem("DateCreated<", dateCreatedLt),
            QueryItem("DateCreated>", dateCreatedGt),
            QueryItem("CallSid", callSid),
            QueryItem("ConferenceSid", conferenceSid),
            QueryItem("IncludeSoftDeleted", includeSoftDeleted.map { $0 ? "true" : "false" }),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Optional query params for `GET /Recordings/{sid}`.
public struct GetRecordingParams: Sendable {
    public var includeSoftDeleted: Bool?

    public init(includeSoftDeleted: Bool? = nil) {
        self.includeSoftDeleted = includeSoftDeleted
    }

    func queryItems() -> [QueryItem] {
        [QueryItem("IncludeSoftDeleted", includeSoftDeleted.map { $0 ? "true" : "false" })]
    }
}

/// Filter parameters for call- and conference-scoped recording list endpoints.
public struct ListCallRecordingsParams: Sendable {
    public var dateCreated: String?
    public var dateCreatedLt: String?
    public var dateCreatedGt: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        dateCreated: String? = nil,
        dateCreatedLt: String? = nil,
        dateCreatedGt: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.dateCreated = dateCreated
        self.dateCreatedLt = dateCreatedLt
        self.dateCreatedGt = dateCreatedGt
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("DateCreated", dateCreated),
            QueryItem("DateCreated<", dateCreatedLt),
            QueryItem("DateCreated>", dateCreatedGt),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Body for `POST /Calls/{sid}/Recordings` and `POST /Conferences/{sid}/Recordings`.
public struct StartRecordingRequest: Sendable {
    public var recordingMaxDuration: Int?
    public var recordingChannels: RecordingChannelsLayout?
    /// `inbound` / `outbound` records a single track; `both` (default) both.
    public var recordingTrack: RecordingTrack?
    public var playBeep: Bool?
    public var recordingStatusCallback: String?
    public var recordingStatusCallbackMethod: String?
    public var recordingStatusCallbackEvent: String?

    public init(
        recordingMaxDuration: Int? = nil,
        recordingChannels: RecordingChannelsLayout? = nil,
        recordingTrack: RecordingTrack? = nil,
        playBeep: Bool? = nil,
        recordingStatusCallback: String? = nil,
        recordingStatusCallbackMethod: String? = nil,
        recordingStatusCallbackEvent: String? = nil
    ) {
        self.recordingMaxDuration = recordingMaxDuration
        self.recordingChannels = recordingChannels
        self.recordingTrack = recordingTrack
        self.playBeep = playBeep
        self.recordingStatusCallback = recordingStatusCallback
        self.recordingStatusCallbackMethod = recordingStatusCallbackMethod
        self.recordingStatusCallbackEvent = recordingStatusCallbackEvent
    }

    func formFields() -> [FormField] {
        [
            FormField("RecordingMaxDuration", recordingMaxDuration),
            FormField("RecordingChannels", recordingChannels?.rawValue),
            FormField("RecordingTrack", recordingTrack?.rawValue),
            FormField("PlayBeep", playBeep),
            FormField("RecordingStatusCallback", recordingStatusCallback),
            FormField("RecordingStatusCallbackMethod", recordingStatusCallbackMethod),
            FormField("RecordingStatusCallbackEvent", recordingStatusCallbackEvent),
        ]
    }
}

/// Body for `POST /Conferences/{sid}/Recordings` — the conference variant declares only
/// the status-callback fields.
public struct StartConferenceRecordingRequest: Sendable {
    public var recordingStatusCallback: String?
    public var recordingStatusCallbackMethod: String?
    public var recordingStatusCallbackEvent: String?

    public init(
        recordingStatusCallback: String? = nil,
        recordingStatusCallbackMethod: String? = nil,
        recordingStatusCallbackEvent: String? = nil
    ) {
        self.recordingStatusCallback = recordingStatusCallback
        self.recordingStatusCallbackMethod = recordingStatusCallbackMethod
        self.recordingStatusCallbackEvent = recordingStatusCallbackEvent
    }

    func formFields() -> [FormField] {
        [
            FormField("RecordingStatusCallback", recordingStatusCallback),
            FormField("RecordingStatusCallbackMethod", recordingStatusCallbackMethod),
            FormField("RecordingStatusCallbackEvent", recordingStatusCallbackEvent),
        ]
    }
}

/// Body for `POST …/Recordings/{sid}` — pause/resume/stop a live recording.
public struct UpdateRecordingRequest: Sendable {
    public var status: RecordingUpdateStatus
    /// With `status=.paused`: `skip` leaves the paused span out; `silence` keeps it as
    /// silence (server default).
    public var pauseBehavior: PauseBehavior?

    public init(status: RecordingUpdateStatus, pauseBehavior: PauseBehavior? = nil) {
        self.status = status
        self.pauseBehavior = pauseBehavior
    }

    func formFields() -> [FormField] {
        [
            FormField("Status", status.rawValue),
            FormField("PauseBehavior", pauseBehavior?.rawValue),
        ]
    }
}

/// Result of `GET /Recordings/{sid}.wav` — the bytes after following any redirect,
/// which never carries credentials.
public struct RecordingAudio: Sendable {
    public var sid: String
    public var body: Data
    public var contentType: String
}
