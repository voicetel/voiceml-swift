import Foundation

public enum RecordingStatus: String, Codable, Sendable {
    case inProgress = "in-progress"
    case completed, failed, absent, paused, stopped, processing
}

public enum RecordingSource: String, Codable, Sendable {
    case outboundAPI = "OutboundAPI"
    case recordVerb = "RecordVerb"
    case dialVerb = "DialVerb"
    case conference = "Conference"
    case trunking = "Trunking"
    case startCallRecordingAPI = "StartCallRecordingAPI"
}

public enum RecordingUpdateStatus: String, Codable, Sendable {
    case stopped, paused
    case inProgress = "in-progress"
}

public struct Recording: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var callSid: String
    public var conferenceSid: String?
    public var status: RecordingStatus
    public var source: RecordingSource?
    public var channels: Int?
    public var duration: String?
    public var apiVersion: String?
    public var uri: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var startTime: String?
    public var price: String?
    public var priceUnit: String?
}

/// Recordings list response.
///
/// The account-scoped endpoint (`GET /Recordings`) returns the canonical Twilio fields
/// (`recordings/page/pageSize/total`). Per-call (`GET /Calls/{sid}/Recordings`) and
/// per-conference (`GET /Conferences/{sid}/Recordings`) endpoints currently return only
/// `recordings`; the pagination fields will be `nil`.
public struct RecordingList: Codable, Sendable {
    public var recordings: [Recording]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var numPages: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

public struct StartRecordingRequest: Sendable {
    public var recordingMaxDuration: Int?
    public var recordingChannels: RecordingChannelsLayout?
    public var playBeep: Bool?
    public var recordingStatusCallback: String?
    public var recordingStatusCallbackMethod: String?
    public var recordingStatusCallbackEvent: String?

    public init(
        recordingMaxDuration: Int? = nil,
        recordingChannels: RecordingChannelsLayout? = nil,
        playBeep: Bool? = nil,
        recordingStatusCallback: String? = nil,
        recordingStatusCallbackMethod: String? = nil,
        recordingStatusCallbackEvent: String? = nil
    ) {
        self.recordingMaxDuration = recordingMaxDuration
        self.recordingChannels = recordingChannels
        self.playBeep = playBeep
        self.recordingStatusCallback = recordingStatusCallback
        self.recordingStatusCallbackMethod = recordingStatusCallbackMethod
        self.recordingStatusCallbackEvent = recordingStatusCallbackEvent
    }

    func formFields() -> [FormField] {
        [
            FormField("RecordingMaxDuration", recordingMaxDuration),
            FormField("RecordingChannels", recordingChannels?.rawValue),
            FormField("PlayBeep", playBeep),
            FormField("RecordingStatusCallback", recordingStatusCallback),
            FormField("RecordingStatusCallbackMethod", recordingStatusCallbackMethod),
            FormField("RecordingStatusCallbackEvent", recordingStatusCallbackEvent),
        ]
    }
}

public struct UpdateRecordingRequest: Sendable {
    public var status: RecordingUpdateStatus

    public init(status: RecordingUpdateStatus) {
        self.status = status
    }

    func formFields() -> [FormField] {
        [FormField("Status", status.rawValue)]
    }
}

/// Result of `GET /Recordings/{sid}.wav` — the bytes after following any S3 redirect.
public struct RecordingAudio: Sendable {
    public var sid: String
    public var body: Data
    public var contentType: String
}
