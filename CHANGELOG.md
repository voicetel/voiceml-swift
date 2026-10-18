# Changelog

## [0.9.3] - 2026-10-18

### Breaking changes
- **Removed methods** for endpoints the API no longer serves
  (405 / error 20004): `calls.listStreams`, `calls.getStream`,
  `calls.listSiprec`, `calls.getSiprec`, `calls.listTranscriptions`,
  `calls.getTranscription`, and the `StreamList` / `SiprecList` /
  `TranscriptionList` models. The `start*` / `stop*` POST methods
  remain.
- **Pagination**: `iterate()` now follows `next_page_uri` (with its
  `PageToken`) verbatim and fetches lazily, instead of synthesising
  `Page=N`. Page-counting loops never terminated against the current
  API for Calls and Conferences, and Messages/Recordings rejected
  `Page>0` without a token. `total` / `numPages` were removed from list
  envelopes; `start`, `end`, `firstPageUri` and `previousPageUri` were
  added. The producer stops as soon as the consumer breaks out.
- **Retry policy**: non-idempotent requests (`POST`) are no longer
  retried on 5xx responses or timeouts, which could place duplicate
  calls or messages. They are retried only on 429 and on
  connection-establishment failures where the request was provably not
  sent.
- `messages.create`'s `body` is optional when `mediaUrl` is present.

### Added
- 36 operations previously missing: Accounts fetch/update, Balance,
  OutgoingCallerIds, Message Media, Exports, account and recording
  Transcriptions, conference recording create, Usage Records (list plus
  the eight window subresources), SIP Registrations, Messaging Service
  sender phone numbers, and `openapiYaml()` / `openapiYml()`
  diagnostics.
- Monitor v1 Alerts: `client.monitorAlerts.list(_:)` (severity and
  date-window filters) and `fetch(sid:)`, with `iterate(_:)` /
  `nextPage(of:)` over the `/v1` `meta` envelope.
- `messages.createFeedback(sid:_:)` — delivery-quality feedback for a
  Message.
- `accounts.rotateKey()` — rotates the account's API key; the new key is
  returned on `AccountWithKey.apiKey` and excluded from `Mirror`,
  `dump()` and `debugDescription` output.
- `RequestValidator` for verifying `X-Twilio-Signature` webhook
  signatures (constant-time compare, default-port normalisation).
- MMS support (`mediaUrl` repeated keys), `ValidityPeriod`,
  `StatusCallbackMethod` on `messages.create`.
- `smsUrl` / `smsMethod` / `smsFallbackUrl` / `smsFallbackMethod` /
  `smsApplicationSid` on IncomingPhoneNumbers; list filters
  `friendlyName` / `beta` / `origin`; `messageStatusCallback` /
  `smsStatusCallback` on Applications; `recordingTrack` /
  `pauseBehavior` on recordings; `friendlyName` on SIP lists.
- `nextPage(of:)` helper; `/v1` lists follow `meta.next_page_url` on
  the configured product host only.
- Typed `Notification` and `CallEvent` models; new response fields
  (`track`, `advancedOptOut`, IncomingPhoneNumber `sms_*` /
  `subresourceUris` / `status` / `origin` / `emergency*`).

### Fixed
- **Recording audio no longer sends credentials to storage hosts**: the
  download follows the redirect itself, stripping `Authorization`
  whenever the host or scheme changes and refusing https-to-http
  downgrades.
- `notifications.list` / `calls.listEvents` decode the current
  envelope (the old models required a `total` the API no longer sends).
- `diagnostics.health()` decodes a healthy body (`warnings` optional),
  honours the configured session and timeout, works without
  credentials, and raises `ServerError` on 503.
- Task cancellation propagates to the HTTP layer on Linux and is never
  retried or wrapped.
- `Retry-After` is honoured as delta-seconds or an HTTP-date, capped at
  60 seconds; beyond the cap the rate-limit error is raised immediately.
- Every caller-supplied path segment is percent-encoded; `?` can no
  longer inject a query or `../` traverse paths.
- Spec-nullable fields are optional and unknown enum values decode to
  an `unknown` case instead of throwing.
- The API key never appears in `dump()` / Mirror output.

### Security
- Retry defaults no longer replay non-idempotent requests after
  timeouts or 5xx responses (duplicate call/SMS prevention).

### Docs
- README rewritten against the current API (correct counts, working
  `from: "0.9.2"` install line, honest cancellation and Retry-After
  wording); fictional `555-0100`-range example numbers throughout;
  SECURITY.md supported-versions table updated to 0.9.x.
