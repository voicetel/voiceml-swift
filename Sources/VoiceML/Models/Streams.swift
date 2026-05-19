import Foundation

public enum StreamStatus: String, Codable, Sendable {
    case inProgress = "in-progress"
    case stopped
}

public struct Stream: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var callSid: String
    public var name: String?
    public var status: StreamStatus
    public var apiVersion: String
    public var uri: String
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct StreamList: Codable, Sendable {
    public var streams: [Stream]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var uri: String?
}

public struct StartStreamRequest: Sendable {
    public var url: String
    public var track: TrackSelector?
    public var name: String?
    public var statusCallback: String?
    public var statusCallbackMethod: String?

    public init(
        url: String,
        track: TrackSelector? = nil,
        name: String? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: String? = nil
    ) {
        self.url = url
        self.track = track
        self.name = name
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("Url", url),
            FormField("Track", track?.rawValue),
            FormField("Name", name),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod),
        ]
    }
}

public struct StopStreamRequest: Sendable {
    public var status: String

    public init(status: String = "stopped") {
        self.status = status
    }

    func formFields() -> [FormField] {
        [FormField("Status", status)]
    }
}
