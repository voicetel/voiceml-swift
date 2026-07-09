import Foundation

// Per-product host resolution for the VoiceML API.
//
// Twilio splits its products across dedicated subdomains (api.twilio.com,
// conversations.twilio.com, messaging.twilio.com, …). VoiceML mirrors that
// shape on voicetel.com: the Conversations product answers on
// conversations.voicetel.com and the Messaging Service product on
// messaging.voicetel.com, while everything else stays on the default
// voiceml.voicetel.com host. A Conversation Service and a Messaging Service
// share the identical /v1/Services path shape, so the host is what
// disambiguates them on the wire.
//
// Given the configured base URL these helpers derive the two product hosts by
// swapping the leftmost `voiceml` label — but only for recognised
// *.voicetel.com hosts. For any other base URL (a self-hosted callBroadcast
// instance, a test stub) the product hosts fall back to the configured host
// unchanged, so a single-host deployment keeps working. A caller who needs
// Messaging Service against a custom host points `messagingBaseURL` (or
// `conversationsBaseURL`) at their own subdomain explicitly.

/// Swap the `voiceml` label of a `*.voicetel.com` host for `product`. Returns
/// `baseURL` unchanged when the host is not a `voiceml.*.voicetel.com` style
/// host, so single-host deployments keep working without special-casing.
func deriveProductHost(_ baseURL: URL, _ product: String) -> URL {
    guard let host = baseURL.host, host.hasSuffix(".voicetel.com") else { return baseURL }
    var labels = host.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard let idx = labels.firstIndex(of: "voiceml") else { return baseURL }
    labels[idx] = product
    guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return baseURL }
    comps.host = labels.joined(separator: ".")
    return comps.url ?? baseURL
}

/// Drop trailing slashes from a URL's string form (mirrors Python's `rstrip("/")`).
func stripTrailingSlash(_ url: URL) -> URL {
    var s = url.absoluteString
    while s.hasSuffix("/") { s.removeLast() }
    return URL(string: s) ?? url
}

/// Return `(default, messaging, conversations)` base URLs. Explicit overrides
/// win; otherwise each product host is derived from `baseURL`. All three are
/// returned without a trailing slash.
func resolveProductBaseURLs(
    baseURL: URL,
    messagingBaseURL: URL? = nil,
    conversationsBaseURL: URL? = nil
) -> (defaultURL: URL, messaging: URL, conversations: URL) {
    let def = stripTrailingSlash(baseURL)
    let messaging = stripTrailingSlash(messagingBaseURL ?? deriveProductHost(def, "messaging"))
    let conversations = stripTrailingSlash(conversationsBaseURL ?? deriveProductHost(def, "conversations"))
    return (def, messaging, conversations)
}
