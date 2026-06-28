import Foundation

/// REST companion to the `<Pay>` TwiML verb. Response shape mirrors the
/// Twilio-compatible payload — runtime config (chargeAmount, paymentConnector,
/// validCardTypes, etc.) is captured server-side and not echoed back.
///
/// Tenant-side BYO is binding: the account must have `pay_enabled = true` AND a
/// `stripe_secret_key` set, or the call fails 403.
public struct CallPayment: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var callSid: String
    // Twilio's CreatePayments/UpdatePayments fixtures omit api_version
    // (only the list-envelope items carry it). Optional to match — same
    // fix-forward the TS SDK shipped at voiceml-node-sdk@a11b0a1 for the
    // Stream/Siprec/CallTranscription Create responses.
    public var apiVersion: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

/// Narrows the `BankAccountType` field on a Pay session.
public enum PaymentBankAccountType: String, Codable, Sendable {
    case consumerChecking = "consumer-checking"
    case consumerSavings = "consumer-savings"
    case commercialChecking = "commercial-checking"
}

/// Narrows the `Input` field. DTMF is the only supported value today.
public enum PaymentInput: String, Codable, Sendable {
    case dtmf
}

/// Narrows the `PaymentMethod` field.
public enum PaymentMethod: String, Codable, Sendable {
    case creditCard = "credit-card"
    case achDebit = "ach-debit"
}

/// Narrows the `TokenType` field.
public enum PaymentTokenType: String, Codable, Sendable {
    case oneTime = "one-time"
    case reusable
    case paymentMethod = "payment-method"
}

/// Narrows the `Capture` field on Pay-session updates — tells the runtime which input
/// the user is about to type next.
public enum PaymentCapture: String, Codable, Sendable {
    case paymentCardNumber = "payment-card-number"
    case expirationDate = "expiration-date"
    case securityCode = "security-code"
    case postalCode = "postal-code"
    case bankRoutingNumber = "bank-routing-number"
    case bankAccountNumber = "bank-account-number"
    case paymentCardNumberMatcher = "payment-card-number-matcher"
    case expirationDateMatcher = "expiration-date-matcher"
    case securityCodeMatcher = "security-code-matcher"
    case postalCodeMatcher = "postal-code-matcher"
}

/// Narrows the `Status` field on Pay-session updates.
public enum PaymentSessionStatus: String, Codable, Sendable {
    case complete
    case cancel
}

/// Body for `POST /Calls/{callSid}/Payments`. Every attribute the `<Pay>` TwiML verb
/// accepts has a counterpart here. `idempotencyKey` is accepted and persisted for
/// diagnostic visibility but replay-dedup is NOT enforced today.
public struct StartPaymentRequest: Sendable {
    public var idempotencyKey: String?
    public var statusCallback: String?
    public var bankAccountType: PaymentBankAccountType?
    /// Decimal under 1,000,000.
    public var chargeAmount: String?
    public var currency: String?
    public var description: String?
    public var input: PaymentInput?
    public var minPostalCodeLength: Int?
    /// Single-level JSON object passed to the payment connector.
    public var parameter: String?
    public var paymentConnector: String?
    public var paymentMethod: PaymentMethod?
    public var postalCode: Bool?
    public var securityCode: Bool?
    public var timeout: Int?
    public var tokenType: PaymentTokenType?
    /// Space-separated. Default: `visa mastercard amex maestro discover optima jcb diners-club enroute`.
    public var validCardTypes: String?
    /// Comma-separated fields requiring matcher inputs.
    public var requireMatchingInputs: String?
    public var confirmation: Bool?

    public init(
        idempotencyKey: String? = nil,
        statusCallback: String? = nil,
        bankAccountType: PaymentBankAccountType? = nil,
        chargeAmount: String? = nil,
        currency: String? = nil,
        description: String? = nil,
        input: PaymentInput? = nil,
        minPostalCodeLength: Int? = nil,
        parameter: String? = nil,
        paymentConnector: String? = nil,
        paymentMethod: PaymentMethod? = nil,
        postalCode: Bool? = nil,
        securityCode: Bool? = nil,
        timeout: Int? = nil,
        tokenType: PaymentTokenType? = nil,
        validCardTypes: String? = nil,
        requireMatchingInputs: String? = nil,
        confirmation: Bool? = nil
    ) {
        self.idempotencyKey = idempotencyKey
        self.statusCallback = statusCallback
        self.bankAccountType = bankAccountType
        self.chargeAmount = chargeAmount
        self.currency = currency
        self.description = description
        self.input = input
        self.minPostalCodeLength = minPostalCodeLength
        self.parameter = parameter
        self.paymentConnector = paymentConnector
        self.paymentMethod = paymentMethod
        self.postalCode = postalCode
        self.securityCode = securityCode
        self.timeout = timeout
        self.tokenType = tokenType
        self.validCardTypes = validCardTypes
        self.requireMatchingInputs = requireMatchingInputs
        self.confirmation = confirmation
    }

    func formFields() -> [FormField] {
        [
            FormField("IdempotencyKey", idempotencyKey),
            FormField("StatusCallback", statusCallback),
            FormField("BankAccountType", bankAccountType?.rawValue),
            FormField("ChargeAmount", chargeAmount),
            FormField("Currency", currency),
            FormField("Description", description),
            FormField("Input", input?.rawValue),
            FormField("MinPostalCodeLength", minPostalCodeLength),
            FormField("Parameter", parameter),
            FormField("PaymentConnector", paymentConnector),
            FormField("PaymentMethod", paymentMethod?.rawValue),
            FormField("PostalCode", postalCode),
            FormField("SecurityCode", securityCode),
            FormField("Timeout", timeout),
            FormField("TokenType", tokenType?.rawValue),
            FormField("ValidCardTypes", validCardTypes),
            FormField("RequireMatchingInputs", requireMatchingInputs),
            FormField("Confirmation", confirmation),
        ]
    }
}

/// Body for `POST /Calls/{callSid}/Payments/{paymentSid}`. Either advance the session
/// (`capture=…`) or terminate it (`status=.complete` or `status=.cancel`).
public struct UpdatePaymentRequest: Sendable {
    public var idempotencyKey: String?
    public var statusCallback: String?
    public var capture: PaymentCapture?
    public var status: PaymentSessionStatus?

    public init(
        idempotencyKey: String? = nil,
        statusCallback: String? = nil,
        capture: PaymentCapture? = nil,
        status: PaymentSessionStatus? = nil
    ) {
        self.idempotencyKey = idempotencyKey
        self.statusCallback = statusCallback
        self.capture = capture
        self.status = status
    }

    func formFields() -> [FormField] {
        [
            FormField("IdempotencyKey", idempotencyKey),
            FormField("StatusCallback", statusCallback),
            FormField("Capture", capture?.rawValue),
            FormField("Status", status?.rawValue),
        ]
    }
}
