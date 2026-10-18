import Foundation

/// Webhook signature validation.
///
/// VoiceML signs every webhook it delivers with `X-Twilio-Signature`. The signature is
/// `Base64(HMAC-SHA1(apiKey, url + sortedFormPairs))`:
///
/// - Take the URL with any `#fragment` stripped.
/// - For POST, append each pair `key + value` for every form key sorted ascending
///   (byte order); repeated keys keep their received value order. For GET, use the
///   URL only.
/// - HMAC-SHA1 with the **account API key** as the key, then standard padded Base64.
///
/// Validators compare in constant time and also accept the URL with the default port
/// added or removed (`:443` for https, `:80` for http), because proxies frequently
/// rewrite one form into the other.
public enum RequestValidator {

    /// Compute the signature for a URL and form parameters, in the order the server
    /// would sign them.
    public static func signature(
        apiKey: String,
        url: String,
        params: [(String, String)] = []
    ) -> String {
        var payload = stripFragment(url)
        if !params.isEmpty {
            // Sort by key in byte order; repeated keys keep their received value
            // order (stable sort via index tie-break).
            let order = params.indices.sorted { i, j in
                let li = params[i].0.utf8
                let lj = params[j].0.utf8
                if li.elementsEqual(lj) { return i < j }
                return li.lexicographicallyPrecedes(lj)
            }
            for idx in order {
                payload += params[idx].0
                payload += params[idx].1
            }
        }
        let mac = hmacSHA1(key: Array(apiKey.utf8), message: Array(payload.utf8))
        return Data(mac).base64EncodedString()
    }

    /// Validate an `X-Twilio-Signature` header value against a URL and the form
    /// parameters the webhook carried. For GET webhooks pass an empty `params` list
    /// (the URL alone is signed).
    public static func validate(
        apiKey: String,
        url: String,
        params: [(String, String)] = [],
        signature: String
    ) -> Bool {
        let candidates = signatureCandidates(apiKey: apiKey, url: url, params: params)
        for candidate in candidates where constantTimeEquals(candidate, signature) {
            return true
        }
        return false
    }

    /// Convenience overload for dictionary-shaped parameters (no repeated keys).
    public static func validate(
        apiKey: String,
        url: String,
        params: [String: String],
        signature: String
    ) -> Bool {
        validate(apiKey: apiKey, url: url, params: params.sorted { $0.key < $1.key }, signature: signature)
    }

    static func signatureCandidates(
        apiKey: String,
        url: String,
        params: [(String, String)]
    ) -> [String] {
        var urls = [stripFragment(url)]
        if let portVariant = defaultPortVariant(of: stripFragment(url)) {
            urls.append(portVariant)
        }
        return urls.map { signature(apiKey: apiKey, url: $0, params: params) }
    }

    static func stripFragment(_ url: String) -> String {
        if let idx = url.firstIndex(of: "#") {
            return String(url[..<(idx)])
        }
        return url
    }

    /// Return the same URL with the default port explicitly added, or with an explicit
    /// default port removed — whichever differs from the input.
    static func defaultPortVariant(of url: String) -> String? {
        guard var comps = URLComponents(string: url), let scheme = comps.scheme?.lowercased() else {
            return nil
        }
        let defaults: [String: Int] = ["https": 443, "http": 80]
        guard let def = defaults[scheme] else { return nil }
        if comps.port == nil {
            comps.port = def
            return comps.url?.absoluteString
        }
        if comps.port == def {
            comps.port = nil
            return comps.url?.absoluteString
        }
        return nil
    }

    /// Constant-time equality over the Base64 signature strings.
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var diff: UInt8 = a.count == b.count ? 0 : 1
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            diff |= x ^ y
        }
        return diff == 0
    }

    // MARK: - HMAC-SHA1

    static func hmacSHA1(key: [UInt8], message: [UInt8]) -> [UInt8] {
        var k = key
        if k.count > 64 {
            k = sha1(k)
        }
        while k.count < 64 {
            k.append(0)
        }
        var outer = [UInt8]()
        var inner = [UInt8]()
        for byte in k {
            outer.append(byte ^ 0x5c)
            inner.append(byte ^ 0x36)
        }
        inner.append(contentsOf: message)
        let innerHash = sha1(inner)
        outer.append(contentsOf: innerHash)
        return sha1(outer)
    }

    static func sha1(_ input: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

        var message = input
        let originalBitLength = UInt64(input.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 {
            message.append(0)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8((originalBitLength >> UInt64(shift)) & 0xFF))
        }

        var block = [UInt32](repeating: 0, count: 16)
        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            for i in 0..<16 {
                let base = chunkStart + i * 4
                block[i] = (UInt32(message[base]) << 24)
                    | (UInt32(message[base + 1]) << 16)
                    | (UInt32(message[base + 2]) << 8)
                    | UInt32(message[base + 3])
            }
            var w = block
            for i in 16..<80 {
                let x = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
                w.append(rotl(x, 1))
            }

            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4]
            for i in 0..<80 {
                let f: UInt32
                let k: UInt32
                switch i {
                case 0..<20:
                    f = (b & c) | ((~b) & d)
                    k = 0x5A827999
                case 20..<40:
                    f = b ^ c ^ d
                    k = 0x6ED9EBA1
                case 40..<60:
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8F1BBCDC
                default:
                    f = b ^ c ^ d
                    k = 0xCA62C1D6
                }
                let temp = rotl(a, 5) &+ f &+ e &+ k &+ w[i]
                e = d
                d = c
                c = rotl(b, 30)
                b = a
                a = temp
            }
            h[0] = h[0] &+ a
            h[1] = h[1] &+ b
            h[2] = h[2] &+ c
            h[3] = h[3] &+ d
            h[4] = h[4] &+ e
        }

        var out = [UInt8]()
        for word in h {
            out.append(UInt8((word >> 24) & 0xFF))
            out.append(UInt8((word >> 16) & 0xFF))
            out.append(UInt8((word >> 8) & 0xFF))
            out.append(UInt8(word & 0xFF))
        }
        return out
    }

    static func rotl(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x << n) | (x >> (32 - n))
    }
}
