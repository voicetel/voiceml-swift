import Foundation

/// Twilio-compatible post-recording transcription — distinct from the live
/// `CallTranscription` modelled in `Transcriptions.swift` (which is the
/// realtime `/Calls/{sid}/Transcription` resource).
///
/// `/Recordings/{sid}/Transcriptions/{sid}.json` and
/// `/Transcriptions/{sid}.json` both decode into this shape. Modelled for
/// fixture-driven conformance; the SDK doesn't currently surface a
/// recording-transcriptions resource client.
public struct RecordingTranscription: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var recordingSid: String
    public var apiVersion: String?
    public var status: String?
    /// Twilio returns the transcribed text inline; can be null when the
    /// transcription is still in progress or has been redacted.
    public var transcriptionText: String?
    public var type: String?
    public var duration: String?
    public var price: String?
    public var priceUnit: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

/// Envelope for `GET /Recordings/{sid}/Transcriptions.json` and
/// `GET /Transcriptions.json`. Both endpoints serialize items under the
/// `transcriptions` key.
public struct RecordingTranscriptionList: Codable, Sendable {
    public var transcriptions: [RecordingTranscription]
    public var page: Int?
    public var pageSize: Int?
    public var numPages: Int?
    public var total: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}
