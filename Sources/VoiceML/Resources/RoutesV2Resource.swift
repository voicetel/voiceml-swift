import Foundation

/// `client.routesV2` — Twilio routes/v2 Inbound Processing Region API.
public final class RoutesV2Resource: Sendable {
    public let sipDomains: RoutesV2SipDomainsResource

    init(transport: Transport) {
        self.sipDomains = RoutesV2SipDomainsResource(transport: transport)
    }
}

/// Operations on `/v2/SipDomains/{SipDomain}`. Keyed by SIP domain name —
/// the account is resolved from HTTP Basic auth, so `/v2/` paths bypass
/// `/2010-04-01/Accounts/{Sid}/`.
public final class RoutesV2SipDomainsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func fetch(domainName: String) async throws -> RoutesV2SipDomain {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v2/SipDomains/\(domainName)"))
    }

    public func update(domainName: String, _ body: UpdateRoutesV2SipDomainRequest) async throws -> RoutesV2SipDomain {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v2/SipDomains/\(domainName)", form: body.formFields()))
    }
}
