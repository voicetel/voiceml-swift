import Foundation

/// Twilio-compatible Account resource — `/Accounts/{sid}.json`.
///
/// The Account payload differs in shape from per-resource records: there's
/// no `account_sid`/`api_version`, and the owning identifier is
/// `owner_account_sid`. `sid` carries the AC… account SID itself. The
/// server additively embeds VoiceML extension keys, which this model
/// ignores on decode.
public struct Account: Codable, Sendable {
    public var sid: String?
    public var ownerAccountSid: String?
    public var friendlyName: String?
    public var status: String?
    /// `Trial`, `Full`, etc. Optional for forward compatibility.
    public var type: String?
    public var authToken: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var uri: String?
    public var subresourceUris: [String: String]?
}

/// `POST /Accounts/{AccountSid}/RotateKey.json` response — the account
/// configuration view plus the freshly generated `apiKey`. No read endpoint
/// returns the key, so store it right away; requests signed with the previous
/// key fail with 401 from that point on. The key is secret material:
/// `Mirror`, `dump()` and `debugDescription` never expose it.
public struct AccountWithKey: Codable, Sendable, CustomReflectable, CustomDebugStringConvertible {
    public var sid: String?
    public var apiKey: String?
    public var sipUsername: String?
    public var name: String?
    public var phoneRegions: [String]?
    public var allowCidr: [String]?
    public var disabled: Bool?
    public var sttFsVendor: String?
    public var sttHttpUrl: String?
    public var sttHttpTokenSet: Bool?
    public var ttsHttpUrl: String?
    public var ttsHttpTokenSet: Bool?
    public var ttsEngineName: String?
    public var ttsDefaultVoice: String?
    public var ttsDefaultLanguage: String?
    public var stripeSecretKeySet: Bool?
    public var payEnabled: Bool?
    public var smsProvider: String?
    public var smsAllowedProviders: [String]?
    public var sttAllowedProviders: [String]?
    public var sttProvider: String?
    public var voiceUrl: String?
    public var voiceMethod: String?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: String?
    public var awsBucket: String?
    public var awsRegion: String?
    public var awsPrefix: String?
    public var awsAccessKeyId: String?
    public var awsSecretAccessKeySet: Bool?
    public var awsKmsKeyId: String?
    public var createdAt: String?
    public var updatedAt: String?

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "sid": sid as Any,
                "apiKey": "<redacted>",
                "sipUsername": sipUsername as Any,
                "name": name as Any,
                "phoneRegions": phoneRegions as Any,
                "allowCidr": allowCidr as Any,
                "disabled": disabled as Any,
                "sttFsVendor": sttFsVendor as Any,
                "sttHttpUrl": sttHttpUrl as Any,
                "sttHttpTokenSet": sttHttpTokenSet as Any,
                "ttsHttpUrl": ttsHttpUrl as Any,
                "ttsHttpTokenSet": ttsHttpTokenSet as Any,
                "ttsEngineName": ttsEngineName as Any,
                "ttsDefaultVoice": ttsDefaultVoice as Any,
                "ttsDefaultLanguage": ttsDefaultLanguage as Any,
                "stripeSecretKeySet": stripeSecretKeySet as Any,
                "payEnabled": payEnabled as Any,
                "smsProvider": smsProvider as Any,
                "smsAllowedProviders": smsAllowedProviders as Any,
                "sttAllowedProviders": sttAllowedProviders as Any,
                "sttProvider": sttProvider as Any,
                "voiceUrl": voiceUrl as Any,
                "voiceMethod": voiceMethod as Any,
                "voiceFallbackUrl": voiceFallbackUrl as Any,
                "voiceFallbackMethod": voiceFallbackMethod as Any,
                "awsBucket": awsBucket as Any,
                "awsRegion": awsRegion as Any,
                "awsPrefix": awsPrefix as Any,
                "awsAccessKeyId": awsAccessKeyId as Any,
                "awsSecretAccessKeySet": awsSecretAccessKeySet as Any,
                "awsKmsKeyId": awsKmsKeyId as Any,
                "createdAt": createdAt as Any,
                "updatedAt": updatedAt as Any,
            ],
            displayStyle: .struct
        )
    }

    public var debugDescription: String {
        "AccountWithKey(sid: \(sid ?? "nil"), apiKey: <redacted>)"
    }
}
