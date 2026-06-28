import Foundation

/// `client.voiceV1` — Twilio Voice v1 (voice.twilio.com/v1) namespace.
/// Six resources: IpRecords, SourceIpMappings, ByocTrunks,
/// ConnectionPolicies (with nested Targets), DialingPermissions Settings.
public final class VoiceV1Resource: Sendable {
    public let ipRecords: VoiceV1IpRecordsResource
    public let sourceIpMappings: VoiceV1SourceIpMappingsResource
    public let byocTrunks: VoiceV1ByocTrunksResource
    public let connectionPolicies: VoiceV1ConnectionPoliciesResource
    public let settings: VoiceV1SettingsResource

    init(transport: Transport) {
        self.ipRecords = VoiceV1IpRecordsResource(transport: transport)
        self.sourceIpMappings = VoiceV1SourceIpMappingsResource(transport: transport)
        self.byocTrunks = VoiceV1ByocTrunksResource(transport: transport)
        self.connectionPolicies = VoiceV1ConnectionPoliciesResource(transport: transport)
        self.settings = VoiceV1SettingsResource(transport: transport)
    }
}

// MARK: - IpRecords

public final class VoiceV1IpRecordsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateVoiceV1IpRecordRequest) async throws -> VoiceV1IpRecord {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/IpRecords", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> VoiceV1IpRecordList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/IpRecords", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> VoiceV1IpRecord {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/IpRecords/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateVoiceV1IpRecordRequest) async throws -> VoiceV1IpRecord {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/IpRecords/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/IpRecords/\(sid)"))
    }
}

// MARK: - SourceIpMappings

public final class VoiceV1SourceIpMappingsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateVoiceV1SourceIpMappingRequest) async throws -> VoiceV1SourceIpMapping {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/SourceIpMappings", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> VoiceV1SourceIpMappingList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/SourceIpMappings", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> VoiceV1SourceIpMapping {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/SourceIpMappings/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateVoiceV1SourceIpMappingRequest) async throws -> VoiceV1SourceIpMapping {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/SourceIpMappings/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/SourceIpMappings/\(sid)"))
    }
}

// MARK: - ByocTrunks

public final class VoiceV1ByocTrunksResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateVoiceV1ByocTrunkRequest) async throws -> VoiceV1ByocTrunk {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/ByocTrunks", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> VoiceV1ByocTrunkList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/ByocTrunks", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> VoiceV1ByocTrunk {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/ByocTrunks/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateVoiceV1ByocTrunkRequest) async throws -> VoiceV1ByocTrunk {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/ByocTrunks/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/ByocTrunks/\(sid)"))
    }
}

// MARK: - ConnectionPolicies + Targets

public final class VoiceV1ConnectionPoliciesResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateVoiceV1ConnectionPolicyRequest = .init()) async throws -> VoiceV1ConnectionPolicy {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/ConnectionPolicies", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> VoiceV1ConnectionPolicyList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/ConnectionPolicies", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> VoiceV1ConnectionPolicy {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/ConnectionPolicies/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateVoiceV1ConnectionPolicyRequest = .init()) async throws -> VoiceV1ConnectionPolicy {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/ConnectionPolicies/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/ConnectionPolicies/\(sid)"))
    }

    // Nested Targets — keyed by the parent ConnectionPolicy sid.
    public func createTarget(connectionPolicySid: String, _ body: CreateVoiceV1ConnectionPolicyTargetRequest) async throws -> VoiceV1ConnectionPolicyTarget {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/ConnectionPolicies/\(connectionPolicySid)/Targets", form: body.formFields()))
    }
    public func listTargets(connectionPolicySid: String, _ params: ListV1PageParams = .init()) async throws -> VoiceV1ConnectionPolicyTargetList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/ConnectionPolicies/\(connectionPolicySid)/Targets", query: params.queryItems()))
    }
    public func fetchTarget(connectionPolicySid: String, sid: String) async throws -> VoiceV1ConnectionPolicyTarget {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/ConnectionPolicies/\(connectionPolicySid)/Targets/\(sid)"))
    }
    public func updateTarget(connectionPolicySid: String, sid: String, _ body: UpdateVoiceV1ConnectionPolicyTargetRequest) async throws -> VoiceV1ConnectionPolicyTarget {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/ConnectionPolicies/\(connectionPolicySid)/Targets/\(sid)", form: body.formFields()))
    }
    public func deleteTarget(connectionPolicySid: String, sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/ConnectionPolicies/\(connectionPolicySid)/Targets/\(sid)"))
    }
}

// MARK: - DialingPermissions Settings (singleton)

public final class VoiceV1SettingsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func fetch() async throws -> VoiceV1DialingPermissionsSettings {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Settings"))
    }
    public func update(_ body: UpdateVoiceV1DialingPermissionsSettingsRequest = .init()) async throws -> VoiceV1DialingPermissionsSettings {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Settings", form: body.formFields()))
    }
}
