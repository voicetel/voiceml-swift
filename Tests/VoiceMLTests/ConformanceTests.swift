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
            XCTAssertFalse(v.sid.isEmpty, "\(label): Call.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): Call.account_sid")

        case "ListCall":
            let v = try decoder.decode(CallList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): CallList.uri")

        case "FetchConference", "UpdateConference":
            let v = try decoder.decode(Conference.self, from: body)
            XCTAssertFalse(v.sid.isEmpty, "\(label): Conference.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): Conference.account_sid")

        case "ListConference":
            let v = try decoder.decode(ConferenceList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): ConferenceList.uri")

        case "CreateParticipant", "FetchParticipant", "UpdateParticipant":
            let v = try decoder.decode(Participant.self, from: body)
            XCTAssertFalse(v.callSid.isEmpty, "\(label): Participant.call_sid")
            XCTAssertFalse(v.conferenceSid.isEmpty, "\(label): Participant.conference_sid")

        case "ListParticipant":
            let v = try decoder.decode(ParticipantList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): ParticipantList.uri")

        case "CreateQueue", "FetchQueue", "UpdateQueue":
            let v = try decoder.decode(Queue.self, from: body)
            XCTAssertFalse(v.sid.isEmpty, "\(label): Queue.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): Queue.account_sid")

        case "ListQueue":
            let v = try decoder.decode(QueueList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): QueueList.uri")

        case "FetchMember", "UpdateMember":
            let v = try decoder.decode(QueueMember.self, from: body)
            XCTAssertFalse(v.callSid.isEmpty, "\(label): QueueMember.call_sid")

        case "ListMember":
            let v = try decoder.decode(QueueMemberList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): QueueMemberList.uri")

        case "CreateApplication", "FetchApplication", "UpdateApplication":
            let v = try decoder.decode(Application.self, from: body)
            XCTAssertFalse(v.sid.isEmpty, "\(label): Application.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): Application.account_sid")

        case "ListApplication":
            let v = try decoder.decode(ApplicationList.self, from: body)
            XCTAssertFalse((v.uri ?? "").isEmpty, "\(label): ApplicationList.uri")

        case "CreateCallRecording", "FetchCallRecording", "UpdateCallRecording",
             "FetchRecording", "FetchConferenceRecording", "UpdateConferenceRecording":
            let v = try decoder.decode(Recording.self, from: body)
            XCTAssertFalse(v.sid.isEmpty, "\(label): Recording.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): Recording.account_sid")

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
            XCTAssertFalse(v.sid.isEmpty, "\(label): IncomingPhoneNumber.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): IncomingPhoneNumber.account_sid")

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
            XCTAssertFalse(v.sid.isEmpty, "\(label): Stream.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): Stream.account_sid")
            XCTAssertFalse(v.callSid.isEmpty, "\(label): Stream.call_sid")

        case "CreateSiprec", "UpdateSiprec":
            let v = try decoder.decode(SiprecSession.self, from: body)
            XCTAssertFalse(v.sid.isEmpty, "\(label): SiprecSession.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): SiprecSession.account_sid")
            XCTAssertFalse(v.callSid.isEmpty, "\(label): SiprecSession.call_sid")

        case "CreateRealtimeTranscription", "UpdateRealtimeTranscription":
            let v = try decoder.decode(CallTranscription.self, from: body)
            XCTAssertFalse(v.sid.isEmpty, "\(label): CallTranscription.sid")
            XCTAssertFalse(v.accountSid.isEmpty, "\(label): CallTranscription.account_sid")
            XCTAssertFalse(v.callSid.isEmpty, "\(label): CallTranscription.call_sid")

        default:
            XCTFail("conformance harness: no mapping for operation_id=\(opId). Add a case or extend skipOps.")
        }
    }
}
