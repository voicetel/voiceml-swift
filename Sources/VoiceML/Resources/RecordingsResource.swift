import Foundation

public final class RecordingsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(parts)
    }

    public func list(_ params: ListRecordingsParams = .init()) async throws -> RecordingList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Recordings"),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: RecordingList) async throws -> RecordingList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    /// Walk every page of `/Recordings` matching the supplied filters and yield each
    /// ``Recording``. Lazily follows each page's `next_page_uri`.
    public func iterate(_ params: ListRecordingsParams = .init()) -> PagerSequence<Recording> {
        PagerSequence(
            firstPage: { [self] in
                let page = try await list(params)
                return PageResult(items: page.recordings, nextURL: transport.resolvePageURI(page.nextPageUri))
            },
            followPage: { [self] url in
                let page: RecordingList = try await transport.requestPage(url)
                return PageResult(items: page.recordings, nextURL: transport.resolvePageURI(page.nextPageUri))
            }
        )
    }

    public func get(
        _ recordingSid: String,
        params: GetRecordingParams = .init()
    ) async throws -> Recording {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Recordings", recordingSid),
            query: params.queryItems()
        ))
    }

    /// Fetch the WAV audio for a recording. Three server delivery shapes are handled by
    /// following any redirect manually — the redirect leg never carries credentials:
    ///   - 200 OK: local file present.
    ///   - 302 Found: archived to S3; the SDK re-issues a fresh unauthenticated GET to
    ///     the presigned `Location` (https only).
    ///   - 410 Gone: local file gone AND no S3 key. Throws ``GoneError``.
    public func getAudio(recordingSid: String) async throws -> RecordingAudio {
        let p = try transport.accountPath(["Recordings", recordingSid], suffix: ".wav")
        let (body, response) = try await transport.fetchBytes(path: p, jsonSuffix: false)
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
        return RecordingAudio(sid: recordingSid, body: body, contentType: contentType)
    }

    public func delete(_ recordingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("Recordings", recordingSid)
        ))
    }

    // MARK: - Recording transcriptions

    /// Transcription scope for one recording: `client.recordings.transcriptions(recordingSid:)`.
    public func transcriptions(recordingSid: String) -> RecordingTranscriptionsResource {
        RecordingTranscriptionsResource(transport: transport, recordingSid: recordingSid)
    }
}

/// `/Recordings/{RecordingSid}/Transcriptions/…` — post-recording transcriptions.
public final class RecordingTranscriptionsResource: Sendable {
    private let transport: Transport
    private let recordingSid: String

    init(transport: Transport, recordingSid: String) {
        self.transport = transport
        self.recordingSid = recordingSid
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(["Recordings", recordingSid, "Transcriptions"] + parts)
    }

    public func list(_ params: ListTranscriptionsParams = .init()) async throws -> TranscriptionPageList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path(),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: TranscriptionPageList) async throws -> TranscriptionPageList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    public func fetch(sid: String) async throws -> Transcription {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path(sid)
        ))
    }

    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path(sid)
        ))
    }
}
