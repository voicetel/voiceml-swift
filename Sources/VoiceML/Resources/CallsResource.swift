import Foundation

/// `/Calls/…` family — includes per-call sub-resources (recordings, streams, siprec,
/// transcriptions, notifications, events).
public final class CallsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Build a path under `/2010-04-01/Accounts/{AccountSid}/…` from validated,
    /// individually percent-encoded segments.
    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(parts)
    }

    // MARK: - Calls

    public func list(_ params: ListCallsParams = .init()) async throws -> CallList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls"),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    /// Returns nil when the page carries no further link.
    public func nextPage(of page: CallList) async throws -> CallList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    /// Walk every page of `/Calls` matching the supplied filters and yield each ``Call``.
    /// Lazily follows each page's `next_page_uri`; abandoning the sequence stops all
    /// further requests.
    public func iterate(_ params: ListCallsParams = .init()) -> PagerSequence<Call> {
        PagerSequence(
            firstPage: { [self] in
                let page = try await list(params)
                return PageResult(items: page.calls, nextURL: transport.resolvePageURI(page.nextPageUri))
            },
            followPage: { [self] url in
                let page: CallList = try await transport.requestPage(url)
                return PageResult(items: page.calls, nextURL: transport.resolvePageURI(page.nextPageUri))
            }
        )
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

    public func listRecordings(
        callSid: String,
        params: ListCallRecordingsParams = .init()
    ) async throws -> RecordingList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Recordings"),
            query: params.queryItems()
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

    // MARK: - Streams (start/stop only — the list/fetch GETs were removed from the
    // API surface; the server answers 405/20004 for them)

    public func startStream(callSid: String, body: StartStreamRequest) async throws -> Stream {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Streams"),
            form: body.formFields()
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

    // MARK: - SIPREC (start/stop only)

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

    // MARK: - Transcriptions (start/stop only)

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

    // MARK: - Notifications / Events

    public func listNotifications(
        callSid: String,
        params: ListNotificationsParams = .init()
    ) async throws -> NotificationsList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Notifications"),
            query: params.queryItems()
        ))
    }

    /// Fetch a per-call notification by sid.
    public func getNotification(
        callSid: String,
        notificationSid: String
    ) async throws -> Notification {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Notifications", notificationSid)
        ))
    }

    public func listEvents(
        callSid: String,
        params: ListPageParams = .init()
    ) async throws -> EventsList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Calls", callSid, "Events"),
            query: params.queryItems()
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

    // MARK: - Payments

    /// `POST /Calls/{callSid}/Payments` — begin a `<Pay>` session on the live call.
    /// Returns 201 with the freshly-minted ``CallPayment``. Returns 403 when the tenant
    /// is not `pay_enabled` or has no `stripe_secret_key` configured.
    public func startPayment(
        callSid: String,
        _ req: StartPaymentRequest = .init()
    ) async throws -> CallPayment {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Payments"),
            form: req.formFields()
        ))
    }

    /// `POST /Calls/{callSid}/Payments/{paymentSid}` — advance or terminate an existing
    /// Pay session. `status=.complete` captures the collected fields; `status=.cancel`
    /// aborts the session. `capture=…` tells the runtime which input the user is about
    /// to type next.
    public func updatePayment(
        callSid: String,
        paymentSid: String,
        _ req: UpdatePaymentRequest
    ) async throws -> CallPayment {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Calls", callSid, "Payments", paymentSid),
            form: req.formFields()
        ))
    }
}
