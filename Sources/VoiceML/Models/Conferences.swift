import Foundation

/// Conference lifecycle status. Open enum.
public struct ConferenceStatus: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let initStatus = ConferenceStatus(rawValue: "init")
    public static let inProgress = ConferenceStatus(rawValue: "in-progress")
    public static let completed = ConferenceStatus(rawValue: "completed")
}

/// Participant lifecycle status. Open enum.
public struct ParticipantStatus: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let queued = ParticipantStatus(rawValue: "queued")
    public static let connecting = ParticipantStatus(rawValue: "connecting")
    public static let ringing = ParticipantStatus(rawValue: "ringing")
    public static let connected = ParticipantStatus(rawValue: "connected")
    public static let onHold = ParticipantStatus(rawValue: "on-hold")
    public static let complete = ParticipantStatus(rawValue: "complete")
    public static let failed = ParticipantStatus(rawValue: "failed")
    public static let completed = ParticipantStatus(rawValue: "completed")
}

public struct Conference: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var friendlyName: String?
    public var status: ConferenceStatus?
    public var region: String?
    public var apiVersion: String?
    public var uri: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var reasonConferenceEnded: String?
    public var callSidEndingConference: String?
    public var subresourceUris: [String: String]?
    /// VoiceML extension — count of current participants.
    public var memberCount: Int?
}

public struct ConferenceList: Codable, Sendable {
    public var conferences: [Conference]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

public struct Participant: Codable, Sendable {
    public var callSid: String?
    public var conferenceSid: String?
    public var accountSid: String?
    public var muted: Bool?
    public var hold: Bool?
    public var coaching: Bool?
    public var callSidToCoach: String?
    public var queueTime: String?
    public var startConferenceOnEnter: Bool?
    public var endConferenceOnExit: Bool?
    public var status: ParticipantStatus?
    public var label: String?
    public var apiVersion: String?
    public var uri: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct ParticipantList: Codable, Sendable {
    public var participants: [Participant]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// v1 supports only `Status=completed`.
public struct EndConferenceRequest: Sendable {
    public var status: String

    public init(status: String = "completed") {
        self.status = status
    }

    func formFields() -> [FormField] {
        [FormField("Status", status)]
    }
}

/// At least one of `muted` / `hold` must be set.
public struct UpdateParticipantRequest: Sendable {
    public var muted: Bool?
    public var hold: Bool?

    public init(muted: Bool? = nil, hold: Bool? = nil) {
        self.muted = muted
        self.hold = hold
    }

    func formFields() -> [FormField] {
        [
            FormField("Muted", muted),
            FormField("Hold", hold),
        ]
    }
}

/// Filter parameters for `GET /Conferences`.
public struct ListConferencesParams: Sendable {
    public var friendlyName: String?
    public var status: ConferenceStatus?
    public var dateCreated: String?
    public var dateCreatedLt: String?
    public var dateCreatedGt: String?
    public var dateUpdated: String?
    public var dateUpdatedLt: String?
    public var dateUpdatedGt: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        friendlyName: String? = nil,
        status: ConferenceStatus? = nil,
        dateCreated: String? = nil,
        dateCreatedLt: String? = nil,
        dateCreatedGt: String? = nil,
        dateUpdated: String? = nil,
        dateUpdatedLt: String? = nil,
        dateUpdatedGt: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.friendlyName = friendlyName
        self.status = status
        self.dateCreated = dateCreated
        self.dateCreatedLt = dateCreatedLt
        self.dateCreatedGt = dateCreatedGt
        self.dateUpdated = dateUpdated
        self.dateUpdatedLt = dateUpdatedLt
        self.dateUpdatedGt = dateUpdatedGt
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("FriendlyName", friendlyName),
            QueryItem("Status", status?.rawValue),
            QueryItem("DateCreated", dateCreated),
            QueryItem("DateCreated<", dateCreatedLt),
            QueryItem("DateCreated>", dateCreatedGt),
            QueryItem("DateUpdated", dateUpdated),
            QueryItem("DateUpdated<", dateUpdatedLt),
            QueryItem("DateUpdated>", dateUpdatedGt),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Filter parameters for `GET /Conferences/{sid}/Participants`.
public struct ListParticipantsParams: Sendable {
    public var muted: Bool?
    public var hold: Bool?
    public var coaching: Bool?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        muted: Bool? = nil,
        hold: Bool? = nil,
        coaching: Bool? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.muted = muted
        self.hold = hold
        self.coaching = coaching
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("Muted", muted.map { $0 ? "true" : "false" }),
            QueryItem("Hold", hold.map { $0 ? "true" : "false" }),
            QueryItem("Coaching", coaching.map { $0 ? "true" : "false" }),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Body for `POST /Conferences/{sid}/Participants`. `from` and `to` are required.
public struct CreateParticipantRequest: Sendable {
    public var from: String
    public var to: String
    public var label: String?
    public var muted: Bool?
    public var startConferenceOnEnter: Bool?
    public var endConferenceOnExit: Bool?
    public var timeout: Int?
    public var statusCallback: String?
    public var statusCallbackMethod: String?
    public var statusCallbackEvent: String?
    /// Participant's conference lifecycle webhook.
    public var conferenceStatusCallback: String?
    public var conferenceStatusCallbackMethod: HttpMethod?
    /// Space- or comma-separated conference event filter (default `start end`).
    public var conferenceStatusCallbackEvent: String?

    public init(
        from: String,
        to: String,
        label: String? = nil,
        muted: Bool? = nil,
        startConferenceOnEnter: Bool? = nil,
        endConferenceOnExit: Bool? = nil,
        timeout: Int? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: String? = nil,
        statusCallbackEvent: String? = nil,
        conferenceStatusCallback: String? = nil,
        conferenceStatusCallbackMethod: HttpMethod? = nil,
        conferenceStatusCallbackEvent: String? = nil
    ) {
        self.from = from
        self.to = to
        self.label = label
        self.muted = muted
        self.startConferenceOnEnter = startConferenceOnEnter
        self.endConferenceOnExit = endConferenceOnExit
        self.timeout = timeout
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
        self.statusCallbackEvent = statusCallbackEvent
        self.conferenceStatusCallback = conferenceStatusCallback
        self.conferenceStatusCallbackMethod = conferenceStatusCallbackMethod
        self.conferenceStatusCallbackEvent = conferenceStatusCallbackEvent
    }

    func formFields() -> [FormField] {
        [
            FormField("From", from),
            FormField("To", to),
            FormField("Label", label),
            FormField("Muted", muted),
            FormField("StartConferenceOnEnter", startConferenceOnEnter),
            FormField("EndConferenceOnExit", endConferenceOnExit),
            FormField("Timeout", timeout),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod),
            FormField("StatusCallbackEvent", statusCallbackEvent),
            FormField("ConferenceStatusCallback", conferenceStatusCallback),
            FormField("ConferenceStatusCallbackMethod", conferenceStatusCallbackMethod?.rawValue),
            FormField("ConferenceStatusCallbackEvent", conferenceStatusCallbackEvent),
        ]
    }
}
