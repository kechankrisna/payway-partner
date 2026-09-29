# @kechankrisna/payway-partner

ABA PayWay partner API client for Node.js 22+. TypeScript types included; no
runtime dependencies (uses the built-in `fetch` and `node:crypto`).

```sh
npm install @kechankrisna/payway-partner
```

| Feature                                       | Method                                        |
| --------------------------------------------- | --------------------------------------------- |
| Register a merchant                           | `registerMerchant`                            |
| Receive the pushback on your `pushback_url`   | `decryptPushback`                             |
| Inquiry merchant info via register ref        | `checkMerchant` + `decryptMerchantCredential` |
| Inquiry merchant info via merchant public key | `getMcInfo` + `decryptMcInfo`                 |

## Setup

```ts
import {
  PAYWAY_SANDBOX_URL,
  PaywayPartnerError,
  PaywayPartnerService,
  toGetMcInfoRequest,
} from '@kechankrisna/payway-partner';

const payway = new PaywayPartnerService({
  partner: {
    partnerName: 'your partner name',
    partnerId: 'partner id provided by ABA',
    partnerKey: process.env.ABA_PARTNER_KEY!,
    partnerPrivateKey: process.env.ABA_PARTNER_PRIVATE_KEY!, // PEM
    partnerPublicKey: process.env.ABA_PARTNER_PUBLIC_KEY!, // PEM
    partnerReferer: 'https://your-whitelisted-domain.com',
    baseApiUrl: PAYWAY_SANDBOX_URL, // or PAYWAY_PRODUCTION_URL
  },
});
```

Run it on your server: the partner key and private key are secrets.

## Register a merchant

```ts
const response = await payway.registerMerchant({
  pushbackUrl: 'https://your-domain.com/payway/pushback',
  redirectUrl: 'https://your-domain.com',
  registerRef: 'merchant-001', // unique per request
  currency: 'USD',
});
if (response.isSuccess) {
  // redirect the merchant to response.url
}
```

## Receive the pushback

PayWay POSTs `{"return_params": "<encrypted>"}` as `text/plain`:

```ts
app.post('/payway/pushback', express.text({ type: '*/*' }), (req, res) => {
  const credential = payway.decryptPushback(req.body);
  // store credential.merchantKey, publicKey and rsaPublicKey securely
  res.sendStatus(200);
});
```

## Inquiries

```ts
const byRef = await payway.checkMerchant({ registerRef: 'merchant-001' });
if (byRef.isSuccess) {
  const credential = payway.decryptMerchantCredential(byRef.data);

  const byKey = await payway.getMcInfo(toGetMcInfoRequest(credential));
  if (byKey.isSuccess)
    console.log(payway.decryptMcInfo(byKey.data).enabledPaymentMethods);
}
```

## Errors

- PayWay business errors are **returned** in `response.status`; compare with
  `PaywayPartnerStatusCode` (e.g. `PaywayPartnerStatusCode.merchantNotFound`).
- `PaywayPartnerError` is **thrown** when PayWay could not be reached or did
  not answer with a status, and when data cannot be decrypted. Branch on
  `error.type` (`connection`, `timeout`, `cancelled`, `badCertificate`,
  `unexpectedResponse`, `decryption`, `invalidPushback`, `unknown`);
  `error.isRetryable` tells whether retrying later may help.

```ts
try {
  await payway.checkMerchant(
    { registerRef },
    { signal: AbortSignal.timeout(10_000) },
  );
} catch (error) {
  if (error instanceof PaywayPartnerError && error.isRetryable) {
    // retry later
  }
}
```

## Dependency injection

```ts
new PaywayPartnerService({
  partner,
  fetch: myFetch, // any fetch-compatible client
  clock: () => new Date(), // source of request_time
  crypto: myCrypto, // implements PaywayPartnerCrypto
  logger: (line) => log.debug(line), // nothing is logged without it
  timeoutMs: 30_000,
});
```

## License

MIT
