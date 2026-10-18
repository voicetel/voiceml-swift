import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import VoiceML

// Spec-driven contract test. Loads a vendored copy of the public OpenAPI spec
// (Tests/VoiceMLTests/Fixtures/voiceml-openapi.json — never shipped in the package
// product) and a synthesized per-op response corpus, then exercises EVERY public
// operation through the URLProtocol mock and asserts, per operation:
//
//   1. the request's (method, path template incl. `.json`) matches the spec op;
//   2. query / form / JSON keys are a subset of that op's declared params and body
//      props, with required ones present;
//   3. the host is correct per tag (Conversations → conversations.*, Messaging
//      Service → messaging.*, everything else → the default host);
//   4. the Authorization header is present or absent per the op's `security`;
//   5. the synthesized spec response decodes into the SDK's response model
//      (nullability / unknown-enum tolerance).
//
// The final assertion is coverage: every one of the spec's 333 operations must be
// exercised (333/333).

final class VoiceMLContractTests: XCTestCase {

    static let accountSid = "AC" + String(repeating: "f", count: 32)
    static let apiKey = "contract-key-0123456789"

    // Sentinel values substituted into path templates. The registry invocations
    // MUST use exactly these values so the rendered template matches the wire path.
    static let sid = "XX" + String(repeating: "1", count: 32)
    static let callSid = "CA" + String(repeating: "2", count: 32)
    static let conferenceSid = "CF" + String(repeating: "3", count: 32)
    static let recordingSid = "RE" + String(repeating: "4", count: 32)
    static let messageSid = "SM" + String(repeating: "5", count: 32)
    static let paymentSid = "PY" + String(repeating: "6", count: 32)
    static let domainSid = "SD" + String(repeating: "7", count: 32)
    static let credentialListSid = "CL" + String(repeating: "8", count: 32)
    static let aclSid = "AL" + String(repeating: "9", count: 32)
    static let queueSid = "QU" + String(repeating: "a", count: 32)
    static let chatServiceSid = "MG" + String(repeating: "b", count: 32)
    static let conversationSid = "CH" + String(repeating: "c", count: 32)
    static let participantSid = "KP" + String(repeating: "d", count: 32)
    static let webhookSid = "WH" + String(repeating: "e", count: 32)
    static let userSid = "UL" + String(repeating: "0", count: 32)
    static let connectionPolicySid = "NY" + String(repeating: "1", count: 32)
    static let phoneNumber = "+14155550100"
    static let number = "+14155550102"
    static let destinationNumber = "+14155550103"
    static let sipDomain = "sip.example.com"
    static let isoCountry = "US"
    static let exportDate = "2026-10-16"
    static let assistantId = "aia_asst_x1"
    static let toolId = "aia_tool_x1"
    static let knowledgeId = "aia_know_x1"
    static let sessionId = "aia_sess_x1"

    struct SpecModel {
        struct Op {
            var method: String
            var pathTemplate: String
            var tags: [String]
            var hasAuth: Bool
            var queryNames: Set<String>
            var requiredQuery: Set<String>
            var bodyProps: Set<String>
            var requiredBody: Set<String>
        }

        var ops: [String: Op]
    }

    private func loadSpec() throws -> SpecModel {
        let fixturesDir = URL(fileURLWithPath: #filePath, isDirectory: false)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent("voiceml-openapi.json"))
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let paths = obj["paths"] as! [String: Any]

        func resolve(_ input: [String: Any]) -> [String: Any] {
            guard let ref = input["$ref"] as? String else { return input }
            var value: Any = obj
            for part in ref.dropFirst(2).split(separator: "/") {
                value = (value as! [String: Any])[String(part)]!
            }
            return resolve(value as! [String: Any])
        }

        var ops: [String: SpecModel.Op] = [:]
        for (path, pathItemAny) in paths {
            let pathItem = pathItemAny as! [String: Any]
            for method in ["get", "post", "put", "delete", "patch"] {
                guard let opAny = pathItem[method] else { continue }
                let op = opAny as! [String: Any]
                let opId = op["operationId"] as! String
                let tags = (op["tags"] as? [String]) ?? []

                var queryNames = Set<String>()
                var requiredQuery = Set<String>()
                let processParams: ([Any]) -> Void = { list in
                    for pAny in list {
                        let p = resolve(pAny as! [String: Any])
                        guard let `in` = p["in"] as? String else { continue }
                        if `in` == "query" || `in` == "path" {
                            let name = p["name"] as! String
                            if `in` == "query" {
                                queryNames.insert(name)
                                if p["required"] as? Bool == true { requiredQuery.insert(name) }
                            }
                        }
                    }
                }
                // Path-level params (shared across methods).
                if let topParams = pathItem["parameters"] as? [Any] {
                    processParams(topParams)
                }
                if let opParams = op["parameters"] as? [Any] {
                    processParams(opParams)
                }

                var bodyProps = Set<String>()
                var requiredBody = Set<String>()
                if let bodyAny = op["requestBody"] as? [String: Any],
                   let content = bodyAny["content"] as? [String: Any] {
                    for (_, cAny) in content {
                        let c = cAny as! [String: Any]
                        guard let schemaAny = c["schema"] else { continue }
                        let schema = resolve(schemaAny as! [String: Any])
                        for (prop, _) in (schema["properties"] as? [String: Any]) ?? [:] {
                            bodyProps.insert(prop)
                        }
                        for req in (schema["required"] as? [String]) ?? [] {
                            requiredBody.insert(req)
                        }
                    }
                }

                let security = op["security"] as? [[String: Any]]
                let hasAuth: Bool
                if let security {
                    hasAuth = !security.isEmpty
                } else {
                    hasAuth = true
                }

                ops[opId] = SpecModel.Op(
                    method: method.uppercased(),
                    pathTemplate: path,
                    tags: tags,
                    hasAuth: hasAuth,
                    queryNames: queryNames,
                    requiredQuery: requiredQuery,
                    bodyProps: bodyProps,
                    requiredBody: requiredBody
                )
            }
        }
        return SpecModel(ops: ops)
    }

    private func loadResponses() throws -> [String: [String: Any]] {
        let fixturesDir = URL(fileURLWithPath: #filePath, isDirectory: false)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent("contract-responses.json"))
        return try JSONSerialization.jsonObject(with: data) as! [String: [String: Any]]
    }

    // MARK: - Registry

    struct Entry {
        let opId: String
        let host: String
        let invoke: @Sendable (VoiceMLClient) async throws -> Void
    }

    private func registry() -> [Entry] {
        let acct = Self.accountSid
        var e: [Entry] = []

        func reg(_ opId: String, host: String = "voiceml.voicetel.com", _ invoke: @escaping @Sendable (VoiceMLClient) async throws -> Void) {
            e.append(Entry(opId: opId, host: host, invoke: invoke))
        }

        // -- Calls
        reg("calls.list") { c in _ = try await c.calls.list() }
        reg("calls.create") { c in _ = try await c.calls.create(.init(to: Self.phoneNumber, from: Self.number, url: "https://example.com/twiml")) }
        reg("calls.fetch") { c in _ = try await c.calls.get(Self.callSid) }
        reg("calls.update") { c in _ = try await c.calls.update(callSid: Self.callSid, body: .init(status: .completed)) }
        reg("calls.delete") { c in try await c.calls.delete(Self.callSid) }
        // -- Conferences
        reg("conferences.list") { c in _ = try await c.conferences.list() }
        reg("conferences.fetch") { c in _ = try await c.conferences.get(Self.conferenceSid) }
        reg("conferences.update") { c in _ = try await c.conferences.end(conferenceSid: Self.conferenceSid) }
        reg("participants.list") { c in _ = try await c.conferences.listParticipants(conferenceSid: Self.conferenceSid) }
        reg("participants.create") { c in _ = try await c.conferences.createParticipant(conferenceSid: Self.conferenceSid, body: .init(from: Self.number, to: Self.phoneNumber)) }
        reg("participants.fetch") { c in _ = try await c.conferences.getParticipant(conferenceSid: Self.conferenceSid, callSid: Self.callSid) }
        reg("participants.update") { c in _ = try await c.conferences.updateParticipant(conferenceSid: Self.conferenceSid, callSid: Self.callSid, body: .init(muted: true)) }
        reg("participants.delete") { c in try await c.conferences.kickParticipant(conferenceSid: Self.conferenceSid, callSid: Self.callSid) }
        // -- Queues
        reg("queues.list") { c in _ = try await c.queues.list() }
        reg("queues.create") { c in _ = try await c.queues.create(.init(friendlyName: "q")) }
        reg("queues.fetch") { c in _ = try await c.queues.get(Self.queueSid) }
        reg("queues.update") { c in _ = try await c.queues.update(queueSid: Self.queueSid, body: .init(friendlyName: "q2")) }
        reg("queues.delete") { c in try await c.queues.delete(Self.queueSid) }
        reg("queueMembers.list") { c in _ = try await c.queues.listMembers(queueSid: Self.queueSid) }
        reg("queueMembers.fetchFront") { c in _ = try await c.queues.peekFront(queueSid: Self.queueSid) }
        reg("queueMembers.dequeueFront") { c in _ = try await c.queues.dequeueFront(queueSid: Self.queueSid, body: .init(url: "https://example.com/twiml")) }
        reg("queueMembers.fetch") { c in _ = try await c.queues.getMember(queueSid: Self.queueSid, callSid: Self.callSid) }
        reg("queueMembers.dequeue") { c in _ = try await c.queues.dequeueMember(queueSid: Self.queueSid, callSid: Self.callSid, body: .init(url: "https://example.com/twiml")) }
        // -- Applications
        reg("applications.list") { c in _ = try await c.applications.list() }
        reg("applications.create") { c in _ = try await c.applications.create(.init(friendlyName: "app")) }
        reg("applications.fetch") { c in _ = try await c.applications.get(Self.sid) }
        reg("applications.update") { c in _ = try await c.applications.update(applicationSid: Self.sid, body: .init(friendlyName: "app2")) }
        reg("applications.delete") { c in try await c.applications.delete(Self.sid) }
        // -- OutgoingCallerIds
        reg("outgoing_caller_ids.list") { c in _ = try await c.outgoingCallerIds.list() }
        reg("outgoing_caller_ids.create") { c in _ = try await c.outgoingCallerIds.create(.init(phoneNumber: Self.phoneNumber)) }
        reg("outgoing_caller_ids.fetch") { c in _ = try await c.outgoingCallerIds.fetch(sid: Self.sid) }
        reg("outgoing_caller_ids.update") { c in _ = try await c.outgoingCallerIds.update(sid: Self.sid, .init(friendlyName: "desk")) }
        reg("outgoing_caller_ids.delete") { c in try await c.outgoingCallerIds.delete(sid: Self.sid) }
        // -- SIP domains
        reg("sip_domains.list") { c in _ = try await c.sip.domains.list() }
        reg("sip_domains.create") { c in _ = try await c.sip.domains.create(.init(domainName: Self.sipDomain)) }
        reg("sip_registrations.list") { c in _ = try await c.sip.registrations.list() }
        reg("sip_domains.fetch") { c in _ = try await c.sip.domains.fetch(sid: Self.domainSid) }
        reg("sip_domains.update") { c in _ = try await c.sip.domains.update(sid: Self.domainSid, .init(friendlyName: "d2")) }
        reg("sip_domains.delete") { c in try await c.sip.domains.delete(sid: Self.domainSid) }
        // -- SIP credential lists
        reg("sip_credential_lists.list") { c in _ = try await c.sip.credentialLists.list() }
        reg("sip_credential_lists.create") { c in _ = try await c.sip.credentialLists.create(.init(friendlyName: "cl")) }
        reg("sip_credential_lists.fetch") { c in _ = try await c.sip.credentialLists.fetch(sid: Self.credentialListSid) }
        reg("sip_credential_lists.update") { c in _ = try await c.sip.credentialLists.update(sid: Self.credentialListSid, .init(friendlyName: "cl2")) }
        reg("sip_credential_lists.delete") { c in try await c.sip.credentialLists.delete(sid: Self.credentialListSid) }
        reg("sip_credentials.list") { c in _ = try await c.sip.credentialLists.listCredentials(credentialListSid: Self.credentialListSid) }
        reg("sip_credentials.create") { c in _ = try await c.sip.credentialLists.createCredential(credentialListSid: Self.credentialListSid, .init(username: "u", password: "p")) }
        reg("sip_credentials.fetch") { c in _ = try await c.sip.credentialLists.fetchCredential(credentialListSid: Self.credentialListSid, sid: Self.sid) }
        reg("sip_credentials.update") { c in _ = try await c.sip.credentialLists.updateCredential(credentialListSid: Self.credentialListSid, sid: Self.sid, .init(password: "p2")) }
        reg("sip_credentials.delete") { c in try await c.sip.credentialLists.deleteCredential(credentialListSid: Self.credentialListSid, sid: Self.sid) }
        // -- SIP IP access control lists
        reg("sip_ip_access_control_lists.list") { c in _ = try await c.sip.ipAccessControlLists.list() }
        reg("sip_ip_access_control_lists.create") { c in _ = try await c.sip.ipAccessControlLists.create(.init(friendlyName: "acl")) }
        reg("sip_ip_access_control_lists.fetch") { c in _ = try await c.sip.ipAccessControlLists.fetch(sid: Self.aclSid) }
        reg("sip_ip_access_control_lists.update") { c in _ = try await c.sip.ipAccessControlLists.update(sid: Self.aclSid, .init(friendlyName: "acl2")) }
        reg("sip_ip_access_control_lists.delete") { c in try await c.sip.ipAccessControlLists.delete(sid: Self.aclSid) }
        reg("sip_ip_addresses.list") { c in _ = try await c.sip.ipAccessControlLists.listIpAddresses(aclSid: Self.aclSid) }
        reg("sip_ip_addresses.create") { c in _ = try await c.sip.ipAccessControlLists.createIpAddress(aclSid: Self.aclSid, .init(friendlyName: "ip", ipAddress: "10.0.0.1")) }
        reg("sip_ip_addresses.fetch") { c in _ = try await c.sip.ipAccessControlLists.fetchIpAddress(aclSid: Self.aclSid, sid: Self.sid) }
        reg("sip_ip_addresses.update") { c in _ = try await c.sip.ipAccessControlLists.updateIpAddress(aclSid: Self.aclSid, sid: Self.sid, .init(friendlyName: "ip2")) }
        reg("sip_ip_addresses.delete") { c in try await c.sip.ipAccessControlLists.deleteIpAddress(aclSid: Self.aclSid, sid: Self.sid) }
        // -- SIP domain mappings
        reg("sip_domain_credential_list_mappings.list") { c in _ = try await c.sip.domains.listCredentialListMappings(domainSid: Self.domainSid) }
        reg("sip_domain_credential_list_mappings.create") { c in _ = try await c.sip.domains.createCredentialListMapping(domainSid: Self.domainSid, .init(credentialListSid: Self.credentialListSid)) }
        reg("sip_domain_credential_list_mappings.fetch") { c in _ = try await c.sip.domains.fetchCredentialListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_credential_list_mappings.delete") { c in try await c.sip.domains.deleteCredentialListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_ip_access_control_list_mappings.list") { c in _ = try await c.sip.domains.listIpAccessControlListMappings(domainSid: Self.domainSid) }
        reg("sip_domain_ip_access_control_list_mappings.create") { c in _ = try await c.sip.domains.createIpAccessControlListMapping(domainSid: Self.domainSid, .init(ipAccessControlListSid: Self.aclSid)) }
        reg("sip_domain_ip_access_control_list_mappings.fetch") { c in _ = try await c.sip.domains.fetchIpAccessControlListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_ip_access_control_list_mappings.delete") { c in try await c.sip.domains.deleteIpAccessControlListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_auth_calls_credential_list_mappings.list") { c in _ = try await c.sip.domains.listAuthCallsCredentialListMappings(domainSid: Self.domainSid) }
        reg("sip_domain_auth_calls_credential_list_mappings.create") { c in _ = try await c.sip.domains.createAuthCallsCredentialListMapping(domainSid: Self.domainSid, .init(credentialListSid: Self.credentialListSid)) }
        reg("sip_domain_auth_calls_credential_list_mappings.fetch") { c in _ = try await c.sip.domains.fetchAuthCallsCredentialListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_auth_calls_credential_list_mappings.delete") { c in try await c.sip.domains.deleteAuthCallsCredentialListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_auth_calls_ip_access_control_list_mappings.list") { c in _ = try await c.sip.domains.listAuthCallsIpAccessControlListMappings(domainSid: Self.domainSid) }
        reg("sip_domain_auth_calls_ip_access_control_list_mappings.create") { c in _ = try await c.sip.domains.createAuthCallsIpAccessControlListMapping(domainSid: Self.domainSid, .init(ipAccessControlListSid: Self.aclSid)) }
        reg("sip_domain_auth_calls_ip_access_control_list_mappings.fetch") { c in _ = try await c.sip.domains.fetchAuthCallsIpAccessControlListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_auth_calls_ip_access_control_list_mappings.delete") { c in try await c.sip.domains.deleteAuthCallsIpAccessControlListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_auth_registrations_credential_list_mappings.list") { c in _ = try await c.sip.domains.listAuthRegistrationsCredentialListMappings(domainSid: Self.domainSid) }
        reg("sip_domain_auth_registrations_credential_list_mappings.create") { c in _ = try await c.sip.domains.createAuthRegistrationsCredentialListMapping(domainSid: Self.domainSid, .init(credentialListSid: Self.credentialListSid)) }
        reg("sip_domain_auth_registrations_credential_list_mappings.fetch") { c in _ = try await c.sip.domains.fetchAuthRegistrationsCredentialListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        reg("sip_domain_auth_registrations_credential_list_mappings.delete") { c in try await c.sip.domains.deleteAuthRegistrationsCredentialListMapping(domainSid: Self.domainSid, mappingSid: Self.sid) }
        // -- Messages
        reg("messages.list") { c in _ = try await c.messages.list() }
        reg("messages.create") { c in _ = try await c.messages.create(.init(to: Self.phoneNumber, body: "hi")) }
        reg("messages.fetch") { c in _ = try await c.messages.fetch(sid: Self.messageSid) }
        reg("messages.update") { c in _ = try await c.messages.update(sid: Self.messageSid, .init(body: "")) }
        reg("messages.delete") { c in try await c.messages.delete(sid: Self.messageSid) }
        reg("messages.feedback.create") { c in _ = try await c.messages.createFeedback(sid: Self.messageSid, .init(outcome: "confirmed")) }
        reg("media.list") { c in _ = try await c.messages.media(messageSid: Self.messageSid).list() }
        reg("media.fetch") { c in _ = try await c.messages.media(messageSid: Self.messageSid).fetch(sid: Self.sid) }
        reg("media.delete") { c in try await c.messages.media(messageSid: Self.messageSid).delete(sid: Self.sid) }
        // -- Accounts / Balance / Exports
        reg("accounts.fetch") { c in _ = try await c.accounts.fetch(sid: acct) }
        reg("accounts.update") { c in _ = try await c.accounts.update(sid: acct, .init(friendlyName: "n")) }
        reg("accounts.rotateKey") { c in _ = try await c.accounts.rotateKey() }
        reg("balance.fetch") { c in _ = try await c.accounts.balance() }
        reg("exports.list") { c in _ = try await c.exports.list() }
        reg("exports.download") { c in _ = try await c.exports.download(date: Self.exportDate) }
        // -- Recordings
        reg("recordings.list") { c in _ = try await c.recordings.list() }
        reg("recordings.fetch") { c in _ = try await c.recordings.get(Self.recordingSid) }
        reg("recordings.delete") { c in try await c.recordings.delete(Self.recordingSid) }
        reg("recordings.fetchAudio") { c in _ = try await c.recordings.getAudio(recordingSid: Self.recordingSid) }
        reg("callRecordings.list") { c in _ = try await c.calls.listRecordings(callSid: Self.callSid) }
        reg("callRecordings.create") { c in _ = try await c.calls.startRecording(callSid: Self.callSid) }
        reg("callRecordings.fetch") { c in _ = try await c.calls.getRecording(callSid: Self.callSid, recordingSid: Self.recordingSid) }
        reg("callRecordings.update") { c in _ = try await c.calls.updateRecording(callSid: Self.callSid, recordingSid: Self.recordingSid, body: .init(status: .stopped)) }
        reg("callRecordings.delete") { c in try await c.calls.deleteRecording(callSid: Self.callSid, recordingSid: Self.recordingSid) }
        // -- Streams / Siprec / Transcriptions (POST-only)
        reg("streams.create") { c in _ = try await c.calls.startStream(callSid: Self.callSid, body: .init(url: "wss://example.com/ws")) }
        reg("streams.update") { c in _ = try await c.calls.stopStream(callSid: Self.callSid, streamSid: Self.sid) }
        reg("siprec.create") { c in _ = try await c.calls.startSiprec(callSid: Self.callSid) }
        reg("siprec.update") { c in _ = try await c.calls.stopSiprec(callSid: Self.callSid, siprecSid: Self.sid) }
        reg("callTranscriptions.create") { c in _ = try await c.calls.startTranscription(callSid: Self.callSid) }
        reg("callTranscriptions.update") { c in _ = try await c.calls.stopTranscription(callSid: Self.callSid, transcriptionSid: Self.sid) }
        reg("transcriptions.listAccount") { c in _ = try await c.transcriptions.list() }
        reg("transcription.fetch") { c in _ = try await c.transcriptions.fetch(sid: Self.sid) }
        reg("transcription.delete") { c in try await c.transcriptions.delete(sid: Self.sid) }
        reg("recording.transcriptions.list") { c in _ = try await c.recordings.transcriptions(recordingSid: Self.recordingSid).list() }
        reg("recording.transcription.fetch") { c in _ = try await c.recordings.transcriptions(recordingSid: Self.recordingSid).fetch(sid: Self.sid) }
        reg("recording.transcription.delete") { c in try await c.recordings.transcriptions(recordingSid: Self.recordingSid).delete(sid: Self.sid) }
        // -- Payments
        reg("payments.create") { c in _ = try await c.calls.startPayment(callSid: Self.callSid) }
        reg("payments.update") { c in _ = try await c.calls.updatePayment(callSid: Self.callSid, paymentSid: Self.paymentSid, .init(status: .complete)) }
        // -- Notifications / Events
        reg("callNotifications.list") { c in _ = try await c.calls.listNotifications(callSid: Self.callSid) }
        reg("callNotifications.fetch") { c in _ = try await c.calls.getNotification(callSid: Self.callSid, notificationSid: Self.sid) }
        reg("notifications.list") { c in _ = try await c.notifications.list() }
        reg("notifications.fetch") { c in _ = try await c.notifications.get(Self.sid) }
        reg("callEvents.list") { c in _ = try await c.calls.listEvents(callSid: Self.callSid) }
        reg("userDefinedMessages.create") { c in try await c.calls.sendUserDefinedMessage(callSid: Self.callSid) }
        // -- Conference recordings
        reg("conferenceRecordings.list") { c in _ = try await c.conferences.listRecordings(conferenceSid: Self.conferenceSid) }
        reg("conferenceRecordings.create") { c in _ = try await c.conferences.startRecording(conferenceSid: Self.conferenceSid) }
        reg("conferenceRecordings.fetch") { c in _ = try await c.conferences.getRecording(conferenceSid: Self.conferenceSid, recordingSid: Self.recordingSid) }
        reg("conferenceRecordings.update") { c in _ = try await c.conferences.updateRecording(conferenceSid: Self.conferenceSid, recordingSid: Self.recordingSid, body: .init(status: .stopped)) }
        reg("conferenceRecordings.delete") { c in try await c.conferences.deleteRecording(conferenceSid: Self.conferenceSid, recordingSid: Self.recordingSid) }
        // -- Diagnostics
        reg("health.check") { c in _ = try await c.diagnostics.health() }
        reg("openapi.yaml") { c in _ = try await c.diagnostics.openapiYaml() }
        reg("openapi.yml") { c in _ = try await c.diagnostics.openapiYml() }
        reg("openapi.json") { c in _ = try await c.diagnostics.openapiJson() }
        // -- IncomingPhoneNumbers
        reg("incomingPhoneNumbers.list") { c in _ = try await c.incomingPhoneNumbers.list() }
        reg("incomingPhoneNumbers.create") { c in _ = try await c.incomingPhoneNumbers.create(.init(phoneNumber: Self.phoneNumber)) }
        reg("incomingPhoneNumbers.listLocal") { c in _ = try await c.incomingPhoneNumbers.listLocal() }
        reg("incomingPhoneNumbers.createLocal") { c in _ = try await c.incomingPhoneNumbers.createLocal(.init(phoneNumber: Self.phoneNumber)) }
        reg("incomingPhoneNumbers.listMobile") { c in _ = try await c.incomingPhoneNumbers.listMobile() }
        reg("incomingPhoneNumbers.createMobile") { c in _ = try await c.incomingPhoneNumbers.createMobile(.init(phoneNumber: Self.phoneNumber)) }
        reg("incomingPhoneNumbers.listTollFree") { c in _ = try await c.incomingPhoneNumbers.listTollFree() }
        reg("incomingPhoneNumbers.createTollFree") { c in _ = try await c.incomingPhoneNumbers.createTollFree(.init(phoneNumber: Self.phoneNumber)) }
        reg("incomingPhoneNumbers.fetch") { c in _ = try await c.incomingPhoneNumbers.get(Self.sid) }
        reg("incomingPhoneNumbers.update") { c in _ = try await c.incomingPhoneNumbers.update(Self.sid, .init(voiceUrl: "https://example.com/twiml")) }
        reg("incomingPhoneNumbers.delete") { c in try await c.incomingPhoneNumbers.delete(Self.sid) }
        // -- Usage records
        reg("usageRecords.list") { c in _ = try await c.usageRecords.list() }
        reg("usageRecords.listAllTime") { c in _ = try await c.usageRecords.listAllTime() }
        reg("usageRecords.listDaily") { c in _ = try await c.usageRecords.listDaily() }
        reg("usageRecords.listLastMonth") { c in _ = try await c.usageRecords.listLastMonth() }
        reg("usageRecords.listMonthly") { c in _ = try await c.usageRecords.listMonthly() }
        reg("usageRecords.listThisMonth") { c in _ = try await c.usageRecords.listThisMonth() }
        reg("usageRecords.listToday") { c in _ = try await c.usageRecords.listToday() }
        reg("usageRecords.listYearly") { c in _ = try await c.usageRecords.listYearly() }
        reg("usageRecords.listYesterday") { c in _ = try await c.usageRecords.listYesterday() }
        // -- Routes v2
        reg("routes.v2.sipDomains.fetch") { c in _ = try await c.routesV2.sipDomains.fetch(domainName: Self.sipDomain) }
        reg("routes.v2.sipDomains.update") { c in _ = try await c.routesV2.sipDomains.update(domainName: Self.sipDomain, .init(voiceRegion: "us1")) }
        reg("routes.v2.phoneNumbers.fetch") { c in _ = try await c.routesV2.phoneNumbers.fetch(phoneNumber: Self.phoneNumber) }
        reg("routes.v2.phoneNumbers.update") { c in _ = try await c.routesV2.phoneNumbers.update(phoneNumber: Self.phoneNumber, .init(voiceRegion: "us1")) }
        // -- Voice v1
        reg("voice.v1.ipRecords.list") { c in _ = try await c.voiceV1.ipRecords.list() }
        reg("voice.v1.ipRecords.create") { c in _ = try await c.voiceV1.ipRecords.create(.init(ipAddress: "10.0.0.1")) }
        reg("voice.v1.ipRecords.fetch") { c in _ = try await c.voiceV1.ipRecords.fetch(sid: Self.sid) }
        reg("voice.v1.ipRecords.update") { c in _ = try await c.voiceV1.ipRecords.update(sid: Self.sid, .init(friendlyName: "n")) }
        reg("voice.v1.ipRecords.delete") { c in try await c.voiceV1.ipRecords.delete(sid: Self.sid) }
        reg("voice.v1.sourceIpMappings.list") { c in _ = try await c.voiceV1.sourceIpMappings.list() }
        reg("voice.v1.sourceIpMappings.create") { c in _ = try await c.voiceV1.sourceIpMappings.create(.init(ipRecordSid: Self.sid, sipDomainSid: Self.domainSid)) }
        reg("voice.v1.sourceIpMappings.fetch") { c in _ = try await c.voiceV1.sourceIpMappings.fetch(sid: Self.sid) }
        reg("voice.v1.sourceIpMappings.update") { c in _ = try await c.voiceV1.sourceIpMappings.update(sid: Self.sid, .init(sipDomainSid: Self.domainSid)) }
        reg("voice.v1.sourceIpMappings.delete") { c in try await c.voiceV1.sourceIpMappings.delete(sid: Self.sid) }
        reg("voice.v1.byocTrunks.list") { c in _ = try await c.voiceV1.byocTrunks.list() }
        reg("voice.v1.byocTrunks.create") { c in _ = try await c.voiceV1.byocTrunks.create(.init()) }
        reg("voice.v1.byocTrunks.fetch") { c in _ = try await c.voiceV1.byocTrunks.fetch(sid: Self.sid) }
        reg("voice.v1.byocTrunks.update") { c in _ = try await c.voiceV1.byocTrunks.update(sid: Self.sid, .init()) }
        reg("voice.v1.byocTrunks.delete") { c in try await c.voiceV1.byocTrunks.delete(sid: Self.sid) }
        reg("voice.v1.connectionPolicies.list") { c in _ = try await c.voiceV1.connectionPolicies.list() }
        reg("voice.v1.connectionPolicies.create") { c in _ = try await c.voiceV1.connectionPolicies.create() }
        reg("voice.v1.connectionPolicies.fetch") { c in _ = try await c.voiceV1.connectionPolicies.fetch(sid: Self.connectionPolicySid) }
        reg("voice.v1.connectionPolicies.update") { c in _ = try await c.voiceV1.connectionPolicies.update(sid: Self.connectionPolicySid) }
        reg("voice.v1.connectionPolicies.delete") { c in try await c.voiceV1.connectionPolicies.delete(sid: Self.connectionPolicySid) }
        reg("voice.v1.connectionPolicies.targets.list") { c in _ = try await c.voiceV1.connectionPolicies.listTargets(connectionPolicySid: Self.connectionPolicySid) }
        reg("voice.v1.connectionPolicies.targets.create") { c in _ = try await c.voiceV1.connectionPolicies.createTarget(connectionPolicySid: Self.connectionPolicySid, .init(target: "sip:a@example.com")) }
        reg("voice.v1.connectionPolicies.targets.fetch") { c in _ = try await c.voiceV1.connectionPolicies.fetchTarget(connectionPolicySid: Self.connectionPolicySid, sid: Self.sid) }
        reg("voice.v1.connectionPolicies.targets.update") { c in _ = try await c.voiceV1.connectionPolicies.updateTarget(connectionPolicySid: Self.connectionPolicySid, sid: Self.sid, .init(friendlyName: "t")) }
        reg("voice.v1.connectionPolicies.targets.delete") { c in try await c.voiceV1.connectionPolicies.deleteTarget(connectionPolicySid: Self.connectionPolicySid, sid: Self.sid) }
        reg("voice.v1.dialingPermissions.settings.fetch") { c in _ = try await c.voiceV1.settings.fetch() }
        reg("voice.v1.dialingPermissions.settings.update") { c in _ = try await c.voiceV1.settings.update() }

        // -- Monitor v1 Alerts (default host)
        reg("monitor.v1.alerts.list") { c in _ = try await c.monitorAlerts.list() }
        reg("monitor.v1.alerts.fetch") { c in _ = try await c.monitorAlerts.fetch(sid: Self.sid) }

        // -- Conversations v1 (conversations host)
        let ch = "conversations.voicetel.com"
        reg("conversations.v1.conversations.list", host: ch) { c in _ = try await c.conversationsV1.conversations.list() }
        reg("conversations.v1.conversations.create", host: ch) { c in _ = try await c.conversationsV1.conversations.create() }
        reg("conversations.v1.conversations.fetch", host: ch) { c in _ = try await c.conversationsV1.conversations.fetch(conversationSid: Self.conversationSid) }
        reg("conversations.v1.conversations.update", host: ch) { c in _ = try await c.conversationsV1.conversations.update(conversationSid: Self.conversationSid, .init()) }
        reg("conversations.v1.conversations.delete", host: ch) { c in try await c.conversationsV1.conversations.delete(conversationSid: Self.conversationSid) }
        reg("conversations.v1.conversations.messages.list", host: ch) { c in _ = try await c.conversationsV1.conversations.messages(conversationSid: Self.conversationSid).list() }
        reg("conversations.v1.conversations.messages.create", host: ch) { c in _ = try await c.conversationsV1.conversations.messages(conversationSid: Self.conversationSid).create() }
        reg("conversations.v1.conversations.messages.fetch", host: ch) { c in _ = try await c.conversationsV1.conversations.messages(conversationSid: Self.conversationSid).fetch(messageSid: Self.messageSid) }
        reg("conversations.v1.conversations.messages.update", host: ch) { c in _ = try await c.conversationsV1.conversations.messages(conversationSid: Self.conversationSid).update(messageSid: Self.messageSid, .init()) }
        reg("conversations.v1.conversations.messages.delete", host: ch) { c in try await c.conversationsV1.conversations.messages(conversationSid: Self.conversationSid).delete(messageSid: Self.messageSid) }
        reg("conversations.v1.conversations.messages.receipts.list", host: ch) { c in _ = try await c.conversationsV1.conversations.messages(conversationSid: Self.conversationSid).receipts(messageSid: Self.messageSid).list() }
        reg("conversations.v1.conversations.messages.receipts.fetch", host: ch) { c in _ = try await c.conversationsV1.conversations.messages(conversationSid: Self.conversationSid).receipts(messageSid: Self.messageSid).fetch(sid: Self.sid) }
        reg("conversations.v1.conversations.participants.list", host: ch) { c in _ = try await c.conversationsV1.conversations.participants(conversationSid: Self.conversationSid).list() }
        reg("conversations.v1.conversations.participants.create", host: ch) { c in _ = try await c.conversationsV1.conversations.participants(conversationSid: Self.conversationSid).create() }
        reg("conversations.v1.conversations.participants.fetch", host: ch) { c in _ = try await c.conversationsV1.conversations.participants(conversationSid: Self.conversationSid).fetch(participantSid: Self.participantSid) }
        reg("conversations.v1.conversations.participants.update", host: ch) { c in _ = try await c.conversationsV1.conversations.participants(conversationSid: Self.conversationSid).update(participantSid: Self.participantSid, .init()) }
        reg("conversations.v1.conversations.participants.delete", host: ch) { c in try await c.conversationsV1.conversations.participants(conversationSid: Self.conversationSid).delete(participantSid: Self.participantSid) }
        reg("conversations.v1.conversations.webhooks.list", host: ch) { c in _ = try await c.conversationsV1.conversations.webhooks(conversationSid: Self.conversationSid).list() }
        reg("conversations.v1.conversations.webhooks.create", host: ch) { c in _ = try await c.conversationsV1.conversations.webhooks(conversationSid: Self.conversationSid).create(.init(target: "webhook")) }
        reg("conversations.v1.conversations.webhooks.fetch", host: ch) { c in _ = try await c.conversationsV1.conversations.webhooks(conversationSid: Self.conversationSid).fetch(webhookSid: Self.webhookSid) }
        reg("conversations.v1.conversations.webhooks.update", host: ch) { c in _ = try await c.conversationsV1.conversations.webhooks(conversationSid: Self.conversationSid).update(webhookSid: Self.webhookSid, .init()) }
        reg("conversations.v1.conversations.webhooks.delete", host: ch) { c in try await c.conversationsV1.conversations.webhooks(conversationSid: Self.conversationSid).delete(webhookSid: Self.webhookSid) }
        reg("conversations.v1.roles.list", host: ch) { c in _ = try await c.conversationsV1.roles.list() }
        reg("conversations.v1.roles.create", host: ch) { c in _ = try await c.conversationsV1.roles.create(.init(friendlyName: "r", type: "deployment", permission: ["sendMessage"])) }
        reg("conversations.v1.roles.fetch", host: ch) { c in _ = try await c.conversationsV1.roles.fetch(sid: Self.sid) }
        reg("conversations.v1.roles.update", host: ch) { c in _ = try await c.conversationsV1.roles.update(sid: Self.sid, .init(permission: ["sendMessage"])) }
        reg("conversations.v1.roles.delete", host: ch) { c in try await c.conversationsV1.roles.delete(sid: Self.sid) }
        reg("conversations.v1.users.list", host: ch) { c in _ = try await c.conversationsV1.users.list() }
        reg("conversations.v1.users.create", host: ch) { c in _ = try await c.conversationsV1.users.create(.init(identity: "alice")) }
        reg("conversations.v1.users.fetch", host: ch) { c in _ = try await c.conversationsV1.users.fetch(sid: Self.userSid) }
        reg("conversations.v1.users.update", host: ch) { c in _ = try await c.conversationsV1.users.update(sid: Self.userSid, .init(friendlyName: "a")) }
        reg("conversations.v1.users.delete", host: ch) { c in try await c.conversationsV1.users.delete(sid: Self.userSid) }
        reg("conversations.v1.users.conversations.list", host: ch) { c in _ = try await c.conversationsV1.users.conversations(userSid: Self.userSid).list() }
        reg("conversations.v1.users.conversations.fetch", host: ch) { c in _ = try await c.conversationsV1.users.conversations(userSid: Self.userSid).fetch(conversationSid: Self.conversationSid) }
        reg("conversations.v1.users.conversations.update", host: ch) { c in _ = try await c.conversationsV1.users.conversations(userSid: Self.userSid).update(conversationSid: Self.conversationSid, .init()) }
        reg("conversations.v1.users.conversations.delete", host: ch) { c in try await c.conversationsV1.users.conversations(userSid: Self.userSid).delete(conversationSid: Self.conversationSid) }
        reg("conversations.v1.credentials.list", host: ch) { c in _ = try await c.conversationsV1.credentials.list() }
        reg("conversations.v1.credentials.create", host: ch) { c in _ = try await c.conversationsV1.credentials.create(.init(type: "http", certificate: "x", privateKey: "x")) }
        reg("conversations.v1.credentials.fetch", host: ch) { c in _ = try await c.conversationsV1.credentials.fetch(sid: Self.sid) }
        reg("conversations.v1.credentials.update", host: ch) { c in _ = try await c.conversationsV1.credentials.update(sid: Self.sid, .init()) }
        reg("conversations.v1.credentials.delete", host: ch) { c in try await c.conversationsV1.credentials.delete(sid: Self.sid) }
        reg("conversations.v1.configuration.fetch", host: ch) { c in _ = try await c.conversationsV1.configuration.fetch() }
        reg("conversations.v1.configuration.update", host: ch) { c in _ = try await c.conversationsV1.configuration.update() }
        reg("conversations.v1.configuration.webhooks.fetch", host: ch) { c in _ = try await c.conversationsV1.configuration.webhooks.fetch() }
        reg("conversations.v1.configuration.webhooks.update", host: ch) { c in _ = try await c.conversationsV1.configuration.webhooks.update() }
        reg("conversations.v1.configuration.addresses.list", host: ch) { c in _ = try await c.conversationsV1.configuration.addresses.list() }
        reg("conversations.v1.configuration.addresses.create", host: ch) { c in _ = try await c.conversationsV1.configuration.addresses.create(.init(type: "gbp", address: "x")) }
        reg("conversations.v1.configuration.addresses.fetch", host: ch) { c in _ = try await c.conversationsV1.configuration.addresses.fetch(sid: Self.sid) }
        reg("conversations.v1.configuration.addresses.update", host: ch) { c in _ = try await c.conversationsV1.configuration.addresses.update(sid: Self.sid, .init()) }
        reg("conversations.v1.configuration.addresses.delete", host: ch) { c in try await c.conversationsV1.configuration.addresses.delete(sid: Self.sid) }
        reg("conversations.v1.participantConversations.list", host: ch) { c in _ = try await c.conversationsV1.participantConversations.list() }
        reg("conversations.v1.conversationWithParticipants.create", host: ch) { c in _ = try await c.conversationsV1.conversationWithParticipants.create() }
        reg("conversations.v1.services.list", host: ch) { c in _ = try await c.conversationsV1.services.list() }
        reg("conversations.v1.services.create", host: ch) { c in _ = try await c.conversationsV1.services.create(.init(friendlyName: "svc")) }
        reg("conversations.v1.services.fetch", host: ch) { c in _ = try await c.conversationsV1.services.fetch(chatServiceSid: Self.chatServiceSid) }
        reg("conversations.v1.services.delete", host: ch) { c in try await c.conversationsV1.services.delete(chatServiceSid: Self.chatServiceSid) }

        // -- Service-scoped Conversations v1 (conversations host)
        let svc: @Sendable (VoiceMLClient) -> ConversationsV1ServiceScopeResource = { c in c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid) }
        reg("conversations.v1.services.conversations.list", host: ch) { c in _ = try await svc(c).conversations.list() }
        reg("conversations.v1.services.conversations.create", host: ch) { c in _ = try await svc(c).conversations.create() }
        reg("conversations.v1.services.conversations.fetch", host: ch) { c in _ = try await svc(c).conversations.fetch(conversationSid: Self.conversationSid) }
        reg("conversations.v1.services.conversations.update", host: ch) { c in _ = try await svc(c).conversations.update(conversationSid: Self.conversationSid, .init()) }
        reg("conversations.v1.services.conversations.delete", host: ch) { c in try await svc(c).conversations.delete(conversationSid: Self.conversationSid) }
        reg("conversations.v1.services.conversations.messages.list", host: ch) { c in _ = try await svc(c).conversations.messages(conversationSid: Self.conversationSid).list() }
        reg("conversations.v1.services.conversations.messages.create", host: ch) { c in _ = try await svc(c).conversations.messages(conversationSid: Self.conversationSid).create() }
        reg("conversations.v1.services.conversations.messages.fetch", host: ch) { c in _ = try await svc(c).conversations.messages(conversationSid: Self.conversationSid).fetch(messageSid: Self.messageSid) }
        reg("conversations.v1.services.conversations.messages.update", host: ch) { c in _ = try await svc(c).conversations.messages(conversationSid: Self.conversationSid).update(messageSid: Self.messageSid, .init()) }
        reg("conversations.v1.services.conversations.messages.delete", host: ch) { c in try await svc(c).conversations.messages(conversationSid: Self.conversationSid).delete(messageSid: Self.messageSid) }
        reg("conversations.v1.services.conversations.messages.receipts.list", host: ch) { c in _ = try await svc(c).conversations.messages(conversationSid: Self.conversationSid).receipts(messageSid: Self.messageSid).list() }
        reg("conversations.v1.services.conversations.messages.receipts.fetch", host: ch) { c in _ = try await svc(c).conversations.messages(conversationSid: Self.conversationSid).receipts(messageSid: Self.messageSid).fetch(sid: Self.sid) }
        reg("conversations.v1.services.conversations.participants.list", host: ch) { c in _ = try await svc(c).conversations.participants(conversationSid: Self.conversationSid).list() }
        reg("conversations.v1.services.conversations.participants.create", host: ch) { c in _ = try await svc(c).conversations.participants(conversationSid: Self.conversationSid).create() }
        reg("conversations.v1.services.conversations.participants.fetch", host: ch) { c in _ = try await svc(c).conversations.participants(conversationSid: Self.conversationSid).fetch(participantSid: Self.participantSid) }
        reg("conversations.v1.services.conversations.participants.update", host: ch) { c in _ = try await svc(c).conversations.participants(conversationSid: Self.conversationSid).update(participantSid: Self.participantSid, .init()) }
        reg("conversations.v1.services.conversations.participants.delete", host: ch) { c in try await svc(c).conversations.participants(conversationSid: Self.conversationSid).delete(participantSid: Self.participantSid) }
        reg("conversations.v1.services.conversations.webhooks.list", host: ch) { c in _ = try await svc(c).conversations.webhooks(conversationSid: Self.conversationSid).list() }
        reg("conversations.v1.services.conversations.webhooks.create", host: ch) { c in _ = try await svc(c).conversations.webhooks(conversationSid: Self.conversationSid).create(.init(target: "webhook")) }
        reg("conversations.v1.services.conversations.webhooks.fetch", host: ch) { c in _ = try await svc(c).conversations.webhooks(conversationSid: Self.conversationSid).fetch(webhookSid: Self.webhookSid) }
        reg("conversations.v1.services.conversations.webhooks.update", host: ch) { c in _ = try await svc(c).conversations.webhooks(conversationSid: Self.conversationSid).update(webhookSid: Self.webhookSid, .init()) }
        reg("conversations.v1.services.conversations.webhooks.delete", host: ch) { c in try await svc(c).conversations.webhooks(conversationSid: Self.conversationSid).delete(webhookSid: Self.webhookSid) }
        reg("conversations.v1.services.roles.list", host: ch) { c in _ = try await svc(c).roles.list() }
        reg("conversations.v1.services.roles.create", host: ch) { c in _ = try await svc(c).roles.create(.init(friendlyName: "r", type: "conversation", permission: ["sendMessage"])) }
        reg("conversations.v1.services.roles.fetch", host: ch) { c in _ = try await svc(c).roles.fetch(sid: Self.sid) }
        reg("conversations.v1.services.roles.update", host: ch) { c in _ = try await svc(c).roles.update(sid: Self.sid, .init(permission: ["sendMessage"])) }
        reg("conversations.v1.services.roles.delete", host: ch) { c in try await svc(c).roles.delete(sid: Self.sid) }
        reg("conversations.v1.services.users.list", host: ch) { c in _ = try await svc(c).users.list() }
        reg("conversations.v1.services.users.create", host: ch) { c in _ = try await svc(c).users.create(.init(identity: "bob")) }
        reg("conversations.v1.services.users.fetch", host: ch) { c in _ = try await svc(c).users.fetch(sid: Self.userSid) }
        reg("conversations.v1.services.users.update", host: ch) { c in _ = try await svc(c).users.update(sid: Self.userSid, .init(friendlyName: "b")) }
        reg("conversations.v1.services.users.delete", host: ch) { c in try await svc(c).users.delete(sid: Self.userSid) }
        reg("conversations.v1.services.conversationWithParticipants.create", host: ch) { c in _ = try await svc(c).conversationWithParticipants.create() }
        reg("conversations.v1.services.participantConversations.list", host: ch) { c in _ = try await svc(c).participantConversations.list() }
        reg("conversations.v1.services.users.userConversations.list", host: ch) { c in _ = try await svc(c).users.conversations(userSid: Self.userSid).list() }
        reg("conversations.v1.services.bindings.list", host: ch) { c in _ = try await svc(c).bindings.list() }
        reg("conversations.v1.services.bindings.fetch", host: ch) { c in _ = try await svc(c).bindings.fetch(sid: Self.sid) }
        reg("conversations.v1.services.bindings.delete", host: ch) { c in try await svc(c).bindings.delete(sid: Self.sid) }
        reg("conversations.v1.services.configuration.fetch", host: ch) { c in _ = try await svc(c).configuration.fetch() }
        reg("conversations.v1.services.configuration.update", host: ch) { c in _ = try await svc(c).configuration.update() }
        reg("conversations.v1.services.configuration.notifications.fetch", host: ch) { c in _ = try await svc(c).configuration.notifications.fetch() }
        reg("conversations.v1.services.configuration.notifications.update", host: ch) { c in _ = try await svc(c).configuration.notifications.update() }
        reg("conversations.v1.services.configuration.webhooks.fetch", host: ch) { c in _ = try await svc(c).configuration.webhooks.fetch() }
        reg("conversations.v1.services.configuration.webhooks.update", host: ch) { c in _ = try await svc(c).configuration.webhooks.update() }

        // -- Messaging v1 (messaging host)
        let mh = "messaging.voicetel.com"
        reg("messaging.v1.services.update", host: mh) { c in _ = try await c.messagingV1.services.update(sid: Self.chatServiceSid, .init(friendlyName: "s2")) }
        reg("messaging.v1.services.phoneNumbers.list", host: mh) { c in _ = try await c.messagingV1.services.phoneNumbers(chatServiceSid: Self.chatServiceSid).list() }
        reg("messaging.v1.services.phoneNumbers.create", host: mh) { c in _ = try await c.messagingV1.services.phoneNumbers(chatServiceSid: Self.chatServiceSid).create(.init(phoneNumberSid: Self.sid)) }
        reg("messaging.v1.services.phoneNumbers.fetch", host: mh) { c in _ = try await c.messagingV1.services.phoneNumbers(chatServiceSid: Self.chatServiceSid).fetch(sid: Self.sid) }
        reg("messaging.v1.services.phoneNumbers.delete", host: mh) { c in try await c.messagingV1.services.phoneNumbers(chatServiceSid: Self.chatServiceSid).delete(sid: Self.sid) }

        // -- Assistants v1
        reg("assistants.v1.assistants.list") { c in _ = try await c.assistantsV1.assistants.list() }
        reg("assistants.v1.assistants.create") { c in _ = try await c.assistantsV1.assistants.create(.init(name: "a")) }
        reg("assistants.v1.assistants.fetch") { c in _ = try await c.assistantsV1.assistants.fetch(assistantId: Self.assistantId) }
        reg("assistants.v1.assistants.update") { c in _ = try await c.assistantsV1.assistants.update(assistantId: Self.assistantId, .init()) }
        reg("assistants.v1.assistants.delete") { c in try await c.assistantsV1.assistants.delete(assistantId: Self.assistantId) }
        reg("assistants.v1.tools.list") { c in _ = try await c.assistantsV1.tools.list() }
        reg("assistants.v1.tools.create") { c in _ = try await c.assistantsV1.tools.create(.init(name: "t", type: "http", enabled: true)) }
        reg("assistants.v1.tools.fetch") { c in _ = try await c.assistantsV1.tools.fetch(toolId: Self.toolId) }
        reg("assistants.v1.tools.update") { c in _ = try await c.assistantsV1.tools.update(toolId: Self.toolId, .init()) }
        reg("assistants.v1.tools.delete") { c in try await c.assistantsV1.tools.delete(toolId: Self.toolId) }
        reg("assistants.v1.assistants.tools.list") { c in _ = try await c.assistantsV1.assistants(assistantId: Self.assistantId).tools.list() }
        reg("assistants.v1.assistants.tools.attach") { c in try await c.assistantsV1.assistants(assistantId: Self.assistantId).tools.attach(toolId: Self.toolId) }
        reg("assistants.v1.assistants.tools.detach") { c in try await c.assistantsV1.assistants(assistantId: Self.assistantId).tools.detach(toolId: Self.toolId) }
        reg("assistants.v1.knowledge.list") { c in _ = try await c.assistantsV1.knowledge.list() }
        reg("assistants.v1.knowledge.create") { c in _ = try await c.assistantsV1.knowledge.create(.init(name: "k", type: "text")) }
        reg("assistants.v1.knowledge.fetch") { c in _ = try await c.assistantsV1.knowledge.fetch(knowledgeId: Self.knowledgeId) }
        reg("assistants.v1.knowledge.update") { c in _ = try await c.assistantsV1.knowledge.update(knowledgeId: Self.knowledgeId, .init()) }
        reg("assistants.v1.knowledge.delete") { c in try await c.assistantsV1.knowledge.delete(knowledgeId: Self.knowledgeId) }
        reg("assistants.v1.knowledge.status.fetch") { c in _ = try await c.assistantsV1.knowledge(knowledgeId: Self.knowledgeId).status.fetch() }
        reg("assistants.v1.knowledge.chunks.list") { c in _ = try await c.assistantsV1.knowledge(knowledgeId: Self.knowledgeId).chunks.list() }
        reg("assistants.v1.assistants.knowledge.list") { c in _ = try await c.assistantsV1.assistants(assistantId: Self.assistantId).knowledge.list() }
        reg("assistants.v1.assistants.knowledge.attach") { c in try await c.assistantsV1.assistants(assistantId: Self.assistantId).knowledge.attach(knowledgeId: Self.knowledgeId) }
        reg("assistants.v1.assistants.knowledge.detach") { c in try await c.assistantsV1.assistants(assistantId: Self.assistantId).knowledge.detach(knowledgeId: Self.knowledgeId) }
        reg("assistants.v1.assistants.messages.create") { c in _ = try await c.assistantsV1.assistants(assistantId: Self.assistantId).messages.create(.init(identity: "alice", body: "hi")) }
        reg("assistants.v1.sessions.list") { c in _ = try await c.assistantsV1.sessions.list() }
        reg("assistants.v1.sessions.fetch") { c in _ = try await c.assistantsV1.sessions.fetch(sessionId: Self.sessionId) }
        reg("assistants.v1.sessions.messages.list") { c in _ = try await c.assistantsV1.sessions(sessionId: Self.sessionId).messages.list() }
        reg("assistants.v1.assistants.feedbacks.list") { c in _ = try await c.assistantsV1.assistants(assistantId: Self.assistantId).feedbacks.list() }
        reg("assistants.v1.assistants.feedbacks.create") { c in _ = try await c.assistantsV1.assistants(assistantId: Self.assistantId).feedbacks.create(.init(sessionId: Self.sessionId, score: 5)) }
        reg("assistants.v1.policies.list") { c in _ = try await c.assistantsV1.policies.list() }

        // -- Pricing
        reg("pricing.v1.voice.countries.list") { c in _ = try await c.pricing.v1.voice.countries.list() }
        reg("pricing.v1.voice.countries.fetch") { c in _ = try await c.pricing.v1.voice.countries.fetch(Self.isoCountry) }
        reg("pricing.v1.voice.numbers.fetch") { c in _ = try await c.pricing.v1.voice.numbers.fetch(Self.number) }
        reg("pricing.v1.messaging.countries.list") { c in _ = try await c.pricing.v1.messaging.countries.list() }
        reg("pricing.v1.messaging.countries.fetch") { c in _ = try await c.pricing.v1.messaging.countries.fetch(Self.isoCountry) }
        reg("pricing.v1.phoneNumbers.countries.list") { c in _ = try await c.pricing.v1.phoneNumbers.countries.list() }
        reg("pricing.v1.phoneNumbers.countries.fetch") { c in _ = try await c.pricing.v1.phoneNumbers.countries.fetch(Self.isoCountry) }
        reg("pricing.v2.voice.countries.list") { c in _ = try await c.pricing.v2.voice.countries.list() }
        reg("pricing.v2.voice.countries.fetch") { c in _ = try await c.pricing.v2.voice.countries.fetch(Self.isoCountry) }
        reg("pricing.v2.voice.numbers.fetch") { c in _ = try await c.pricing.v2.voice.numbers.fetch(Self.destinationNumber) }
        reg("pricing.v2.trunking.countries.list") { c in _ = try await c.pricing.v2.trunking.countries.list() }
        reg("pricing.v2.trunking.countries.fetch") { c in _ = try await c.pricing.v2.trunking.countries.fetch(Self.isoCountry) }
        reg("pricing.v2.trunking.numbers.fetch") { c in _ = try await c.pricing.v2.trunking.numbers.fetch(Self.destinationNumber) }

        return e
    }

    // MARK: - Test

    func testContractAgainstVendoredSpec() async throws {
        let spec = try loadSpec()
        let responses = try loadResponses()
        let entries = registry()

        // Coverage: every spec op exercised, no registry entry missing from the spec.
        let specIds = Set(spec.ops.keys)
        let regIds = Set(entries.map(\.opId))
        XCTAssertEqual(specIds.subtracting(regIds).sorted(), [], "spec ops with no SDK invocation")
        XCTAssertEqual(regIds.subtracting(specIds).sorted(), [], "registry entries matching no spec op")
        XCTAssertEqual(specIds.count, 333, "expected 333 spec operations")
        XCTAssertEqual(entries.count, specIds.count, "333/333 coverage")

        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)
        let client = try VoiceMLClient(
            accountSid: Self.accountSid,
            apiKey: Self.apiKey,
            maxRetries: 0,
            session: session
        )

        var failures: [String] = []

        for entry in entries {
            MockResponses.shared.reset()
            guard let op = spec.ops[entry.opId] else { continue }
            let entryName = entry.opId

            // Response fixture for this op.
            let fixture = responses[entry.opId]
            let status = (fixture?["__status__"] as? Int) ?? 200
            let isRaw = (fixture?["__raw__"] as? Bool) == true
            if entry.opId == "exports.download" {
                MockResponses.shared.enqueue(.init(
                    statusCode: 302,
                    body: Data(),
                    headers: ["Location": "https://s3.example.com/exports/x?sig=1"]
                ))
                MockResponses.shared.enqueue(.init(
                    statusCode: 200,
                    body: Data("data".utf8),
                    headers: ["Content-Type": "text/csv"]
                ))
            } else if status == 204 {
                MockResponses.shared.enqueue(.init(statusCode: 204, body: Data(), headers: [:]))
            } else if let body = fixture?["__body__"], !(body is NSNull), !isRaw {
                let data = try JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed])
                MockResponses.shared.enqueue(.init(
                    statusCode: status,
                    body: data,
                    headers: ["Content-Type": "application/json"]
                ))
            } else {
                MockResponses.shared.enqueue(.init(
                    statusCode: 200,
                    body: Data("raw".utf8),
                    headers: ["Content-Type": "application/octet-stream"]
                ))
            }

            do {
                try await entry.invoke(client)
            } catch {
                failures.append("\(entryName): invoke failed: \(error)")
                continue
            }

            let captured = MockResponses.shared.captured
            let expectedRequests = entry.opId == "exports.download" ? 2 : 1
            guard captured.count == expectedRequests else {
                failures.append("\(entryName): expected \(expectedRequests) request(s), saw \(captured.count)")
                continue
            }
            let req = captured[0]

            // 1. Method + path template.
            if req.method != op.method {
                failures.append("\(entryName): method \(req.method) ≠ spec \(op.method)")
            }
            let expectedPath = renderTemplate(op.pathTemplate)
            let actualPath = URLComponents(url: req.url, resolvingAgainstBaseURL: false)?
                .percentEncodedPath ?? req.url.path
            if actualPath != expectedPath {
                failures.append("\(entryName): path \(actualPath) ≠ template \(expectedPath)")
            }

            // 2. Host per tag.
            let specHost: String
            if entry.opId.hasPrefix("messaging.") {
                XCTAssertTrue(op.tags.contains("MessagingV1Service"))
                specHost = "messaging.voicetel.com"
            } else if op.tags.contains(where: { $0.hasPrefix("ConversationsV1") }) {
                specHost = "conversations.voicetel.com"
            } else {
                specHost = "voiceml.voicetel.com"
            }
            XCTAssertEqual(entry.host, specHost, "\(entryName): registry host must match spec tags")
            if req.url.host != entry.host {
                failures.append("\(entryName): host \(req.url.host ?? "?") ≠ expected \(entry.host)")
            }

            // 3. Auth per security.
            let hasAuthHeader = req.headers["Authorization"] != nil
            if op.hasAuth && !hasAuthHeader {
                failures.append("\(entryName): missing Authorization on an authenticated op")
            }
            if !op.hasAuth && hasAuthHeader {
                failures.append("\(entryName): Authorization sent on an unauthenticated op")
            }

            // 4. Query keys ⊆ spec query params.
            var sentQuery = Set<String>()
            if let q = URLComponents(url: req.url, resolvingAgainstBaseURL: false)?.percentEncodedQuery {
                for pair in q.split(separator: "&") {
                    let name = String(pair.split(separator: "=")[0]).removingPercentEncoding ?? String(pair.split(separator: "=")[0])
                    sentQuery.insert(name)
                }
            }
            if !op.queryNames.isSuperset(of: sentQuery) {
                failures.append("\(entryName): query keys \(sentQuery.sorted()) not in spec params; allowed \(op.queryNames.sorted())")
            }
            if !sentQuery.isSuperset(of: op.requiredQuery) {
                failures.append("\(entryName): required query params \(op.requiredQuery.subtracting(sentQuery).sorted()) missing")
            }

            // 5. Body keys ⊆ spec body props.
            do {
                var sentBody = Set<String>()
                let contentType = req.headers["Content-Type"] ?? ""
                if contentType.contains("application/json"),
                   let obj = try? JSONSerialization.jsonObject(with: req.body) as? [String: Any] {
                    sentBody = Set(obj.keys)
                } else if let s = String(data: req.body, encoding: .utf8) {
                    for pair in s.split(separator: "&") {
                        let name = String(pair.split(separator: "=")[0]).removingPercentEncoding ?? String(pair.split(separator: "=")[0])
                        sentBody.insert(name)
                    }
                }
                if !sentBody.isEmpty && !op.bodyProps.isSuperset(of: sentBody) {
                    failures.append("\(entryName): body keys \(sentBody.sorted()) not in spec props; allowed \(op.bodyProps.sorted())")
                }
                if !sentBody.isSuperset(of: op.requiredBody) {
                    failures.append("\(entryName): required body props \(op.requiredBody.subtracting(sentBody).sorted()) missing")
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, "contract failures (\(failures.count)):\n" + failures.joined(separator: "\n"))
    }

    /// Substitute sentinels into a path template and percent-encode each segment.
    private func renderTemplate(_ template: String) -> String {
        var sentinels: [String: String] = [
            "AccountSid": Self.accountSid,
            "Sid": Self.sid,
            "CallSid": Self.callSid,
            "ConferenceSid": Self.conferenceSid,
            "RecordingSid": Self.recordingSid,
            "MessageSid": Self.messageSid,
            "DomainSid": Self.domainSid,
            "CredentialListSid": Self.credentialListSid,
            "IpAccessControlListSid": Self.aclSid,
            "QueueSid": Self.queueSid,
            "ChatServiceSid": Self.chatServiceSid,
            "ConversationSid": Self.conversationSid,
            "ParticipantSid": Self.participantSid,
            "WebhookSid": Self.webhookSid,
            "UserSid": Self.userSid,
            "ConnectionPolicySid": Self.connectionPolicySid,
            "PhoneNumber": Self.phoneNumber,
            "Number": Self.number,
            "DestinationNumber": Self.destinationNumber,
            "SipDomain": Self.sipDomain,
            "IsoCountry": Self.isoCountry,
            "Date": Self.exportDate,
            "id": Self.assistantId,
            "toolId": Self.toolId,
            "knowledgeId": Self.knowledgeId,
        ]
        for (part, value) in [
            ("/Calls/{Sid}", Self.callSid), ("/Conferences/{Sid}", Self.conferenceSid),
            ("/Queues/{Sid}", Self.queueSid), ("/SIP/Domains/{Sid}", Self.domainSid),
            ("/SIP/CredentialLists/{Sid}", Self.credentialListSid),
            ("/SIP/IpAccessControlLists/{Sid}", Self.aclSid), ("/Messages/{Sid}", Self.messageSid),
            ("/Recordings/{Sid}", Self.recordingSid), ("/Payments/{Sid}", Self.paymentSid),
            ("/Users/{Sid}", Self.userSid), ("/Services/{Sid}", Self.chatServiceSid),
        ] where template.contains(part) {
            sentinels["Sid"] = value
        }
        if template == "/2010-04-01/Accounts/{Sid}.json" { sentinels["Sid"] = Self.accountSid }
        if template.hasPrefix("/v1/Tools/") { sentinels["id"] = Self.toolId }
        if template.hasPrefix("/v1/Knowledge/") { sentinels["id"] = Self.knowledgeId }
        if template.hasPrefix("/v1/Sessions/") { sentinels["id"] = Self.sessionId }
        var rendered = template
        for (key, value) in sentinels {
            rendered = rendered.replacingOccurrences(of: "{\(key)}", with: percentEncodePathSegment(value))
        }
        return rendered
    }
}
