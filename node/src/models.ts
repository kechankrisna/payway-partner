/** Partner credentials provided by ABA Bank. */
export interface PaywayPartner {
  /** your partner name registered with ABA */
  partnerName: string;
  /** encrypted partner id provided by ABA */
  partnerId: string;
  /** HMAC key used to sign every request (secret) */
  partnerKey: string;
  /** PEM private key, decrypts PayWay data (secret) */
  partnerPrivateKey: string;
  /** PEM public key, encrypts `request_data` */
  partnerPublicKey: string;
  /** domain whitelisted by ABA, sent as the `Referer` header */
  partnerReferer: string;
  /** {@link PAYWAY_SANDBOX_URL} or {@link PAYWAY_PRODUCTION_URL} */
  baseApiUrl: string;
}

/** PayWay sandbox (testing) environment */
export const PAYWAY_SANDBOX_URL = 'https://sandbox.payway.com.kh';

/** PayWay production (live) environment */
export const PAYWAY_PRODUCTION_URL = 'https://merchant.payway.com.kh';

/** Request of `new-merchant` (register a merchant). */
export interface RegisterMerchantRequest {
  /** PayWay POSTs the merchant details here once registration completes */
  pushbackUrl: string;
  /**
   * embedded in the button on PayWay's success screen. Native app (`type` 1):
   * `{"ios_scheme":"...","android_scheme":"..."}`; web (`type` 0): a URL
   */
  redirectUrl: string;
  /** your unique reference for this registration (letters, numbers, `_`, `-`) */
  registerRef: string;
  /** merchant currency to register */
  currency: 'USD' | 'KHR';
  /** activation platform: `0` web (default), `1` native app */
  type?: 0 | 1;
  /** `0` in-store merchant, `1` online merchant (ABA default when omitted) */
  merchantType?: 0 | 1;
}

/** Request of `get-mc-credential-info` (inquiry merchant info via register ref). */
export interface CheckMerchantRequest {
  /** the `registerRef` used when registering the merchant */
  registerRef: string;
}

/**
 * Request of `get-mc-info` (inquiry merchant info via merchant public key).
 * The keys are never sent as is: they key the hashes PayWay verifies.
 */
export interface GetMcInfoRequest {
  /** merchant key provided by ABA */
  merchantKey: string;
  /** `USD` or `KHR` */
  currency: string;
  /** merchant public key, keys `public_key_hash_encrypt` (HMAC-SHA512) */
  publicKey: string;
  /** merchant RSA public key, encrypts `rsa_public_key_hash_encrypt` */
  rsaPublicKey?: string;
}

/** The `status` object of every PayWay partner response. */
export interface PaywayStatus {
  /** status code, `00` on success; see {@link PaywayPartnerStatusCode} */
  code: string;
  /** human readable status message from PayWay */
  message: string;
  /** transaction id (register and inquiry via register ref) */
  tranId?: string;
  /** PayWay log id for debugging (inquiry via public key) */
  traceId?: string;
  /** PayWay correlation id for debugging */
  correlationId?: string;
}

/** Response of `new-merchant`. */
export interface RegisterMerchantResponse {
  /** onboarding form: redirect the merchant here to complete registration */
  url: string;
  /** unique token of this registration session */
  token: string;
  /** PayWay's `status` object */
  status: PaywayStatus;
  /** whether PayWay answered `00` (success) */
  isSuccess: boolean;
}

/** Response of both merchant inquiries. `data` is encrypted. */
export interface InquiryResponse {
  /** encrypted merchant details, empty unless `isSuccess` */
  data: string;
  /** PayWay's `status` object */
  status: PaywayStatus;
  /** whether PayWay answered `00` (success) */
  isSuccess: boolean;
}

/**
 * Decrypted merchant details, sent to your `pushback_url` and returned by
 * the inquiry via register ref. Store these securely.
 */
export interface MerchantCredential {
  /** your official partner name registered in PayWay */
  partnerName: string;
  /** outlet name */
  merchantName: string;
  /** MID representing the outlet */
  mid: string;
  /** `merchant_id` used for purchase, refund and other merchant APIs */
  merchantKey: string;
  /** merchant public key (secret) */
  publicKey: string;
  /** your register reference id */
  registerRef: string;
  /** merchant currency code: `USD`, `KHR` or both */
  currency: string;
  /** merchant RSA public key */
  rsaPublicKey: string;
}

/** Decrypted merchant info returned by the inquiry via public key. */
export interface MerchantInfo {
  /** outlet (merchant) name */
  outletName: string;
  /** ABA account receiving KHR payments, empty when none */
  abaAccountKhr: string;
  /** ABA account receiving USD payments, empty when none */
  abaAccountUsd: string;
  /** payment methods the merchant can apply for, `code: label` */
  availablePaymentMethods: Record<string, string>;
  /** payment methods the merchant can accept now, `code: label` */
  enabledPaymentMethods: Record<string, string>;
  /** payment methods awaiting approval, `code: label` */
  pendingPaymentMethods: Record<string, string>;
}

/** Status codes documented for the PayWay partner API. */
export const PaywayPartnerStatusCode = {
  /** `00` Success! */
  success: '00',
  /** `PTL02` Wrong Hash */
  wrongHash: 'PTL02',
  /** `PTL04` Parameter Validation Required */
  parameterValidationRequired: 'PTL04',
  /** `PTL06` The Request is Expired */
  requestExpired: 'PTL06',
  /** `PTL46` Merchant not found */
  merchantNotFound: 'PTL46',
  /** `PTL137` Partner id not found */
  partnerIdNotFound: 'PTL137',
  /** `PTL141` The redirect url can not empty */
  redirectUrlEmpty: 'PTL141',
  /** `PTL142` The pushback url can not empty */
  pushbackUrlEmpty: 'PTL142',
  /** `PTL164` The register ref is already exist */
  registerRefAlreadyExists: 'PTL164',
  /** `PTL165` The register ref can not empty */
  registerRefEmpty: 'PTL165',
  /** `PTL166` The register ref is invalid format */
  registerRefInvalidFormat: 'PTL166',
  /** `PTL170` Your profile is deactivated */
  profileDeactivated: 'PTL170',
  /** `PTL171` Invalid request data: check the key and encryption method */
  invalidRequestData: 'PTL171',
  /** `PTL175` Requested Domain is not in whitelist */
  domainNotWhitelisted: 'PTL175',
} as const;

// ---- JSON mapping (PayWay uses snake_case) --------------------------------

type Json = Record<string, unknown>;

/**
 * Values documented as strings are read as strings, so a number (e.g. an
 * account or mid) does not break parsing; objects and arrays count as absent.
 */
const optionalStr = (value: unknown): string | undefined => {
  switch (typeof value) {
    case 'string':
      return value;
    case 'number':
    case 'boolean':
    case 'bigint':
      return String(value);
    default:
      return undefined;
  }
};

const str = (value: unknown): string => optionalStr(value) ?? '';

/** PHP encodes an empty associative array as `[]` */
const methods = (value: unknown): Record<string, string> =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
    ? Object.fromEntries(
        Object.entries(value as Json).map(([k, v]) => [k, String(v)]),
      )
    : {};

/** @internal */
export function statusFromJson(json: Json): PaywayStatus {
  const status: PaywayStatus = {
    code: str(json['code']),
    message: str(json['message']),
  };
  const tranId = optionalStr(json['tran_id']);
  const traceId = optionalStr(json['trace_id']);
  const correlationId = optionalStr(json['correlation_id']);
  if (tranId !== undefined) status.tranId = tranId;
  if (traceId !== undefined) status.traceId = traceId;
  if (correlationId !== undefined) status.correlationId = correlationId;
  return status;
}

/** @internal */
export function registerMerchantResponseFromJson(
  json: Json,
): RegisterMerchantResponse {
  const status = statusFromJson(json['status'] as Json);
  return {
    // the documented sample url has a leading space
    url: str(json['url']).trim(),
    token: str(json['token']),
    status,
    isSuccess: status.code === PaywayPartnerStatusCode.success,
  };
}

/** @internal */
export function inquiryResponseFromJson(json: Json): InquiryResponse {
  const status = statusFromJson(json['status'] as Json);
  return {
    data: str(json['data']),
    status,
    isSuccess: status.code === PaywayPartnerStatusCode.success,
  };
}

/** Maps decrypted PayWay JSON (snake_case) to a {@link MerchantCredential}. */
export function merchantCredentialFromJson(json: Json): MerchantCredential {
  return {
    partnerName: str(json['partner_name']),
    merchantName: str(json['merchant_name']),
    mid: str(json['mid']),
    merchantKey: str(json['merchant_key']),
    publicKey: str(json['public_key']),
    registerRef: str(json['register_ref']),
    currency: str(json['currency']),
    rsaPublicKey: str(json['rsa_public_key']),
  };
}

/** Maps a {@link MerchantCredential} back to PayWay's field names. */
export function merchantCredentialToJson(credential: MerchantCredential): Json {
  return {
    partner_name: credential.partnerName,
    merchant_name: credential.merchantName,
    mid: credential.mid,
    merchant_key: credential.merchantKey,
    public_key: credential.publicKey,
    register_ref: credential.registerRef,
    currency: credential.currency,
    rsa_public_key: credential.rsaPublicKey,
  };
}

/** Maps decrypted PayWay JSON (snake_case) to a {@link MerchantInfo}. */
export function merchantInfoFromJson(json: Json): MerchantInfo {
  return {
    outletName: str(json['outlet_name']),
    abaAccountKhr: str(json['aba_account_khr']),
    abaAccountUsd: str(json['aba_account_usd']),
    availablePaymentMethods: methods(json['available_payment_methods']),
    enabledPaymentMethods: methods(json['enabled_payment_methods']),
    pendingPaymentMethods: methods(json['pending_payment_methods']),
  };
}

/** Builds the `getMcInfo` request from stored merchant credentials. */
export function toGetMcInfoRequest(
  credential: MerchantCredential,
  currency: string = credential.currency,
): GetMcInfoRequest {
  const request: GetMcInfoRequest = {
    merchantKey: credential.merchantKey,
    currency,
    publicKey: credential.publicKey,
  };
  if (credential.rsaPublicKey !== '') {
    request.rsaPublicKey = credential.rsaPublicKey;
  }
  return request;
}
