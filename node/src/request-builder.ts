import { NodePaywayPartnerCrypto, type PaywayPartnerCrypto } from './crypto.js';
import type {
  CheckMerchantRequest,
  GetMcInfoRequest,
  PaywayPartner,
  RegisterMerchantRequest,
} from './models.js';

/** returns the current time; injectable so `request_time` can be tested */
export type PaywayPartnerClock = () => Date;

/** A signed body, ready to POST as JSON. */
export type SignedBody = Record<string, string>;

/**
 * Builds the signed JSON bodies PayWay expects: `request_time`,
 * `request_data` (RSA-encrypted payload), `partner_id` and `hash`
 * (HMAC-SHA256 of partner_id + request_data + request_time).
 *
 * To support a new endpoint, build its body with {@link signedBody}.
 */
export class PaywayPartnerRequestBuilder {
  readonly #partner: PaywayPartner;
  readonly #clock: PaywayPartnerClock;
  readonly #crypto: PaywayPartnerCrypto;

  constructor(
    partner: PaywayPartner,
    options: { clock?: PaywayPartnerClock; crypto?: PaywayPartnerCrypto } = {},
  ) {
    this.#partner = partner;
    this.#clock = options.clock ?? (() => new Date());
    this.#crypto = options.crypto ?? new NodePaywayPartnerCrypto();
  }

  /** body of `new-merchant`; `reference_id` mirrors `register_ref` */
  registerMerchant(
    request: RegisterMerchantRequest,
    requestTime?: string,
  ): SignedBody {
    const payload: Record<string, unknown> = {
      pushback_url: request.pushbackUrl,
      redirect_url: request.redirectUrl,
      type: request.type ?? 0,
      register_ref: request.registerRef,
    };
    if (request.merchantType !== undefined) {
      payload['merchant_type'] = request.merchantType;
    }
    payload['currency'] = request.currency;
    return this.signedBody(payload, requestTime, {
      reference_id: request.registerRef,
    });
  }

  /** body of `get-mc-credential-info` */
  checkMerchant(request: CheckMerchantRequest, requestTime?: string): SignedBody {
    return this.signedBody({ register_ref: request.registerRef }, requestTime);
  }

  /**
   * body of `get-mc-info`: `public_key_hash_encrypt` is the HMAC-SHA512 of
   * partner_id + merchant_key + request_time keyed with the merchant public
   * key; `rsa_public_key_hash_encrypt` is the same string RSA-encrypted.
   */
  getMcInfo(request: GetMcInfoRequest, requestTime?: string): SignedBody {
    const time = this.#requestTime(requestTime);
    const hashEncryptString =
      this.#partner.partnerId + request.merchantKey + time;
    const payload: Record<string, unknown> = {
      merchant_key: request.merchantKey,
      currency: request.currency,
      public_key_hash_encrypt: this.#crypto.hmacSha512(
        hashEncryptString,
        request.publicKey,
      ),
    };
    if (request.rsaPublicKey !== undefined) {
      payload['rsa_public_key_hash_encrypt'] = this.#crypto.encryptString(
        hashEncryptString,
        request.rsaPublicKey,
      );
    }
    return this.signedBody(payload, time);
  }

  /** encrypt `payload` as `request_data` and sign it; `extra` is sent as is */
  signedBody(
    payload: Record<string, unknown>,
    requestTime?: string,
    extra: Record<string, string> = {},
  ): SignedBody {
    const time = this.#requestTime(requestTime);
    const requestData = this.#crypto.encryptJson(
      payload,
      this.#partner.partnerPublicKey,
    );
    return {
      request_time: time,
      request_data: requestData,
      partner_id: this.#partner.partnerId,
      ...extra,
      hash: this.hash(requestData, time),
    };
  }

  /** HMAC-SHA256 of partner_id + request_data + request_time with the partner key */
  hash(requestData: string, requestTime: string): string {
    return this.#crypto.hmacSha256(
      this.#partner.partnerId + requestData + requestTime,
      this.#partner.partnerKey,
    );
  }

  #requestTime(requestTime: string | undefined): string {
    const time = requestTime ?? formatRequestTime(this.#clock());
    if (!/^\d{14}$/.test(time)) {
      throw new RangeError(
        `requestTime must be 14 digits YYYYMMDDHHmmss, got "${time}"`,
      );
    }
    return time;
  }
}

/** `YYYYMMDDHHmmss` in UTC, as PayWay requires */
export function formatRequestTime(time: Date): string {
  const two = (value: number) => String(value).padStart(2, '0');
  return (
    String(time.getUTCFullYear()).padStart(4, '0') +
    two(time.getUTCMonth() + 1) +
    two(time.getUTCDate()) +
    two(time.getUTCHours()) +
    two(time.getUTCMinutes()) +
    two(time.getUTCSeconds())
  );
}
