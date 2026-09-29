// Integration tests against the ABA PayWay sandbox. They need the sandbox
// credentials in ../.env (see ../.env.example) and are skipped without it.
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { beforeAll, describe, expect, it } from 'vitest';

import {
  PAYWAY_SANDBOX_URL,
  PaywayPartnerService,
  PaywayPartnerStatusCode,
} from '../src/index.js';

const envFile = fileURLToPath(new URL('../../.env', import.meta.url));

describe.skipIf(!existsSync(envFile))('ABA PayWay sandbox', () => {
  let service: PaywayPartnerService;

  beforeAll(() => {
    process.loadEnvFile(envFile);
    const env = (key: string) => process.env[key] ?? '';
    const pem = (key: string) =>
      Buffer.from(env(key), 'base64').toString('utf8');
    service = new PaywayPartnerService({
      partner: {
        partnerName: env('ABA_PARTNER_NAME'),
        partnerId: env('ABA_PARTNER_ID'),
        partnerKey: env('ABA_PARTNER_KEY'),
        partnerPrivateKey: pem('ABA_PARTNER_PRIVATE_KEY'),
        partnerPublicKey: pem('ABA_PARTNER_PUBLIC_KEY'),
        partnerReferer: env('ABA_PARTNER_REFERER_DOMAIN'),
        baseApiUrl: env('ABA_PARTNER_API_URL') || PAYWAY_SANDBOX_URL,
      },
    });
  });

  it('register a merchant returns the onboarding url', async () => {
    const response = await service.registerMerchant({
      pushbackUrl:
        'https://www.mylekha.org/api/v1.0/integrate/payway/success?register_ref=mylekha003',
      redirectUrl: 'https://www.mylekha.org',
      type: 1,
      registerRef: 'mylekha003',
      merchantType: 1,
      currency: 'USD',
    });
    expect(response.isSuccess, JSON.stringify(response.status)).toBe(true);
    expect(response.url).toMatch(/^https:\/\//);
    expect(response.token).not.toBe('');
  });

  it('inquiry via register ref of an unfinished registration', async () => {
    const response = await service.checkMerchant({ registerRef: 'mylekha003' });
    expect(response.status.code).toBe(PaywayPartnerStatusCode.merchantNotFound);
    expect(response.data).toBe('');
  });

  it('inquiry via public key of an unknown merchant', async () => {
    const response = await service.getMcInfo({
      merchantKey: 'UNKNOWN000',
      currency: 'USD',
      publicKey: 'not-a-real-key',
    });
    expect(response.isSuccess).toBe(false);
    expect(response.status.traceId).toBeTruthy();
  });

  it('a wrong partner key is reported as PTL02', async () => {
    const wrongKey = new PaywayPartnerService({
      partner: { ...service.partner, partnerKey: 'wrong-key' },
    });
    const response = await wrongKey.checkMerchant({
      registerRef: 'mylekha003',
    });
    expect(response.status.code).toBe(PaywayPartnerStatusCode.wrongHash);
  });
});
