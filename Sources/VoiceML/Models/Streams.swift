import Foundation

/// Live media-stream status. Open enum.
public struct StreamStatus: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let inProgress = StreamStatus(rawValue: "in-progress")
    public static let stopped = StreamStatus(rawValue: "stopped")
}

public struct Stream: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var callSid: String?
    public var name: String?
    public var status: StreamStatus?
    public var apiVersion: String?
    public var uri: String?
    public var dateCreated: String?
    public var dateUpdated: String?
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
