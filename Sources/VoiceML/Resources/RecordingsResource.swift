import Foundation

public final class RecordingsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.joined(separator: "/")
    }

    public func list(_ params: ListRecordingsParams = .init()) async throws -> RecordingList {
        return try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Recordings"),
            query: params.queryItems()
        ))
    }

    public func iterate(_ params: ListRecordingsParams = .init()) -> AsyncThrowingStream<Recording, Error> {
        var current = params
        if current.page == nil { current.page = 0 }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    while true {
                        let chunk = try await self.list(current)
                        for item in chunk.recordings { continuation.yield(item) }
                        if chunk.nextPageUri == nil || chunk.nextPageUri?.isEmpty == true || chunk.recordings.isEmpty {
                            continuation.finish()
                            return
                        }
                        current.page = (current.page ?? 0) + 1
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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

    /// Fetch the WAV audio for a recording. Three server delivery shapes are flattened by
    /// following any 302 redirect to S3:
    ///   - 200 OK: local file present.
    ///   - 302 Found: archived to S3; URLSession follows the presigned URL automatically.
    ///   - 410 Gone: local file gone AND no S3 key. Throws ``GoneError``.
    public func getAudio(recordingSid: String) async throws -> RecordingAudio {
        let p = path("Recordings", recordingSid) + ".wav"
        let (body, response) = try await transport.fetchBytes(path: p)
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
        return RecordingAudio(sid: recordingSid, body: body, contentType: contentType)
    }

    public func delete(_ recordingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("Recordings", recordingSid)
        ))
    }
}
