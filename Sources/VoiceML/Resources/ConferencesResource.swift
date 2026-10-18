import Foundation

public final class ConferencesResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(parts)
    }

    public func list(_ params: ListConferencesParams = .init()) async throws -> ConferenceList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Conferences"),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: ConferenceList) async throws -> ConferenceList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    /// Walk every page of `/Conferences` matching the supplied filters and yield each
    /// ``Conference``. Lazily follows each page's `next_page_uri`.
    public func iterate(_ params: ListConferencesParams = .init()) -> PagerSequence<Conference> {
        PagerSequence(
            firstPage: { [self] in
                let page = try await list(params)
                return PageResult(items: page.conferences, nextURL: transport.resolvePageURI(page.nextPageUri))
            },
            followPage: { [self] url in
                let page: ConferenceList = try await transport.requestPage(url)
                return PageResult(items: page.conferences, nextURL: transport.resolvePageURI(page.nextPageUri))
            }
        )
    }

    public func get(_ conferenceSid: String) async throws -> Conference {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Conferences", conferenceSid)
        ))
    }

    public func end(
        conferenceSid: String,
        body: EndConferenceRequest = .init()
    ) async throws -> Conference {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Conferences", conferenceSid),
            form: body.formFields()
        ))
    }

    // MARK: - Participants

    public func listParticipants(
        conferenceSid: String,
        params: ListParticipantsParams = .init()
    ) async throws -> ParticipantList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Conferences", conferenceSid, "Participants"),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: ParticipantList) async throws -> ParticipantList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    public func getParticipant(conferenceSid: String, callSid: String) async throws -> Participant {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Conferences", conferenceSid, "Participants", callSid)
        ))
    }

    public func updateParticipant(
        conferenceSid: String,
        callSid: String,
        body: UpdateParticipantRequest
    ) async throws -> Participant {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Conferences", conferenceSid, "Participants", callSid),
            form: body.formFields()
        ))
    }

    public func kickParticipant(conferenceSid: String, callSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("Conferences", conferenceSid, "Participants", callSid)
        ))
    }

    /// Dial a leg into a conference. `POST /Conferences/{sid}/Participants`.
    public func createParticipant(
        conferenceSid: String,
        body: CreateParticipantRequest
    ) async throws -> Participant {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Conferences", conferenceSid, "Participants"),
            form: body.formFields()
        ))
    }

    // MARK: - Recordings

    public func listRecordings(
        conferenceSid: String,
        params: ListCallRecordingsParams = .init()
    ) async throws -> RecordingList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Conferences", conferenceSid, "Recordings"),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: RecordingList) async throws -> RecordingList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    /// `POST /Conferences/{sid}/Recordings` — begin a fresh recording on the live
    /// conference. Returns the running recording if one already exists.
    public func startRecording(
        conferenceSid: String,
        body: StartConferenceRecordingRequest = .init()
    ) async throws -> Recording {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Conferences", conferenceSid, "Recordings"),
            form: body.formFields()
        ))
    }

    public func getRecording(conferenceSid: String, recordingSid: String) async throws -> Recording {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Conferences", conferenceSid, "Recordings", recordingSid)
        ))
    }

    public func updateRecording(
        conferenceSid: String,
        recordingSid: String,
        body: UpdateRecordingRequest
    ) async throws -> Recording {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Conferences", conferenceSid, "Recordings", recordingSid),
            form: body.formFields()
        ))
    }

    public func deleteRecording(conferenceSid: String, recordingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("Conferences", conferenceSid, "Recordings", recordingSid)
        ))
    }
}
