// Offline tests of the Node specifics: injected fetch, headers, errors.
import { readFileSync } from 'node:fs';

import { describe, expect, it } from 'vitest';

import {
  NodePaywayPartnerCrypto,
  PaywayPartnerError,
  PaywayPartnerService,
  REGISTER_MERCHANT_PATH,
  SDK_VERSION,
  toGetMcInfoRequest,
} from '../src/index.js';
import { fakeFetch, fixture, testPartner } from './helpers.js';

const partner = testPartner();
const notFound = () =>
  Response.json(
    { status: { code: 'PTL46', message: 'Merchant not found' } },
    { status: 403 },
  );

describe('PaywayPartnerService with an injected fetch', () => {
  it('posts JSON with headers and the injected clock', async () => {
    const fetch = fakeFetch(() =>
      Response.json({
        url: 'https://payway.test/self-register',
        token: 't',
        status: { code: '00', message: 'Success!' },
      }),
    );
    const service = new PaywayPartnerService({
      partner,
      fetch,
      clock: () => new Date(Date.UTC(2026, 0, 2, 3, 4, 5)),
    });

    const response = await service.registerMerchant({
      pushbackUrl: 'p',
      redirectUrl: 'r',
      registerRef: 'ref-001',
      currency: 'USD',
    });

    expect(response.isSuccess).toBe(true);
    const request = fetch.requests[0]!;
    expect(request.url).toBe(`https://payway.test${REGISTER_MERCHANT_PATH}`);
    expect(request.method).toBe('POST');
    expect(request.headers.get('content-type')).toBe('application/json');
    expect(request.headers.get('referer')).toBe('https://partner.test');
    expect(request.headers.get('user-agent')).toBe(
      `payway-partner-node/${SDK_VERSION}`,
    );
    expect(fetch.bodies[0]!['request_time']).toBe('20260102030405');
  });

  it('logs to the injected logger only', async () => {
    const lines: string[] = [];
    const service = new PaywayPartnerService({
      partner,
      fetch: fakeFetch(notFound),
      logger: (line) => lines.push(line),
    });
    await service.checkMerchant({ registerRef: 'a' });
    expect(lines).toHaveLength(2);
    expect(lines[0]).toContain('POST https://payway.test');
    expect(lines[1]).toContain('403');
  });

  it('network failures are retryable connection errors', async () => {
    const service = new PaywayPartnerService({
      partner,
      fetch: fakeFetch(() => {
        throw new TypeError('fetch failed');
      }),
    });
    const error = (await service
      .checkMerchant({ registerRef: 'a' })
      .catch((e: unknown) => e)) as PaywayPartnerError;
    expect(error).toBeInstanceOf(PaywayPartnerError);
    expect(error.type).toBe('connection');
    expect(error.isRetryable).toBe(true);
    expect(error.cause).toBeInstanceOf(TypeError);
  });

  it('an aborted call is cancelled', async () => {
    const controller = new AbortController();
    controller.abort();
    const service = new PaywayPartnerService({
      partner,
      fetch: fakeFetch(notFound),
    });
    const error = (await service
      .checkMerchant({ registerRef: 'a' }, { signal: controller.signal })
      .catch((e: unknown) => e)) as PaywayPartnerError;
    expect(error.type).toBe('cancelled');
    expect(error.isRetryable).toBe(false);
  });

  it('a slow reply times out', async () => {
    const service = new PaywayPartnerService({
      partner,
      timeoutMs: 20,
      fetch: fakeFetch(
        (request) =>
          new Promise((_, reject) => {
            request.signal.addEventListener('abort', () => {
              reject(
                request.signal.reason instanceof Error
                  ? request.signal.reason
                  : new Error('aborted'),
              );
            });
          }),
      ),
    });
    const error = (await service
      .checkMerchant({ registerRef: 'a' })
      .catch((e: unknown) => e)) as PaywayPartnerError;
    expect(error.type).toBe('timeout');
    expect(error.isRetryable).toBe(true);
  });

  it('decryption errors are typed', () => {
    const service = new PaywayPartnerService({ partner });
    const foreign = new NodePaywayPartnerCrypto().encryptJson(
      { a: 1 },
      fixture('rsa_2048_public.pem'),
    );
    expect(() => service.decryptMerchantData(foreign)).toThrow(
      expect.objectContaining({ type: 'decryption' }),
    );
    expect(() => service.decryptMcInfo('%%%')).toThrow(
      expect.objectContaining({ type: 'decryption' }),
    );
  });
});

describe('crypto', () => {
  const crypto = new NodePaywayPartnerCrypto();

  it('accepts PKCS#1 public, PKCS#8 private and bare base64 keys', () => {
    const pkcs1 = crypto.encryptString(
      'hello',
      fixture('rsa_1024_public_pkcs1.pem'),
    );
    expect(
      crypto.decryptString(pkcs1, fixture('rsa_1024_private_pkcs8.pem')),
    ).toBe('hello');

    const bare = fixture('rsa_1024_public.pem')
      .split('\n')
      .filter((l) => l !== '' && !l.startsWith('-----'))
      .join('');
    expect(
      crypto.decryptString(
        crypto.encryptString('hi', bare),
        partner.partnerPrivateKey,
      ),
    ).toBe('hi');
  });

  it('rejects data that is not whole key-size blocks', () => {
    expect(() =>
      crypto.decryptString(
        Buffer.from([1, 2, 3]).toString('base64'),
        partner.partnerPrivateKey,
      ),
    ).toThrow(RangeError);
  });
});

it('toGetMcInfoRequest drops an empty RSA key', () => {
  const request = toGetMcInfoRequest({
    partnerName: 'P',
    merchantName: 'M',
    mid: '1',
    merchantKey: 'mk',
    publicKey: 'pk',
    registerRef: 'r',
    currency: 'USD',
    rsaPublicKey: '',
  });
  expect(request).toEqual({
    merchantKey: 'mk',
    currency: 'USD',
    publicKey: 'pk',
  });
});

it('SDK_VERSION matches package.json', () => {
  const pkg = JSON.parse(
    readFileSync(new URL('../package.json', import.meta.url), 'utf8'),
  ) as { version: string };
  expect(SDK_VERSION).toBe(pkg.version);
});
