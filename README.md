# 📞 VoiceML Swift SDK

The official Swift client for the [VoiceML REST API](https://voicetel.com/docs/api/v0.7/voiceml/) — Twilio-compatible outbound voice and answering-machine-detection from VoiceTel, with `async/await` throughout and `Sendable` types tuned for Swift Concurrency.

![Version](https://img.shields.io/badge/version-0.7.1.1-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Tests](https://img.shields.io/badge/tests-54%20unit-brightgreen)
![Platforms](https://img.shields.io/badge/platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20tvOS%2015%20%7C%20watchOS%208%20%7C%20Linux-lightgrey)

## 📚 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Quickstart](#-quickstart)
- [Authentication](#-authentication)
- [Resource Reference](#-resource-reference)
- [Error Handling](#-error-handling)
- [Async Support](#-async-support)
- [Pagination](#-pagination)
- [Migration from twilio-swift](#-migration-from-twilio-swift)
- [Rate Limits](#-rate-limits)
- [Development](#-development)
- [API Documentation](#-api-documentation)
- [Contributors](#-contributors)
- [Sponsors](#-sponsors)
- [License](#-license)

## ✨ Features

### 🛡️ Strongly Typed End-to-End
- **Native Swift `Codable` structs** for every one of the 81 API operations — request bodies encoded to `application/x-www-form-urlencoded`, responses decoded via `Foundation.JSONDecoder`, no reflection or codegen.
- **Autocomplete everywhere.** Your IDE knows the shape of every field — `Call.sid`, `Recording.duration`, `Queue.currentSize` are all typed.
- **Twilio-compatible wire shapes** — `AccountSid`, `From`, `To`, status callbacks, pagination envelopes — match what Twilio's Programmable Voice API documents, with idiomatic Swift names (`accountSid`, `from`, `to`) on the surface.

### ⚡ Swift Concurrency First-Class
- Every endpoint is `async throws` — cancellation propagates from your `Task` down to the HTTP layer.
- `VoiceMLClient` is a `Sendable` `final class`, safe to share across actors and isolation domains.
- Page walkers return `AsyncThrowingStream<Element, Error>` so you can `for try await` through every resource.

### 🔁 Production-Grade Transport
- Built on `URLSession` — no third-party dependencies, works on Linux via `FoundationNetworking`.
- **Automatic retry** with exponential backoff on 429 / 5xx — honors `Retry-After` headers.
- **Configurable timeouts** and `maxRetries` per client.
- **HTTP Basic auth** with `AccountSid:apiKey` — exactly what the Twilio API consumes, so existing credentials work unchanged.
- **Structured exception hierarchy** — `RateLimitError`, `AuthenticationError`, `NotFoundError`, etc. all subclasses of `ApiError` (itself a `VoiceMLError`) you can catch broadly or narrowly with Swift's typed `catch`.

### 📞 Complete API Coverage
- **Calls** — originate, fetch, terminate, update + per-call recordings, streams, siprec, transcriptions, notifications, events, and the `/Calls/{sid}/Payments` lifecycle (Pay TwiML companion).
- **Conferences** — list, fetch, end conferences, plus participants (mute / hold / kick) and conference-scoped recordings.
- **Queues** — create, list, update, delete, peek, dequeue (front or specific member).
- **Applications** — CRUD on stored TwiML + callback bundles.
- **Recordings** — account-wide list, metadata fetch, audio fetch (follows S3 redirect), delete.
- **Messages** — create, fetch, list (To/From/DateSent filters + pagination), update (Body redaction; Status=canceled), delete.
- **IncomingPhoneNumbers** — list, fetch, update.
- **Notifications** — fetch, list.
- **Diagnostics** — `/health` deep probe, OpenAPI spec.

### 🧪 Tested
- **54 unit tests** across smoke and conformance suites — every resource method exercised against a `URLProtocol` mock, every error path checked for the correct typed subclass.
- CI builds with `-warnings-as-errors`; no warning suppression anywhere in the source tree.

### 📦 Clean Distribution
- Single Swift Package (`VoiceML`) — Foundation-only, zero external dependencies.
- Linux build is first-class (`swift:6.0.3` container in CI).
- Hand-written end to end — no codegen.

## 🚀 Installation

### Swift Package Manager (recommended)

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/voicetel/voiceml-swift", from: "0.7.1.1"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "VoiceML", package: "voiceml-swift")
    ]),
]
```

### Requirements

- Swift 5.9 or later
- Apple platforms: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+
- Linux: any distribution with the Swift toolchain (Foundation + `FoundationNetworking` only — no Apple-specific dependencies)

## 🏁 Quickstart

```swift
import VoiceML

let client = try VoiceMLClient(accountSid: "AC…", apiKey: "…")

// Place a call.
let call = try await client.calls.create(.init(
    to: "+18005551234",
    from: "+18005550000",
    url: "https://example.com/twiml",
    machineDetection: .detectMessageEnd
))
print(call.sid, call.status)

// Walk every queue on the account.
for try await queue in client.queues.iterate() {
    print(queue.friendlyName, queue.currentSize)
}
```

## 🔑 Authentication

Every endpoint uses **HTTP Basic** with your `AccountSid` as the username and your per-tenant API key as the password — identical to Twilio's auth shape, so credentials issued for Twilio code work here unchanged.

```swift
let client = try VoiceMLClient(accountSid: "AC…", apiKey: "…")
let health = try await client.diagnostics.health()
```

The Swift constructor also accepts `authToken:` as an alias for `apiKey:` (Twilio's terminology for the same Basic-auth password). Passing both throws `ConfigurationError` rather than silently picking one.

> Don't have credentials yet? See **[voicetel.com/docs/api/v0.7/voiceml/](https://voicetel.com/docs/api/v0.7/voiceml/)** for issuance and rotation.

## 🗺️ Resource Reference

| Resource | Methods | Covers |
|---|---|---|
| `client.calls` | `create`, `get`, `list`, `iterate`, `update`, `delete` | + per-call recordings, streams, siprec, transcriptions, notifications, events, `startPayment` / `updatePayment` |
| `client.conferences` | `list`, `get`, `end` | participants (mute / hold / kick), conference-scoped recordings |
| `client.queues` | `create`, `list`, `iterate`, `get`, `update`, `delete` | `peekFront`, `dequeueFront`, `getMember`, `dequeueMember` |
| `client.applications` | CRUD on TwiML + callback bundles | |
| `client.recordings` | account-wide list, metadata, audio fetch, delete | follows S3 redirect for audio |
| `client.messages` | `create`, `fetch`, `list`, `iterate`, `update`, `delete` | To/From/DateSent filters; Body redaction; Status=canceled |
| `client.incomingPhoneNumbers` | `list`, `fetch`, `update` | |
| `client.notifications` | `fetch`, `list` | |
| `client.diagnostics` | `/health`, OpenAPI spec | |

Every method that takes a request body accepts a typed Swift struct from the `VoiceML` module:

```swift
import VoiceML

let client = try VoiceMLClient(accountSid: "AC…", apiKey: "…")

let call = try await client.calls.create(.init(
    to: "+18005551234",
    from: "+18005550000",
    url: "https://example.com/twiml"
))

// On a live call, open a Pay session.
let session = try await client.calls.startPayment(callSid: call.sid, .init(
    idempotencyKey: "order-482917",
    statusCallback: "https://example.com/pay-status"
))
print(session.sid, session.status)
```

## 🚨 Error Handling

All non-2xx responses throw a subclass of `ApiError` (itself a `VoiceMLError`). Catch broadly or narrowly using Swift's typed `catch`:

| Status | Error type |
|--------|------------|
| 400 | `BadRequestError` |
| 401 | `AuthenticationError` |
| 403 | `PermissionDeniedError` |
| 404 | `NotFoundError` |
| 409 | `ConflictError` |
| 410 | `GoneError` |
| 429 | `RateLimitError` |
| 501 | `NotImplementedAPIError` |
| 5xx | `ServerError` |
| other | `ApiError` |

```swift
do {
    let call = try await client.calls.get("CA0000000000000000000000000000aaaa")
    print(call.status)
} catch let err as NotFoundError {
    print("That call isn't on your account.")
} catch let err as RateLimitError {
    print("Slow down — server said: \(err.message)")
} catch let err as ApiError {
    print("HTTP \(err.statusCode) — \(err.code ?? "unknown"): \(err.message)")
}
```

The Twilio-compatible error body (`code`, `message`, `more_info`, `status`) is parsed into `error.code` / `error.message` / `error.moreInfo` with the raw payload available on `error.body`.

## ⚡ Async Support

The SDK is `async/await` first — there is no separate "async client" to swap in. Every method is `async throws`, and `VoiceMLClient` is `Sendable`, so the same instance can be safely shared across actors:

```swift
actor CallCenter {
    let voiceml: VoiceMLClient

    init() throws {
        self.voiceml = try VoiceMLClient(accountSid: "AC…", apiKey: "…")
    }

    func placeCall(to number: String) async throws -> Call {
        try await voiceml.calls.create(.init(
            to: number,
            from: "+18005550000",
            url: "https://example.com/twiml"
        ))
    }
}
```

Cancellation propagates: cancelling the parent `Task` aborts the in-flight HTTP request.

## 📄 Pagination

List operations return a `…List` struct with a Twilio-compatible pagination envelope (`page`, `pageSize`, `nextPageUri`, `previousPageUri`, …). For collections that support page-walking, use the `iterate(…)` helper — it returns an `AsyncThrowingStream` that walks every page transparently:

```swift
let params = ListCallsParams(status: .completed, pageSize: 200)
for try await call in client.calls.iterate(params) {
    process(call)
}

for try await message in client.messages.iterate(.init(fromNumber: "+18005550000", pageSize: 200)) {
    archive(message)
}
```

For other resources, page manually by setting `page:` on the params struct and calling `list(…)`.

## 🔁 Migration from twilio-swift

Twilio does not ship an official Swift SDK — Swift projects typically call Twilio's REST API directly via `URLSession` or use a community wrapper. Either way, the `AccountSid` + API-key pair you already have works unchanged here; only the base URL changes:

```swift
// Before — calling Twilio's REST API directly from Swift.
var request = URLRequest(url: URL(string:
    "https://api.twilio.com/2010-04-01/Accounts/AC…/Calls.json"
)!)
request.httpMethod = "POST"
// …add Basic auth header, form-encode body, parse JSON response…

// After — VoiceML, Twilio-compatible wire format.
let client = try VoiceMLClient(accountSid: "AC…", apiKey: "…")
let call = try await client.calls.create(.init(
    to: "+18005551234",
    from: "+18005550000",
    url: "https://example.com/twiml"
))
```

Resource method names follow the map above (`client.calls.create(...)`, `client.queues.list()`, …); request and response shapes are Twilio-compatible (`AccountSid`, `From`, `To`, status callbacks, `next_page_uri`) with idiomatic Swift names on the surface.

## ⏱️ Rate Limits

VoiceML applies per-tenant rate limits at the edge. The SDK automatically retries 429 responses with `Retry-After` honored, up to `maxRetries` (default `2`). To bump it:

```swift
let client = try VoiceMLClient(
    accountSid: "AC…",
    apiKey: "…",
    timeout: 60,
    maxRetries: 4
)
```

## 🛠️ Development

```bash
git clone https://github.com/voicetel/voiceml-swift
cd voiceml-swift

# Build (warnings-as-errors, matches CI).
swift build -Xswiftc -warnings-as-errors

# Unit tests (fast, no network — URLProtocol mocks).
swift test

# Release build.
swift build -c release
```

CI runs against the `swift:6.0.3` container on Linux; the package also builds against the Apple toolchain on macOS 12+.

## 📖 API Documentation

- **Reference docs:** [voicetel.com/docs/api/v0.7/voiceml/](https://voicetel.com/docs/api/v0.7/voiceml/)
- **Validator:** [voicetel.com/voiceml/validator/](https://voicetel.com/voiceml/validator/)
- **SDK catalogue:** [voicetel.com/docs/voiceml-sdks/](https://voicetel.com/docs/voiceml-sdks/)
- **Type definitions:** every wire shape has a `Codable` struct under `Sources/VoiceML/Models/`.

## 🙌 Contributors

- [Michael Mavroudis](https://github.com/mavroudis) — Lead Developer

Contributions welcome. Open an issue describing the change you want to make, or send a pull request against `main`.

## 💖 Sponsors

| Sponsor | Contribution |
|---------|--------------|
| [VoiceTel Communications](https://voicetel.com) | Primary development and production hosting |

## 📄 License

MIT — see [LICENSE](LICENSE).
