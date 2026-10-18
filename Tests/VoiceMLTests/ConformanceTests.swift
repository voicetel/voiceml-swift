import XCTest
@testable import VoiceML

// Twilio response-shape conformance tests (#330 Phase C). Mirrors the
// Go (voiceml-go-sdk@d6ac75c), Python (voiceml-python-sdk), TypeScript
// (voiceml-node-sdk@a11b0a1), Java (voiceml-java-sdk@9178659), C#
// (voiceml-csharp-sdk@087679f), PHP (voiceml-php-sdk@4267511), and Ruby
// (voiceml-ruby-sdk@203e555) harnesses: load 132 canonical Twilio
// response examples from callBroadcast's
// cmd/twilio-conformance-fixtures, decode each into the matching SDK
// model via JSONDecoder, assert key fields. SKIPPED unless
// VOICEML_CONFORMANCE_FIXTURES env points at the corpus.
//
// Strictness: Codable + JSONDecoder throws on type mismatch, missing
// required (non-optional) properties, and unknown enum values — same
// shape as Go's json.Unmarshal strictness, Pydantic strict mode, and
// the Java Jackson harness. Required-field enforcement is the
// XCTAssertFalse on isEmpty post-decode.
//
// Run:
//
//   VOICEML_CONFORMANCE_FIXTURES=/path/to/callBroadcast/cmd/twilio-conformance-fixtures/fixtures \
//     swift test --filter ConformanceTests
final class ConformanceTests: XCTestCase {

    private static let fixturesEnv = "VOICEML_CONFORMANCE_FIXTURES"

    // Operation IDs with no SDK model — same skip set as the other SDKs.
    private static let skipOps: Set<String> = [
        "ListCallEvent",
        "ListCallNotification",
        "FetchCallNotification",
        "ListNotification",
        "FetchNotification",
        "CreateUserDefinedMessage",
        "CreateMessage",
        "FetchMessage",
        "ListMessage",
        "UpdateMessage",
    ]

    private struct ConformanceEntry: Decodable {
        let resource: String
        let method: String
        let status: String
        let operationId: String
        let exampleName: String
        let path: String
        let file: String

        enum CodingKeys: String, CodingKey {
            case resource, method, status, path, file
            case operationId = "operation_id"
            case exampleName = "example_name"
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testTwilioFixtureConformance() throws {
        guard let root = ProcessInfo.processInfo.environment[Self.fixturesEnv], !root.isEmpty else {
            throw XCTSkip("\(Self.fixturesEnv) not set; skipping conformance fixtures")
        }
        let rootURL = URL(fileURLWithPath: root)
        let indexURL = rootURL.appendingPathComponent("index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw XCTSkip("index.json missing at \(indexURL.path)")
        }

        // index.json uses snake_case keys for the entry metadata.
        let indexDecoder = JSONDecoder()
        indexDecoder.keyDecodingStrategy = .useDefaultKeys
        let indexData = try Data(contentsOf: indexURL)
        let entries = try indexDecoder.decode([ConformanceEntry].self, from: indexData)
        XCTAssertFalse(entries.isEmpty, "empty fixture corpus")

        let decoder = makeDecoder()

        for entry in entries {
            if Self.skipOps.contains(entry.operationId) { continue }
            let fixtureURL = rootURL.appendingPathComponent(entry.file)
            let body: Data
            do {
                body = try Data(contentsOf: fixtureURL)
            } catch {
                XCTFail("\(entry.operationId)/\(entry.exampleName): read fixture failed: \(error)")
                continue
            }
            do {
                try runOne(opId: entry.operationId, exampleName: entry.exampleName, body: body, decoder: decoder)
            } catch {
                XCTFail("\(entry.operationId)/\(entry.exampleName): \(error)")
            }
        }
    }

    private func runOne(opId: String, exampleName: String, body: Data, decoder: JSONDecoder) throws {
        let label = "\(opId)/\(exampleName)"

        switch opId {
        case "CreateCall", "FetchCall", "UpdateCall":
            let v = try decoder.decode(Call.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Call.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Call.account_sid")

        case "ListCall":
            let v = try decoder.decode(CallList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): CallList.uri")

        case "FetchConference", "UpdateConference":
            let v = try decoder.decode(Conference.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Conference.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Conference.account_sid")

        case "ListConference":
            let v = try decoder.decode(ConferenceList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): ConferenceList.uri")

        case "CreateParticipant", "FetchParticipant", "UpdateParticipant":
            let v = try decoder.decode(Participant.self, from: body)
            XCTAssertFalse(v.callSid?.isEmpty ?? true, "\(label): Participant.call_sid")
            XCTAssertFalse(v.conferenceSid?.isEmpty ?? true, "\(label): Participant.conference_sid")

        case "ListParticipant":
            let v = try decoder.decode(ParticipantList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): ParticipantList.uri")

        case "CreateQueue", "FetchQueue", "UpdateQueue":
            let v = try decoder.decode(Queue.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Queue.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Queue.account_sid")

        case "ListQueue":
            let v = try decoder.decode(QueueList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): QueueList.uri")

        case "FetchMember", "UpdateMember":
            let v = try decoder.decode(QueueMember.self, from: body)
            XCTAssertFalse(v.callSid?.isEmpty ?? true, "\(label): QueueMember.call_sid")

        case "ListMember":
            let v = try decoder.decode(QueueMemberList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): QueueMemberList.uri")

        case "CreateApplication", "FetchApplication", "UpdateApplication":
            let v = try decoder.decode(Application.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Application.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Application.account_sid")

        case "ListApplication":
            let v = try decoder.decode(ApplicationList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): ApplicationList.uri")

        case "CreateCallRecording", "FetchCallRecording", "UpdateCallRecording",
             "FetchRecording", "FetchConferenceRecording", "UpdateConferenceRecording":
            let v = try decoder.decode(Recording.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Recording.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Recording.account_sid")

        case "ListCallRecording", "ListRecording", "ListConferenceRecording":
            let v = try decoder.decode(RecordingList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): RecordingList.uri")

        case "CreateIncomingPhoneNumber",
             "CreateIncomingPhoneNumberLocal",
             "CreateIncomingPhoneNumberMobile",
             "CreateIncomingPhoneNumberTollFree",
             "FetchIncomingPhoneNumber",
             "UpdateIncomingPhoneNumber":
            let v = try decoder.decode(IncomingPhoneNumber.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): IncomingPhoneNumber.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): IncomingPhoneNumber.account_sid")

        case "ListIncomingPhoneNumber",
             "ListIncomingPhoneNumberLocal",
             "ListIncomingPhoneNumberMobile",
             "ListIncomingPhoneNumberTollFree":
            let v = try decoder.decode(IncomingPhoneNumberList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): IncomingPhoneNumberList.uri")

        // Stream / SiprecSession / CallTranscription Create/Update fixtures
        // don't emit api_version. The three structs declare it `apiVersion:
        // String?` (mirrors the TS SDK's fix-forward at voiceml-node-sdk@a11b0a1)
        // so the missing field decodes to nil instead of throwing keyNotFound.
        // sid/account_sid/call_sid asserted here; api_version not enforced.
        case "CreateStream", "UpdateStream":
            // Disambiguate against Foundation.Stream (an unrelated abstract class).
            let v = try decoder.decode(VoiceML.Stream.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Stream.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Stream.account_sid")
            XCTAssertFalse(v.callSid?.isEmpty ?? true, "\(label): Stream.call_sid")

        case "CreateSiprec", "UpdateSiprec":
            let v = try decoder.decode(SiprecSession.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SiprecSession.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SiprecSession.account_sid")
            XCTAssertFalse(v.callSid?.isEmpty ?? true, "\(label): SiprecSession.call_sid")

        case "CreateRealtimeTranscription", "UpdateRealtimeTranscription":
            let v = try decoder.decode(CallTranscription.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): CallTranscription.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): CallTranscription.account_sid")
            XCTAssertFalse(v.callSid?.isEmpty ?? true, "\(label): CallTranscription.call_sid")

        // Account/Balance/Payments/OutgoingCallerIds/Media/RecordingTranscriptions/
        // SIP-Auth mappings: modelled here for fixture-driven conformance —
        // the SDK doesn't surface these as first-class resource clients yet,
        // but the Codable shapes ensure we don't ship drifted models when
        // they are wired up.
        case "FetchAccount", "UpdateAccount":
            let v = try decoder.decode(Account.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Account.sid")
            XCTAssertFalse(v.ownerAccountSid?.isEmpty ?? true, "\(label): Account.owner_account_sid")

        case "FetchBalance":
            let v = try decoder.decode(Balance.self, from: body)
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Balance.account_sid")
            XCTAssertFalse(v.currency?.isEmpty ?? true, "\(label): Balance.currency")

        case "CreatePayments", "UpdatePayments":
            let v = try decoder.decode(CallPayment.self, from: body)
            XCTAssertFalse(v.sid.isEmpty, "\(label): CallPayment.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): CallPayment.account_sid")
            XCTAssertFalse(v.callSid.isEmpty, "\(label): CallPayment.call_sid")

        case "FetchOutgoingCallerId", "UpdateOutgoingCallerId":
            let v = try decoder.decode(OutgoingCallerId.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): OutgoingCallerId.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): OutgoingCallerId.account_sid")

        case "ListOutgoingCallerId":
            let v = try decoder.decode(OutgoingCallerIdList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): OutgoingCallerIdList.uri")

        case "CreateValidationRequest":
            // ValidationRequest has no sid (Twilio returns a verification
            // code instead). Assert account_sid + validation_code.
            let v = try decoder.decode(ValidationRequest.self, from: body)
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): ValidationRequest.account_sid")
            XCTAssertFalse(v.validationCode?.isEmpty ?? true, "\(label): ValidationRequest.validation_code")

        case "FetchMedia":
            let v = try decoder.decode(Media.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): Media.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): Media.account_sid")

        case "ListMedia":
            let v = try decoder.decode(MediaList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): MediaList.uri")

        case "FetchRecordingTranscription", "FetchTranscription":
            let v = try decoder.decode(RecordingTranscription.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): RecordingTranscription.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): RecordingTranscription.account_sid")
            XCTAssertFalse(v.recordingSid?.isEmpty ?? true, "\(label): RecordingTranscription.recording_sid")

        case "ListRecordingTranscription", "ListTranscription":
            let v = try decoder.decode(RecordingTranscriptionList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): RecordingTranscriptionList.uri")

        // SIP — Domains
        case "CreateSipDomain", "FetchSipDomain", "UpdateSipDomain":
            let v = try decoder.decode(SipDomain.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SipDomain.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SipDomain.account_sid")

        case "ListSipDomain":
            let v = try decoder.decode(SipDomainList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipDomainList.uri")

        // SIP — Credentials
        case "CreateSipCredential", "FetchSipCredential", "UpdateSipCredential":
            let v = try decoder.decode(SipCredential.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SipCredential.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SipCredential.account_sid")

        case "ListSipCredential":
            let v = try decoder.decode(SipCredentialListPage.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipCredentialListPage.uri")

        // SIP — CredentialLists
        case "CreateSipCredentialList", "FetchSipCredentialList", "UpdateSipCredentialList":
            let v = try decoder.decode(SipCredentialList.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SipCredentialList.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SipCredentialList.account_sid")

        case "ListSipCredentialList":
            let v = try decoder.decode(SipCredentialListList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipCredentialListList.uri")

        // SIP — IpAccessControlLists
        case "CreateSipIpAccessControlList", "FetchSipIpAccessControlList", "UpdateSipIpAccessControlList":
            let v = try decoder.decode(SipIpAccessControlList.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SipIpAccessControlList.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SipIpAccessControlList.account_sid")

        case "ListSipIpAccessControlList":
            let v = try decoder.decode(SipIpAccessControlListList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipIpAccessControlListList.uri")

        // SIP — IpAddresses (members of an IpAccessControlList)
        case "CreateSipIpAddress", "FetchSipIpAddress", "UpdateSipIpAddress":
            let v = try decoder.decode(SipIpAddress.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SipIpAddress.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SipIpAddress.account_sid")

        case "ListSipIpAddress":
            let v = try decoder.decode(SipIpAddressList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipIpAddressList.uri")

        // SIP — Domain-scoped mappings (carry uri + domain_sid)
        case "CreateSipCredentialListMapping", "FetchSipCredentialListMapping",
             "CreateSipIpAccessControlListMapping", "FetchSipIpAccessControlListMapping":
            let v = try decoder.decode(SipDomainMapping.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SipDomainMapping.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SipDomainMapping.account_sid")

        case "ListSipCredentialListMapping":
            let v = try decoder.decode(SipCredentialListMappingList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipCredentialListMappingList.uri")

        case "ListSipIpAccessControlListMapping":
            let v = try decoder.decode(SipIpAccessControlListMappingList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipIpAccessControlListMappingList.uri")

        // SIP — Auth subresource mappings (no uri, no domain_sid)
        case "CreateSipAuthCallsCredentialListMapping", "FetchSipAuthCallsCredentialListMapping",
             "CreateSipAuthCallsIpAccessControlListMapping", "FetchSipAuthCallsIpAccessControlListMapping",
             "CreateSipAuthRegistrationsCredentialListMapping", "FetchSipAuthRegistrationsCredentialListMapping":
            let v = try decoder.decode(SipAuthMapping.self, from: body)
            XCTAssertFalse(v.sid?.isEmpty ?? true, "\(label): SipAuthMapping.sid")
            XCTAssertFalse(v.accountSid?.isEmpty ?? true, "\(label): SipAuthMapping.account_sid")

        case "ListSipAuthCallsCredentialListMapping",
             "ListSipAuthCallsIpAccessControlListMapping",
             "ListSipAuthRegistrationsCredentialListMapping":
            let v = try decoder.decode(SipAuthMappingList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): SipAuthMappingList.uri")

        default:
            XCTFail("conformance harness: no mapping for operation_id=\(opId). Add a case or extend skipOps.")
        }
    }
}
