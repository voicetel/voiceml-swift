import Foundation

public enum ConferenceStatus: String, Codable, Sendable {
    case `init`
    case inProgress = "in-progress"
    case completed
}

public enum ParticipantStatus: String, Codable, Sendable {
    case queued, connecting, ringing, connected
    case onHold = "on-hold"
    case complete, failed, completed
}

public struct Conference: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String?
    public var status: ConferenceStatus
    public var region: String?
    public var apiVersion: String
    public var uri: String
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
    public var total: Int?
    public var nextPageUri: String?
    public var uri: String?
}

public struct Participant: Codable, Sendable {
    public var callSid: String
    public var conferenceSid: String
    public var accountSid: String
    public var muted: Bool
    public var hold: Bool
    public var coaching: Bool
    public var callSidToCoach: String?
    public var queueTime: String?
    public var startConferenceOnEnter: Bool
    public var endConferenceOnExit: Bool
    public var status: ParticipantStatus
    public var label: String?
    public var apiVersion: String?
    public var uri: String
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct ParticipantList: Codable, Sendable {
    public var participants: [Participant]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
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
        statusCallbackEvent: String? = nil
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
        ]
    }
}
