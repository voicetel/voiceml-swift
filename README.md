# VoiceML Swift SDK

Official Swift SDK for the [VoiceML](https://voicetel.com/docs/api/v0.6/voiceml/) REST API — VoiceTel's
outbound voice + AMD service. The wire surface is Twilio-shaped (`AccountSid` + API key
Basic auth, form-urlencoded bodies, `/2010-04-01/Accounts/{Sid}/…` paths), so existing
Twilio integration patterns translate directly.

## Requirements

- Swift 5.9+
- Apple platforms: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+
- Linux: any distro with the Swift toolchain (Foundation only — no Apple-specific deps)

## Install

Swift Package Manager — add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/voicetel/voiceml-swift", from: "0.5.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["VoiceML"]),
]
```

## Usage

```swift
import VoiceML

let client = try VoiceMLClient(
    accountSid: "AC" + String(repeating: "0", count: 32),
    apiKey: "your-api-key"
)

// Place a call.
let call = try await client.calls.create(.init(
    to: "+18005551234",
    from: "+18005550000",
    url: "https://example.com/twiml"
))

// List recent calls.
let page = try await client.calls.list(.init(
    status: .completed,
    startTimeGte: "2026-01-01",
    pageSize: 50
))

// Stream audio over WebSocket.
try await client.calls.startStream(callSid: call.sid, body: .init(
    url: "wss://example.com/ws",
    track: .bothTracks
))

// Hang up.
_ = try await client.calls.update(callSid: call.sid, body: .init(status: .completed))
```

## Errors

Catch the base `VoiceMLError` or one of the status-specific subclasses:

```swift
do {
    _ = try await client.calls.get("CA…")
} catch let err as NotFoundError {
    // 404: wrong tenant or sid doesn't exist.
} catch let err as AuthenticationError {
    // 401: bad accountSid/apiKey, or source IP not allowed.
} catch let err as ApiError {
    // anything else non-2xx — inspect err.statusCode / err.code / err.body
}
```

## 📖 API Documentation

- **Reference docs:** [voicetel.com/docs/api/v0.6/voiceml/](https://voicetel.com/docs/api/v0.6/voiceml/)
- **Validator:** [voicetel.com/voiceml/validator/](https://voicetel.com/voiceml/validator/)
- **SDK catalogue:** [voicetel.com/docs/voiceml-sdks/](https://voicetel.com/docs/voiceml-sdks/)

## License

MIT — see `LICENSE`.
