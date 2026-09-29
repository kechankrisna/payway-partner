// Runs the shared conformance vectors in ../spec/test-vectors, which every
// SDK in this repository must pass.
import { describe, expect, it } from 'vitest';

import {
  NodePaywayPartnerCrypto,
  PaywayPartnerError,
  PaywayPartnerRequestBuilder,
  PaywayPartnerService,
  PaywayPartnerStatusCode,
  formatRequestTime,
  merchantCredentialToJson,
  merchantInfoFromJson,
  type InquiryResponse,
  type RegisterMerchantResponse,
} from '../src/index.js';
import {
  fakeFetch,
  fixture,
  statusToJson,
  testPartner,
  vectors,
} from './helpers.js';

type Cases<T> = { cases: T[] };
const crypto = new NodePaywayPartnerCrypto();
const partner = testPartner();

describe('request_time', () => {
  const file = vectors<Cases<{ utc: string; expected: string }>>(
    'request_time.json',
  );
  for (const c of file.cases) {
    it(c.utc, () => {
      expect(formatRequestTime(new Date(c.utc))).toBe(c.expected);
    });
  }
});

describe('hmac', () => {
  const file = vectors<
    Cases<{ algorithm: string; key: string; message: string; expected: string }>
  >('hmac.json');
  for (const c of file.cases) {
    it(`${c.algorithm} ${c.message}`, () => {
      const actual =
        c.algorithm === 'sha256'
          ? crypto.hmacSha256(c.message, c.key)
          : crypto.hmacSha512(c.message, c.key);
      expect(actual).toBe(c.expected);
    });
  }
});

describe('signing', () => {
  const file = vectors<
    Cases<{
      partner_id: string;
      partner_key: string;
      request_data: string;
      request_time: string;
      expected_hash: string;
    }>
  >('signing.json');
  for (const c of file.cases) {
    it(c.request_data, () => {
      const builder = new PaywayPartnerRequestBuilder({
        ...partner,
        partnerId: c.partner_id,
        partnerKey: c.partner_key,
      });
      expect(builder.hash(c.request_data, c.request_time)).toBe(
        c.expected_hash,
      );
    });
  }
});

describe('requests', () => {
  interface RequestCase {
    name: string;
    input: Record<string, unknown>;
    body_keys: string[];
    expected_extra: Record<string, string>;
    expected_payload: Record<string, unknown>;
    expected_rsa_public_key_hash?: string;
  }
  const file = vectors<Cases<RequestCase> & { request_time: string }>(
    'requests.json',
  );
  const builder = new PaywayPartnerRequestBuilder(partner);

  const build = (c: RequestCase) => {
    const i = c.input;
    switch (c.name) {
      case 'register_merchant_minimal':
      case 'register_merchant_full':
        return builder.registerMerchant(
          {
            pushbackUrl: i['pushback_url'] as string,
            redirectUrl: i['redirect_url'] as string,
            registerRef: i['register_ref'] as string,
            currency: i['currency'] as 'USD' | 'KHR',
            ...(i['type'] !== undefined && { type: i['type'] as 0 | 1 }),
            ...(i['merchant_type'] !== undefined && {
              merchantType: i['merchant_type'] as 0 | 1,
            }),
          },
          file.request_time,
        );
      case 'check_merchant':
        return builder.checkMerchant(
          { registerRef: i['register_ref'] as string },
          file.request_time,
        );
      case 'get_mc_info':
        return builder.getMcInfo(
          {
            merchantKey: i['merchant_key'] as string,
            currency: i['currency'] as string,
            publicKey: i['public_key'] as string,
            rsaPublicKey: fixture(i['rsa_public_key'] as string),
          },
          file.request_time,
        );
      default:
        throw new Error(`unknown case ${c.name}`);
    }
  };

  for (const c of file.cases) {
    it(c.name, () => {
      const body = build(c);
      expect(Object.keys(body)).toEqual(c.body_keys);
      expect(body['request_time']).toBe(file.request_time);
      expect(body['partner_id']).toBe(partner.partnerId);
      for (const [key, value] of Object.entries(c.expected_extra)) {
        expect(body[key]).toBe(value);
      }
      expect(body['hash']).toBe(
        crypto.hmacSha256(
          partner.partnerId + body['request_data'] + file.request_time,
          partner.partnerKey,
        ),
      );

      const payload = crypto.decryptJson(
        body['request_data']!,
        partner.partnerPrivateKey,
      );
      const { rsa_public_key_hash_encrypt: rsaHash, ...rest } = payload;
      expect(rest).toEqual(c.expected_payload);
      expect(JSON.stringify(Object.keys(rest))).toBe(
        JSON.stringify(Object.keys(c.expected_payload)),
      );
      if (c.expected_rsa_public_key_hash !== undefined) {
        expect(
          crypto.decryptString(
            rsaHash as string,
            fixture('rsa_2048_private.pem'),
          ),
        ).toBe(c.expected_rsa_public_key_hash);
      }
    });
  }
});

describe('decryption', () => {
  const file = vectors<{
    cases: {
      name: string;
      private_key: string;
      ciphertext: string;
      expected: unknown;
    }[];
    pushback: {
      name: string;
      private_key: string;
      body: string;
      expected?: Record<string, unknown>;
      expected_error?: string;
    }[];
  }>('decryption.json');

  for (const c of file.cases) {
    it(c.name, () => {
      expect(crypto.decryptJson(c.ciphertext, fixture(c.private_key))).toEqual(
        c.expected,
      );
    });
  }

  for (const c of file.pushback) {
    it(`pushback ${c.name}`, () => {
      const service = new PaywayPartnerService({
        partner: { ...partner, partnerPrivateKey: fixture(c.private_key) },
      });
      if (c.expected_error !== undefined) {
        expect(() => service.decryptPushback(c.body)).toThrow(
          expect.objectContaining({ type: c.expected_error }),
        );
      } else {
        expect(
          merchantCredentialToJson(service.decryptPushback(c.body)),
        ).toEqual(c.expected);
      }
    });
  }
});

describe('responses', () => {
  interface ResponseCase {
    name: string;
    endpoint: string;
    http_status: number;
    body?: unknown;
    raw_body?: string;
    expected?: Record<string, unknown> & {
      is_success: boolean;
      status: Record<string, string>;
    };
    expected_error?: { type: string; status_code: number; retryable: boolean };
  }
  const file = vectors<Cases<ResponseCase>>('responses.json');

  for (const c of file.cases) {
    it(c.name, async () => {
      const raw = c.raw_body ?? JSON.stringify(c.body);
      const service = new PaywayPartnerService({
        partner,
        fetch: fakeFetch(() => new Response(raw, { status: c.http_status })),
      });
      const call = (): Promise<RegisterMerchantResponse | InquiryResponse> => {
        switch (c.endpoint) {
          case 'register_merchant':
            return service.registerMerchant({
              pushbackUrl: 'p',
              redirectUrl: 'r',
              registerRef: 'x',
              currency: 'USD',
            });
          case 'check_merchant':
            return service.checkMerchant({ registerRef: 'x' });
          case 'get_mc_info':
            return service.getMcInfo({
              merchantKey: 'k',
              currency: 'USD',
              publicKey: 'p',
            });
          default:
            throw new Error(`unknown endpoint ${c.endpoint}`);
        }
      };

      if (c.expected_error !== undefined) {
        const error = await call().catch((e: unknown) => e);
        expect(error).toBeInstanceOf(PaywayPartnerError);
        const e = error as PaywayPartnerError;
        expect(e.type).toBe(c.expected_error.type);
        expect(e.statusCode).toBe(c.expected_error.status_code);
        expect(e.isRetryable).toBe(c.expected_error.retryable);
        return;
      }

      const response = await call();
      const { is_success, status, ...fields } = c.expected!;
      expect(response.isSuccess).toBe(is_success);
      expect(statusToJson(response.status)).toEqual(status);
      for (const [key, value] of Object.entries(fields)) {
        expect(response[key as keyof typeof response]).toEqual(value);
      }
    });
  }
});

describe('merchant_info', () => {
  const file = vectors<
    Cases<{
      name: string;
      data: Record<string, unknown>;
      expected: Record<string, Record<string, string>>;
    }>
  >('merchant_info.json');
  for (const c of file.cases) {
    it(c.name, () => {
      const info = merchantInfoFromJson(c.data);
      expect(info.availablePaymentMethods).toEqual(
        c.expected['available_payment_methods'],
      );
      expect(info.enabledPaymentMethods).toEqual(
        c.expected['enabled_payment_methods'],
      );
      expect(info.pendingPaymentMethods).toEqual(
        c.expected['pending_payment_methods'],
      );
    });
  }
});

it('status codes', () => {
  const { codes } = vectors<{ codes: Record<string, string> }>(
    'status_codes.json',
  );
  expect(PaywayPartnerStatusCode).toEqual(codes);
});
