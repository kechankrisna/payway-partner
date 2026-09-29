# PayWay Partner SDKs

Clients for the **ABA PayWay partner API**: register merchants on your
platform, receive their credentials, and inquire merchant info. The same SDK
is available for three languages, all tested against one shared set of test
vectors.

| Language | Package | Install | Docs |
|---|---|---|---|
| Dart / Flutter | [`payway_partner`](https://pub.dev/packages/payway_partner) | `dart pub add payway_partner` | [dart/](dart/README.md) |
| Node.js (TypeScript) | [`@kechankrisna/payway-partner`](https://www.npmjs.com/package/@kechankrisna/payway-partner) | `npm install @kechankrisna/payway-partner` | [node/](node/README.md) |
| PHP | [`kechankrisna/payway-partner`](https://packagist.org/packages/kechankrisna/payway-partner) | `composer require kechankrisna/payway-partner` | [php/](php/README.md) |

## Features

| Feature | Dart | Node | PHP |
|---|---|---|---|
| Register a merchant | `registerMerchant` | `registerMerchant` | `registerMerchant` |
| Decrypt the pushback on your `pushback_url` | `decryptPushback` | `decryptPushback` | `decryptPushback` |
| Inquiry merchant info via register ref | `checkMerchant` | `checkMerchant` | `checkMerchant` |
| Inquiry merchant info via merchant public key | `getMcInfo` | `getMcInfo` | `getMcInfo` |

All three SDKs share the same design:

- PayWay business errors (`PTL02 Wrong Hash`, `PTL46 Merchant not found`, ...)
  are **returned** in `status`; network and decryption failures **throw** a
  typed error with an error type and `isRetryable`.
- Every dependency is injectable: HTTP client, clock, crypto, logger.
- TLS certificates are always verified; secrets are kept out of logs.
- `request_time` is UTC; RSA works with 1024 and 2048 bit keys in PEM
  (PKCS#1 / PKCS#8 / SPKI) or bare base64.

## Where to run it

Run these SDKs on **your server**, never in an app you ship or in a browser:
the partner key and private key are secrets, PayWay requires a whitelisted
`Referer`, and your `pushback_url` is a server endpoint anyway.

## Repository layout

```
spec/
  test-vectors/   shared conformance vectors every SDK must pass
  fixtures/       throwaway RSA keys used by the vectors (not ABA keys)
dart/             Dart SDK        → pub.dev
node/             Node.js SDK     → npm
php/              PHP SDK         → Packagist (composer.json is at the root)
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for running the tests and releasing.

## License

[MIT](LICENSE)
