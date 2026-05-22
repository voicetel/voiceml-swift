import Foundation

public final class ConferencesResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.joined(separator: "/")
    }

    public func list(_ params: ListConferencesParams = .init()) async throws -> ConferenceList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Conferences"),
            query: params.queryItems()
        ))
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
}
