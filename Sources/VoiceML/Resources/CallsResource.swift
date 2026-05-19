import Foundation

/// `/Calls/…` family — includes per-call sub-resources (recordings, streams, siprec,
/// transcriptions, notifications, events).
public final class CallsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Build a URL under `/2010-04-01/Accounts/{AccountSid}/…`.
    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.filter { !$0.isEmpty }.joined(separator: "/")
    }

    // MARK: - Calls

    public func list(_ params: ListCallsParams = .init()) async throws -> CallList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls"),
            query: params.queryItems()
        ))
    }

    public func create(_ body: CreateCallRequest) async throws -> Call {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls"),
            form: body.formFields()
        ))
    }

    public func get(_ callSid: String) async throws -> Call {
        try await transport.request(VoiceMLRequest(method: .get, path: path("Calls", callSid)))
    }

    public func update(callSid: String, body: UpdateCallRequest) async throws -> Call {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid),
            form: body.formFields()
        ))
    }

    public func delete(_ callSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("Calls", callSid)))
    }

    // MARK: - Recordings (call-scoped)

    public func listRecordings(callSid: String) async throws -> RecordingList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Recordings")
        ))
    }

    public func startRecording(
        callSid: String,
        body: StartRecordingRequest = .init()
    ) async throws -> Recording {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Recordings"),
            form: body.formFields()
        ))
    }

    public func getRecording(callSid: String, recordingSid: String) async throws -> Recording {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Recordings", recordingSid)
        ))
    }

    public func updateRecording(
        callSid: String,
        recordingSid: String,
        body: UpdateRecordingRequest
    ) async throws -> Recording {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Recordings", recordingSid),
            form: body.formFields()
        ))
    }

    public func deleteRecording(callSid: String, recordingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("Calls", callSid, "Recordings", recordingSid)
        ))
    }

    // MARK: - Streams

    public func listStreams(callSid: String) async throws -> StreamList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Streams")
        ))
    }

    public func startStream(callSid: String, body: StartStreamRequest) async throws -> Stream {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Streams"),
            form: body.formFields()
        ))
    }

    public func getStream(callSid: String, streamSid: String) async throws -> Stream {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Streams", streamSid)
        ))
    }

    public func stopStream(
        callSid: String,
        streamSid: String,
        body: StopStreamRequest = .init()
    ) async throws -> Stream {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Streams", streamSid),
            form: body.formFields()
        ))
    }

    // MARK: - SIPREC

    public func listSiprec(callSid: String) async throws -> SiprecList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Siprec")
        ))
    }

    public func startSiprec(
        callSid: String,
        body: StartSiprecRequest = .init()
    ) async throws -> SiprecSession {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Siprec"),
            form: body.formFields()
        ))
    }

    public func getSiprec(callSid: String, siprecSid: String) async throws -> SiprecSession {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Siprec", siprecSid)
        ))
    }

    public func stopSiprec(
        callSid: String,
        siprecSid: String,
        body: StopSiprecRequest = .init()
    ) async throws -> SiprecSession {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Siprec", siprecSid),
            form: body.formFields()
        ))
    }

    // MARK: - Transcriptions

    public func listTranscriptions(callSid: String) async throws -> TranscriptionList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Transcriptions")
        ))
    }

    public func startTranscription(
        callSid: String,
        body: StartTranscriptionRequest = .init()
    ) async throws -> CallTranscription {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Transcriptions"),
            form: body.formFields()
        ))
    }

    public func getTranscription(
        callSid: String,
        transcriptionSid: String
    ) async throws -> CallTranscription {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Transcriptions", transcriptionSid)
        ))
    }

    public func stopTranscription(
        callSid: String,
        transcriptionSid: String,
        body: StopTranscriptionRequest = .init()
    ) async throws -> CallTranscription {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Transcriptions", transcriptionSid),
            form: body.formFields()
        ))
    }

    // MARK: - Notifications / Events (compat stubs)

    public func listNotifications(callSid: String) async throws -> NotificationsList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Notifications")
        ))
    }

    public func listEvents(callSid: String) async throws -> EventsList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Events")
        ))
    }

    /// `POST /Calls/{sid}/UserDefinedMessages` — server returns 501 (`NotImplementedAPIError`).
    /// Mounted for API completeness so consumers get a clean exception rather than discovering
    /// the gap at runtime.
    public func sendUserDefinedMessage(
        callSid: String,
        payload: [String: String] = [:]
    ) async throws {
        let fields = payload.map { FormField($0.key, $0.value) }
        try await transport.requestVoid(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "UserDefinedMessages"),
            form: fields
        ))
    }
}
