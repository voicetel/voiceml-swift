import Foundation

/// `/IncomingPhoneNumbers/…` family — DIDs assigned to the authenticated tenant.
///
/// Mirrors Twilio's `IncomingPhoneNumber` resource (list / create / fetch / update /
/// delete). Tenant-scoped: numbers belonging to a different account 404 with the same
/// shape as nonexistent numbers (no enumeration leak).
public final class IncomingPhoneNumbersResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.joined(separator: "/")
    }

    /// `GET /IncomingPhoneNumbers.json` — list assigned DIDs.
    public func list(
        _ params: ListIncomingPhoneNumbersParams = .init()
    ) async throws -> IncomingPhoneNumberList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("IncomingPhoneNumbers"),
            query: params.queryItems()
        ))
    }

    /// `POST /IncomingPhoneNumbers.json` — assign a DID. Idempotent for the same tenant;
    /// 409 if already claimed by a different account.
    public func create(
        _ params: CreateIncomingPhoneNumberParams
    ) async throws -> IncomingPhoneNumber {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("IncomingPhoneNumbers"),
            form: params.formFields()
        ))
    }

    /// `GET /IncomingPhoneNumbers/{Sid}.json` — fetch a single DID by sid.
    public func get(_ sid: String) async throws -> IncomingPhoneNumber {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("IncomingPhoneNumbers", sid)
        ))
    }

    /// `POST /IncomingPhoneNumbers/{Sid}.json` — update voice routing.
    /// Only-set-fields-touched semantics; `nil` params are omitted from the body.
    public func update(
        _ sid: String,
        _ params: UpdateIncomingPhoneNumberParams
    ) async throws -> IncomingPhoneNumber {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("IncomingPhoneNumbers", sid),
            form: params.formFields()
        ))
    }

    /// `DELETE /IncomingPhoneNumbers/{Sid}.json` — release the DID. Idempotent: 204
    /// on success OR if the number was already gone.
    public func delete(_ sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("IncomingPhoneNumbers", sid)
        ))
    }
}
