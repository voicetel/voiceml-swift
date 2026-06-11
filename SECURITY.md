# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 0.7.x   | ✅        |
| < 0.7   | ❌        |

## Reporting a Vulnerability

Please **do not** open a public issue for security vulnerabilities.

Use GitHub's private vulnerability reporting for this repository:
**Security → Report a vulnerability** (or
<https://github.com/voicetel/voiceml-swift/security/advisories/new>).

Include, where possible:

- A description of the issue and its impact
- Steps to reproduce or a proof of concept
- Affected version(s) and configuration

You can expect an acknowledgement within a few business days. Please
allow reasonable time for a fix before any public disclosure.

## Scope Notes

This SDK constructs authenticated HTTP requests to the VoiceML REST
API. Hardening expectations on the consumer side:

- Do not log `ClientOptions.apiKey` / `authToken` or the
  `Authorization` header — both carry the per-tenant secret in HTTP
  Basic form.
- Keep `accountSid` + secret out of source control; load from
  Keychain, a secret manager, or environment.
- The SDK uses `URLSession` with the platform default TLS posture
  (TLS 1.2+ via Network.framework / Secure Transport). If you supply
  a custom `URLSession`, you are responsible for matching that
  posture.
- Retries on 429 / 5xx replay the same request body. Do not pass
  non-idempotent payloads through clients with retries enabled
  unless the server enforces an idempotency key.

Out of scope: vulnerabilities in the published `VoiceML` Swift
package caused by a forked / vendored copy that has been modified.
