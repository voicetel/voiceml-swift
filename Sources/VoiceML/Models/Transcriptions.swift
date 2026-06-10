import Foundation

public enum TranscriptionStatus: String, Codable, Sendable {
    case inProgress = "in-progress"
    case stopped
}

public enum TranscriptionEngine: String, Codable, Sendable {
    case deepgram, google, aws, azure
}

public struct CallTranscription: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var callSid: String
    public var name: String?
    public var languageCode: String?
    public var transcriptionEngine: TranscriptionEngine?
    public var status: TranscriptionStatus
    // Twilio's documented Create/Update RealtimeTranscription responses
    // omit api_version (only the LIST envelope items carry it). Optional
    // to match.
    public var apiVersion: String?
    public var uri: String
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct TranscriptionList: Codable, Sendable {
    public var transcriptions: [CallTranscription]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var uri: String?
}

public struct StartTranscriptionRequest: Sendable {
    public var name: String?
    public var track: TrackSelector?
    public var languageCode: String?
    public var transcriptionEngine: TranscriptionEngine?
    public var profanityFilter: Bool?
    public var partialResults: Bool?
    public var hints: String?
    public var statusCallback: String?
    public var statusCallbackMethod: String?
    public var statusCallbackEvents: String?

    public init(
        name: String? = nil,
        track: TrackSelector? = nil,
        languageCode: String? = nil,
        transcriptionEngine: TranscriptionEngine? = nil,
        profanityFilter: Bool? = nil,
        partialResults: Bool? = nil,
        hints: String? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: String? = nil,
        statusCallbackEvents: String? = nil
    ) {
        self.name = name
        self.track = track
        self.languageCode = languageCode
        self.transcriptionEngine = transcriptionEngine
        self.profanityFilter = profanityFilter
        self.partialResults = partialResults
        self.hints = hints
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
        self.statusCallbackEvents = statusCallbackEvents
    }

    func formFields() -> [FormField] {
        [
            FormField("Name", name),
            FormField("Track", track?.rawValue),
            FormField("LanguageCode", languageCode),
            FormField("TranscriptionEngine", transcriptionEngine?.rawValue),
            FormField("ProfanityFilter", profanityFilter),
            FormField("PartialResults", partialResults),
            FormField("Hints", hints),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod),
            FormField("StatusCallbackEvents", statusCallbackEvents),
        ]
    }
}

public struct StopTranscriptionRequest: Sendable {
    public var status: String

    public init(status: String = "stopped") {
        self.status = status
    }

    func formFields() -> [FormField] {
        [FormField("Status", status)]
    }
}
