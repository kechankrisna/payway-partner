# payway_partner

Dart client for the ABA PayWay **partner** API: register merchants on your
platform, receive their credentials, and inquire merchant info.

| Feature | Method |
|---|---|
| Register a merchant | `registerMerchant` |
| Receive the pushback on your `pushback_url` | `decryptPushback` |
| Inquiry merchant info via register ref | `checkMerchant` + `decryptMerchantCredential` |
| Inquiry merchant info via merchant public key | `getMcInfo` + `decryptMcInfo` |

## Setup

```dart
final service = PaywayPartnerService(
  partner: PaywayPartner(
    partnerName: 'your partner name',
    partnerID: 'partner id provided by ABA',
    partnerKey: 'partner key provided by ABA',
    partnerPrivateKey: '-----BEGIN RSA PRIVATE KEY-----...',
    partnerPublicKey: '-----BEGIN PUBLIC KEY-----...',
    partnerReferer: 'https://your-whitelisted-domain.com',
    baseApiUrl: PaywayPartner.sandboxBaseUrl, // or PaywayPartner.productionBaseUrl
  ),
);
```

## Where to run it

Run this SDK on **your server** (or another trusted backend), not in an app
you ship to users or in a browser:

- `partnerKey` and `partnerPrivateKey` are secrets. Anyone who extracts them
  from an app can sign requests and decrypt merchant credentials as you.
- PayWay only accepts requests whose `Referer` matches your whitelisted
  domain, and browsers do not let code set `Referer`.
- Your `pushback_url` must be a server endpoint anyway.

Your app then talks to your server, which calls PayWay. The Flutter app in
`example/` embeds keys only to demo the API against the sandbox.

## Register a merchant

```dart
final response = await service.registerMerchant(
  merchant: const PaywayPartnerRegisterMerchant(
    pushbackUrl: 'https://your-domain.com/payway/pushback',
    redirectUrl: 'https://your-domain.com',
    registerRef: 'merchant-001', // unique per request
    currency: 'USD',             // USD or KHR
    type: 0,                     // 0 web (default), 1 native app
    merchantType: 1,             // optional: 0 in-store, 1 online
  ),
);
if (response.isSuccess) {
  // redirect the merchant to response.url to complete registration
}
```

## Receive the pushback

Once the merchant completes registration, PayWay POSTs
`{"return_params": "<encrypted>"}` as `text/plain` to your `pushback_url`:

```dart
final credential = service.decryptPushback(body);
// store credential.merchantKey, publicKey and rsaPublicKey securely
```

## Inquiry merchant info via register ref

Use this when the pushback was missed:

```dart
final response = await service.checkMerchant(
  merchant: const PaywayPartnerCheckMerchant(registerRef: 'merchant-001'),
);
if (response.isSuccess) {
  final credential = service.decryptMerchantCredential(response.data);
}
```

## Inquiry merchant info via merchant public key

```dart
final response = await service.getMcInfo(
  merchant: credential.toGetMcInfoMerchant(), // or PaywayPartnerGetMcInfoMerchant(...)
);
if (response.isSuccess) {
  final info = service.decryptMcInfo(response.data);
  print(info.enabledPaymentMethods);
}
```

## Errors

- PayWay business errors are **returned** in `response.status`
  (`PTL02` wrong hash, `PTL46` merchant not found, ...). Check `response.isSuccess`.
  Compare codes with the named constants in `PaywayPartnerStatusCode`.
- A `PaywayPartnerException` is **thrown** when PayWay could not be reached
  or did not answer with a status, and when data cannot be decrypted
  (`decryptPushback`, `decryptMerchantCredential`, `decryptMcInfo`).
  Branch on `type` (`connection`, `timeout`, `cancelled`, `badCertificate`,
  `unexpectedResponse`, `decryption`, `invalidPushback`, `unknown`);
  `isRetryable` tells whether retrying later may help, and `cause` holds the
  original error.

```dart
try {
  final response = await service.checkMerchant(merchant: request);
  if (response.status.code == PaywayPartnerStatusCode.merchantNotFound) {
    // registration not completed yet
  }
} on PaywayPartnerException catch (e) {
  if (e.isRetryable) {
    // network problem, retry later
  }
}
```

Every call accepts a `CancelToken` (re-exported from `dio`):

```dart
final token = CancelToken();
final future = service.checkMerchant(merchant: request, cancelToken: token);
token.cancel(); // the call throws PaywayPartnerException
```

## Dependency injection

Every dependency except `partner` is optional:

```dart
final service = PaywayPartnerService(
  partner: partner,
  dio: myDio,              // your HTTP client, used as is and reused for all calls
  clock: () => myClock(),  // source of request_time (default DateTime.now)
  crypto: myCrypto,        // RSA/HMAC implementation (default PaywayPartnerCrypto)
  logger: (line) => log(line), // request/response logs; nothing is logged without it
);
```

The building blocks are public too: `PaywayPartnerRequestBuilder` builds the
signed request bodies and `PaywayPartnerCrypto` does the RSA/HMAC work.

## JSON

Every model is annotated with `json_annotation` and has generated
`fromJson` / `toJson`. PayWay models use PayWay's snake_case field names:

```dart
final credential = service.decryptPushback(body);
await store.write(jsonEncode(credential.toJson())); // {"merchant_key": ..., ...}
final restored = PaywayPartnerMerchantCredential.fromJson(jsonDecode(saved));
```

`PaywayPartner.fromJson` / `toJson` use the Dart field names (`partnerID`, ...)
for loading your configuration. Both `toJson` outputs contain secrets.

After changing a model, regenerate the `*.g.dart` files (they are committed):

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Tests

This package lives in the [payway-partner](https://github.com/kechankrisna/payway-partner)
repository, next to the Node and PHP SDKs; all three pass the same test
vectors in `spec/test-vectors`.

```sh
dart test -x integration   # offline unit tests and shared vectors
dart test -t integration   # ABA sandbox tests, need ../.env (see ../.env.example)
```

See the `example` folder for a Flutter app (`flutter run --dart-define-from-file=../../.env`).

## License

MIT, see `LICENSE`.
