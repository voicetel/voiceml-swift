import Foundation

public final class ApplicationsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(parts)
    }

    public func create(_ body: CreateApplicationRequest) async throws -> Application {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path("Applications"),
            form: body.formFields()
        ))
    }

    public func list(_ params: ListApplicationsParams = .init()) async throws -> ApplicationList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Applications"),
            query: params.queryItems()
        ))
    }

    public func get(_ applicationSid: String) async throws -> Application {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Applications", applicationSid)
        ))
    }

    public func update(
        applicationSid: String,
        body: UpdateApplicationRequest
    ) async throws -> Application {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path("Applications", applicationSid),
            form: body.formFields()
        ))
    }

    public func delete(_ applicationSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: try path("Applications", applicationSid)
        ))
    }
}
