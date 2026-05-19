import Foundation

public final class ApplicationsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.joined(separator: "/")
    }

    public func create(_ body: CreateApplicationRequest) async throws -> Application {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Applications"),
            form: body.formFields()
        ))
    }

    public func list() async throws -> ApplicationList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("Applications")))
    }

    public func get(_ applicationSid: String) async throws -> Application {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Applications", applicationSid)
        ))
    }

    public func update(
        applicationSid: String,
        body: UpdateApplicationRequest
    ) async throws -> Application {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Applications", applicationSid),
            form: body.formFields()
        ))
    }

    public func delete(_ applicationSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("Applications", applicationSid)
        ))
    }
}
