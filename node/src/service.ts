import { NodePaywayPartnerCrypto, type PaywayPartnerCrypto } from './crypto.js';
import { PaywayPartnerError, type PaywayPartnerErrorType } from './errors.js';
import {
  inquiryResponseFromJson,
  merchantCredentialFromJson,
  merchantInfoFromJson,
  registerMerchantResponseFromJson,
  type CheckMerchantRequest,
  type GetMcInfoRequest,
  type InquiryResponse,
  type MerchantCredential,
  type MerchantInfo,
  type PaywayPartner,
  type RegisterMerchantRequest,
  type RegisterMerchantResponse,
} from './models.js';
import {
  PaywayPartnerRequestBuilder,
  type PaywayPartnerClock,
  type SignedBody,
} from './request-builder.js';
import { SDK_VERSION } from './version.js';

/** receives request/response log lines */
export type PaywayPartnerLogger = (message: string) => void;

/** Options of every API call. */
export interface CallOptions {
  /** aborts the call; it then throws a `cancelled` {@link PaywayPartnerError} */
  signal?: AbortSignal;
}

/** Dependencies of {@link PaywayPartnerService}; all but `partner` are optional. */
export interface PaywayPartnerServiceOptions {
  /** partner credentials used to sign and decrypt */
  partner: PaywayPartner;
  /** HTTP client (default: global `fetch`) */
  fetch?: typeof globalThis.fetch;
  /** source of `request_time` (default: current time) */
  clock?: PaywayPartnerClock;
  /** RSA/HMAC implementation (default: `node:crypto`) */
  crypto?: PaywayPartnerCrypto;
  /** receives request/response logs; nothing is logged without it */
  logger?: PaywayPartnerLogger;
  /** per request timeout in milliseconds (default 60 000) */
  timeoutMs?: number;
}

/** endpoint of {@link PaywayPartnerService.registerMerchant} */
export const REGISTER_MERCHANT_PATH =
  '/api/merchant-portal/online-self-activation/new-merchant';
/** endpoint of {@link PaywayPartnerService.checkMerchant} */
export const CHECK_MERCHANT_PATH =
  '/api/merchant-portal/online-self-activation/get-mc-credential-info';
/** endpoint of {@link PaywayPartnerService.getMcInfo} */
export const GET_MC_INFO_PATH =
  '/api/merchant-portal/online-self-activation/get-mc-info';

/**
 * ABA PayWay partner API client.
 *
 * PayWay business errors (`PTL02 Wrong Hash`, `PTL46 Merchant not found`, ...)
 * are returned in `status`. A {@link PaywayPartnerError} is thrown only when
 * PayWay could not be reached, did not answer with a status, or data could
 * not be decrypted.
 *
 * Run this on your server: the partner key and private key are secrets.
 */
export class PaywayPartnerService {
  /** partner credentials used to sign and decrypt */
  readonly partner: PaywayPartner;
  /** builds the signed request bodies; exposed to support new endpoints */
  readonly requestBuilder: PaywayPartnerRequestBuilder;
  readonly #crypto: PaywayPartnerCrypto;
  readonly #fetch: typeof globalThis.fetch;
  readonly #logger: PaywayPartnerLogger | undefined;
  readonly #timeoutMs: number;

  constructor(options: PaywayPartnerServiceOptions) {
    this.partner = options.partner;
    this.#crypto = options.crypto ?? new NodePaywayPartnerCrypto();
    this.requestBuilder = new PaywayPartnerRequestBuilder(options.partner, {
      ...(options.clock && { clock: options.clock }),
      crypto: this.#crypto,
    });
    this.#fetch = options.fetch ?? globalThis.fetch;
    this.#logger = options.logger;
    this.#timeoutMs = options.timeoutMs ?? 60_000;
  }

  /**
   * Register a merchant; redirect the merchant to the returned `url`, then
   * wait for the pushback (see {@link decryptPushback}).
   */
  registerMerchant(
    request: RegisterMerchantRequest,
    options: CallOptions = {},
  ): Promise<RegisterMerchantResponse> {
    return this.#post(
      REGISTER_MERCHANT_PATH,
      this.requestBuilder.registerMerchant(request),
      registerMerchantResponseFromJson,
      options,
    );
  }

  /** Inquiry merchant info via register ref; decrypt with {@link decryptMerchantCredential}. */
  checkMerchant(
    request: CheckMerchantRequest,
    options: CallOptions = {},
  ): Promise<InquiryResponse> {
    return this.#post(
      CHECK_MERCHANT_PATH,
      this.requestBuilder.checkMerchant(request),
      inquiryResponseFromJson,
      options,
    );
  }

  /** Inquiry merchant info via merchant public key; decrypt with {@link decryptMcInfo}. */
  getMcInfo(
    request: GetMcInfoRequest,
    options: CallOptions = {},
  ): Promise<InquiryResponse> {
    return this.#post(
      GET_MC_INFO_PATH,
      this.requestBuilder.getMcInfo(request),
      inquiryResponseFromJson,
      options,
    );
  }

  /**
   * Decrypt encrypted PayWay `data` with the partner private key.
   * @throws {PaywayPartnerError} `decryption` when it cannot be decrypted
   */
  decryptMerchantData(data: string): Record<string, unknown> {
    try {
      return this.#crypto.decryptJson(data, this.partner.partnerPrivateKey);
    } catch (error) {
      throw new PaywayPartnerError(
        'decryption',
        'Could not decrypt PayWay data',
        { cause: error },
      );
    }
  }

  /** Decrypt the `data` of {@link checkMerchant}. */
  decryptMerchantCredential(data: string): MerchantCredential {
    return merchantCredentialFromJson(this.decryptMerchantData(data));
  }

  /** Decrypt the `data` of {@link getMcInfo}. */
  decryptMcInfo(data: string): MerchantInfo {
    return merchantInfoFromJson(this.decryptMerchantData(data));
  }

  /**
   * Decrypt the body PayWay POSTs (as `text/plain`) to your `pushback_url`:
   * `{"return_params": "<encrypted merchant details>"}`.
   * @throws {PaywayPartnerError} `invalidPushback` or `decryption`
   */
  decryptPushback(body: string): MerchantCredential {
    let decoded: unknown;
    try {
      decoded = JSON.parse(body);
    } catch (error) {
      throw new PaywayPartnerError(
        'invalidPushback',
        'Pushback body is not JSON',
        { cause: error },
      );
    }
    const returnParams =
      decoded !== null && typeof decoded === 'object'
        ? (decoded as Record<string, unknown>)['return_params']
        : undefined;
    if (typeof returnParams !== 'string') {
      throw new PaywayPartnerError(
        'invalidPushback',
        'Pushback body has no "return_params"',
      );
    }
    return this.decryptMerchantCredential(returnParams);
  }

  /**
   * POST `body` to `path` and parse PayWay's reply. PayWay answers errors
   * with a non-2xx status and a JSON body carrying the real status, which is
   * parsed like a success.
   */
  async #post<T>(
    path: string,
    body: SignedBody,
    parse: (json: Record<string, unknown>) => T,
    options: CallOptions,
  ): Promise<T> {
    const url = new URL(path, this.partner.baseApiUrl);
    const payload = JSON.stringify(body);
    this.#logger?.(`[PayWay] POST ${url.href} ${payload}`);

    const timeout = AbortSignal.timeout(this.#timeoutMs);
    const signal = options.signal
      ? AbortSignal.any([options.signal, timeout])
      : timeout;

    let status: number;
    let text: string;
    try {
      const response = await this.#fetch(url, {
        method: 'POST',
        headers: this.#headers(),
        body: payload,
        signal,
      });
      status = response.status;
      text = await response.text();
    } catch (error) {
      this.#logger?.(`[PayWay] failed ${String(error)}`);
      const [type, message] = describe(error, options.signal, timeout);
      throw new PaywayPartnerError(type, message, { cause: error });
    }

    this.#logger?.(`[PayWay] ${String(status)} ${text}`);
    const json = statusBody(text);
    if (json !== undefined) return parse(json);
    throw new PaywayPartnerError(
      'unexpectedResponse',
      'Unexpected response from PayWay',
      { statusCode: status },
    );
  }

  #headers(): Record<string, string> {
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': `payway-partner-node/${SDK_VERSION}`,
    };
    if (this.partner.partnerReferer !== '') {
      headers['Referer'] = this.partner.partnerReferer;
    }
    return headers;
  }
}

/** decode `text` when it is a JSON object with a PayWay `status` */
function statusBody(text: string): Record<string, unknown> | undefined {
  try {
    const json: unknown = JSON.parse(text);
    if (
      json !== null &&
      typeof json === 'object' &&
      !Array.isArray(json) &&
      typeof (json as Record<string, unknown>)['status'] === 'object' &&
      (json as Record<string, unknown>)['status'] !== null
    ) {
      return json as Record<string, unknown>;
    }
  } catch {
    // not JSON
  }
  return undefined;
}

const CERTIFICATE_ERRORS = new Set([
  'CERT_HAS_EXPIRED',
  'DEPTH_ZERO_SELF_SIGNED_CERT',
  'SELF_SIGNED_CERT_IN_CHAIN',
  'UNABLE_TO_VERIFY_LEAF_SIGNATURE',
  'UNABLE_TO_GET_ISSUER_CERT_LOCALLY',
  'ERR_TLS_CERT_ALTNAME_INVALID',
]);

function describe(
  error: unknown,
  userSignal: AbortSignal | undefined,
  timeout: AbortSignal,
): [PaywayPartnerErrorType, string] {
  if (userSignal?.aborted) {
    return ['cancelled', 'Request to PayWay was cancelled'];
  }
  if (timeout.aborted) return ['timeout', 'Timeout with PayWay'];
  const cause = (error as { cause?: { code?: unknown } } | null)?.cause;
  const code = typeof cause?.code === 'string' ? cause.code : undefined;
  if (code !== undefined && CERTIFICATE_ERRORS.has(code)) {
    return ['badCertificate', 'Bad certificate from PayWay'];
  }
  if (error instanceof TypeError) {
    return ['connection', 'Could not connect to PayWay'];
  }
  return ['unknown', `Request to PayWay failed: ${String(error)}`];
}
