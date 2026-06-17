import Foundation

/// `client.sip.*` — top-level SIP Trunking holder.
public final class SipResource: Sendable {
    public let domains: SipDomainsResource
    public let credentialLists: SipCredentialListsResource
    public let ipAccessControlLists: SipIpAccessControlListsResource

    init(transport: Transport) {
        self.domains = SipDomainsResource(transport: transport)
        self.credentialLists = SipCredentialListsResource(transport: transport)
        self.ipAccessControlLists = SipIpAccessControlListsResource(transport: transport)
    }
}

/// `/SIP/Domains` + the four mapping endpoints.
public final class SipDomainsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.filter { !$0.isEmpty }.joined(separator: "/")
    }

    // --- CRUD ---
    public func list(_ params: ListSipPageParams = .init()) async throws -> SipDomainList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains"), query: params.queryItems()))
    }

    public func create(_ body: CreateSipDomainRequest) async throws -> SipDomain {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "Domains"), form: body.formFields()))
    }

    public func fetch(sid: String) async throws -> SipDomain {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", sid)))
    }

    public func update(sid: String, _ body: UpdateSipDomainRequest) async throws -> SipDomain {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "Domains", sid), form: body.formFields()))
    }

    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "Domains", sid)))
    }

    // --- Historical CredentialList mappings ---
    public func listCredentialListMappings(domainSid: String, _ params: ListSipPageParams = .init()) async throws -> SipCredentialListMappingList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "CredentialListMappings"), query: params.queryItems()))
    }
    public func createCredentialListMapping(domainSid: String, _ body: CreateSipCredentialListMappingRequest) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "Domains", domainSid, "CredentialListMappings"), form: body.formFields()))
    }
    public func fetchCredentialListMapping(domainSid: String, mappingSid: String) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "CredentialListMappings", mappingSid)))
    }
    public func deleteCredentialListMapping(domainSid: String, mappingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "Domains", domainSid, "CredentialListMappings", mappingSid)))
    }

    // --- Historical IpAccessControlList mappings ---
    public func listIpAccessControlListMappings(domainSid: String, _ params: ListSipPageParams = .init()) async throws -> SipIpAccessControlListMappingList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "IpAccessControlListMappings"), query: params.queryItems()))
    }
    public func createIpAccessControlListMapping(domainSid: String, _ body: CreateSipIpAccessControlListMappingRequest) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "Domains", domainSid, "IpAccessControlListMappings"), form: body.formFields()))
    }
    public func fetchIpAccessControlListMapping(domainSid: String, mappingSid: String) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "IpAccessControlListMappings", mappingSid)))
    }
    public func deleteIpAccessControlListMapping(domainSid: String, mappingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "Domains", domainSid, "IpAccessControlListMappings", mappingSid)))
    }

    // --- Auth/Calls/CredentialListMappings ---
    public func listAuthCallsCredentialListMappings(domainSid: String, _ params: ListSipPageParams = .init()) async throws -> SipCredentialListMappingList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "CredentialListMappings"), query: params.queryItems()))
    }
    public func createAuthCallsCredentialListMapping(domainSid: String, _ body: CreateSipCredentialListMappingRequest) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "CredentialListMappings"), form: body.formFields()))
    }
    public func fetchAuthCallsCredentialListMapping(domainSid: String, mappingSid: String) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "CredentialListMappings", mappingSid)))
    }
    public func deleteAuthCallsCredentialListMapping(domainSid: String, mappingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "CredentialListMappings", mappingSid)))
    }

    // --- Auth/Calls/IpAccessControlListMappings ---
    public func listAuthCallsIpAccessControlListMappings(domainSid: String, _ params: ListSipPageParams = .init()) async throws -> SipIpAccessControlListMappingList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "IpAccessControlListMappings"), query: params.queryItems()))
    }
    public func createAuthCallsIpAccessControlListMapping(domainSid: String, _ body: CreateSipIpAccessControlListMappingRequest) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "IpAccessControlListMappings"), form: body.formFields()))
    }
    public func fetchAuthCallsIpAccessControlListMapping(domainSid: String, mappingSid: String) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "IpAccessControlListMappings", mappingSid)))
    }
    public func deleteAuthCallsIpAccessControlListMapping(domainSid: String, mappingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "Domains", domainSid, "Auth", "Calls", "IpAccessControlListMappings", mappingSid)))
    }

    // --- Auth/Registrations/CredentialListMappings ---
    public func listAuthRegistrationsCredentialListMappings(domainSid: String, _ params: ListSipPageParams = .init()) async throws -> SipCredentialListMappingList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "Auth", "Registrations", "CredentialListMappings"), query: params.queryItems()))
    }
    public func createAuthRegistrationsCredentialListMapping(domainSid: String, _ body: CreateSipCredentialListMappingRequest) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "Domains", domainSid, "Auth", "Registrations", "CredentialListMappings"), form: body.formFields()))
    }
    public func fetchAuthRegistrationsCredentialListMapping(domainSid: String, mappingSid: String) async throws -> SipDomainMapping {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "Domains", domainSid, "Auth", "Registrations", "CredentialListMappings", mappingSid)))
    }
    public func deleteAuthRegistrationsCredentialListMapping(domainSid: String, mappingSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "Domains", domainSid, "Auth", "Registrations", "CredentialListMappings", mappingSid)))
    }
}

/// `/SIP/CredentialLists` + nested /Credentials.
public final class SipCredentialListsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }
    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.filter { !$0.isEmpty }.joined(separator: "/")
    }

    public func list(_ params: ListSipPageParams = .init()) async throws -> SipCredentialListList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "CredentialLists"), query: params.queryItems()))
    }
    public func create(_ body: CreateSipCredentialListRequest) async throws -> SipCredentialList {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "CredentialLists"), form: body.formFields()))
    }
    public func fetch(sid: String) async throws -> SipCredentialList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "CredentialLists", sid)))
    }
    public func update(sid: String, _ body: UpdateSipCredentialListRequest) async throws -> SipCredentialList {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "CredentialLists", sid), form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "CredentialLists", sid)))
    }

    public func listCredentials(credentialListSid: String, _ params: ListSipPageParams = .init()) async throws -> SipCredentialListPage {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "CredentialLists", credentialListSid, "Credentials"), query: params.queryItems()))
    }
    public func createCredential(credentialListSid: String, _ body: CreateSipCredentialRequest) async throws -> SipCredential {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "CredentialLists", credentialListSid, "Credentials"), form: body.formFields()))
    }
    public func fetchCredential(credentialListSid: String, sid: String) async throws -> SipCredential {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "CredentialLists", credentialListSid, "Credentials", sid)))
    }
    public func updateCredential(credentialListSid: String, sid: String, _ body: UpdateSipCredentialRequest) async throws -> SipCredential {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "CredentialLists", credentialListSid, "Credentials", sid), form: body.formFields()))
    }
    public func deleteCredential(credentialListSid: String, sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "CredentialLists", credentialListSid, "Credentials", sid)))
    }
}

/// `/SIP/IpAccessControlLists` + nested /IpAddresses.
public final class SipIpAccessControlListsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }
    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.filter { !$0.isEmpty }.joined(separator: "/")
    }

    public func list(_ params: ListSipPageParams = .init()) async throws -> SipIpAccessControlListList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "IpAccessControlLists"), query: params.queryItems()))
    }
    public func create(_ body: CreateSipIpAccessControlListRequest) async throws -> SipIpAccessControlList {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "IpAccessControlLists"), form: body.formFields()))
    }
    public func fetch(sid: String) async throws -> SipIpAccessControlList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "IpAccessControlLists", sid)))
    }
    public func update(sid: String, _ body: UpdateSipIpAccessControlListRequest) async throws -> SipIpAccessControlList {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "IpAccessControlLists", sid), form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "IpAccessControlLists", sid)))
    }

    public func listIpAddresses(aclSid: String, _ params: ListSipPageParams = .init()) async throws -> SipIpAddressList {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "IpAccessControlLists", aclSid, "IpAddresses"), query: params.queryItems()))
    }
    public func createIpAddress(aclSid: String, _ body: CreateSipIpAddressRequest) async throws -> SipIpAddress {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "IpAccessControlLists", aclSid, "IpAddresses"), form: body.formFields()))
    }
    public func fetchIpAddress(aclSid: String, sid: String) async throws -> SipIpAddress {
        try await transport.request(VoiceMLRequest(method: .get, path: path("SIP", "IpAccessControlLists", aclSid, "IpAddresses", sid)))
    }
    public func updateIpAddress(aclSid: String, sid: String, _ body: UpdateSipIpAddressRequest) async throws -> SipIpAddress {
        try await transport.request(VoiceMLRequest(method: .post, path: path("SIP", "IpAccessControlLists", aclSid, "IpAddresses", sid), form: body.formFields()))
    }
    public func deleteIpAddress(aclSid: String, sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("SIP", "IpAccessControlLists", aclSid, "IpAddresses", sid)))
    }
}
