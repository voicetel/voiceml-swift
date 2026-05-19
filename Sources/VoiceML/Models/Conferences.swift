import Foundation

public enum ConferenceStatus: String, Codable, Sendable {
    case inProgress = "in-progress"
    case completed
}

public enum ParticipantStatus: String, Codable, Sendable {
    case queued, connecting, ringing, connected
    case onHold = "on-hold"
    case completed
}

public struct Conference: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String
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
    public var startConferenceOnEnter: Bool
    public var endConferenceOnExit: Bool
    public var status: ParticipantStatus
    public var label: String?
    public var apiVersion: String
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
