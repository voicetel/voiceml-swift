import Foundation

/// SIPREC session status. Open enum.
public struct SiprecStatus: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let inProgress = SiprecStatus(rawValue: "in-progress")
    public static let stopped = SiprecStatus(rawValue: "stopped")
}

public struct SiprecSession: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var callSid: String?
    public var name: String?
    public var connectorName: String?
    public var status: SiprecStatus?
    public var apiVersion: String?
    public var uri: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct StartSiprecRequest: Sendable {
    public var name: String?
    /// mod_siprec profile name. Empty falls back to `SIPREC_DEFAULT_PROFILE`, then `default`.
    public var connectorName: String?
    public var track: TrackSelector?
    public var statusCallback: String?
    public var statusCallbackMethod: String?

    public init(
        name: String? = nil,
        connectorName: String? = nil,
        track: TrackSelector? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: String? = nil
    ) {
        self.name = name
        self.connectorName = connectorName
        self.track = track
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("Name", name),
            FormField("ConnectorName", connectorName),
            FormField("Track", track?.rawValue),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod),
        ]
    }
}

/// Body for `POST /Calls/{sid}/Siprec/{sid}` — clears VoiceML's session tracking only.
/// The SRS recording itself continues until call hangup (documented mod_siprec limitation).
public struct StopSiprecRequest: Sendable {
    public var status: String

    public init(status: String = "stopped") {
        self.status = status
    }

    func formFields() -> [FormField] {
        [FormField("Status", status)]
    }
}
