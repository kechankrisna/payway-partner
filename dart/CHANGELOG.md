## 2.0.1

- Docs: test commands in the README are safe to paste into zsh.
- First release published automatically from GitHub Actions.

## 2.0.0

First release under the new name **`payway_partner`**, the successor of
[`dart_payway_partner`](https://pub.dev/packages/dart_payway_partner) 1.x.
To migrate, replace the dependency and imports:
`package:dart_payway_partner/dart_payway_partner.dart` →
`package:payway_partner/payway_partner.dart`.

### Breaking changes
- fields are camelCase (`registerRef`, `pushbackUrl`, `merchantKey`, ...); JSON keys sent to PayWay are unchanged
- `PaywayPartnerRegisterMerchant.currency` (`USD`/`KHR`) is required, as per ABA docs; `type` defaults to `0`
- one `PaywayPartnerStatus` (`code`, `message`, `tranId`, `traceId`, `correlationId`, `isSuccess`) replaces
  `PaywayPartnerRegisterMerchantResponseStatus` and `PaywayPartnerCheckMerchantResponseStatus`
- `PaywayPartnerCheckMerchantResponse` is renamed `PaywayPartnerInquiryResponse` (used by `checkMerchant` and `getMcInfo`)
- network failures and bodies without a PayWay status throw `PaywayPartnerException` instead of returning a fake `PTL46`
- `PaywayPartnerClientFormRequestService` is replaced by `PaywayPartnerRequestBuilder`
  (`registerMerchant`, `checkMerchant`, `getMcInfo`, `signedBody`, `hash`)
- `PaywayPartnerClientService`, `EncoderService`, `PaywayPartnerLogger` (logger class), `PlatformHttpClientAdapter`,
  `dioLoggerInterceptor` are removed; RSA/HMAC is in `PaywayPartnerCrypto`
- the package no longer exports `debugPrint`, `listEquals`, `kIsWeb` or the string/list extensions,
  which clashed with `package:flutter/foundation.dart`
- the per-call `enabledLogger` flag is removed: pass `logger` to `PaywayPartnerService`
- `PaywayPartner.refererDomain` (unused) is removed; `partnerReferer` is sent as `Referer`
- dependencies `intl` and `logger` are removed
- requires Dart 3.9+ (Flutter 3.35+), needed by `json_annotation` 4.12
- models use `json_serializable`: `fromMap` / `toMap` are replaced by generated `fromJson` / `toJson`
  (PayWay snake_case keys; `PaywayPartner` uses its Dart field names)
- decryption errors (`decryptPushback`, `decryptMerchantCredential`, `decryptMcInfo`, `decryptMerchantData`)
  throw `PaywayPartnerException` instead of `FormatException` / `ArgumentError`
- `PaywayPartnerStatus.successCode` is replaced by `PaywayPartnerStatusCode.success`
- `PaywayPartnerException` takes a `PaywayPartnerErrorType` as first argument
- the `encrypt` dependency is replaced by `pointycastle` 4 (drops the discontinued `js` package);
  `PaywayPartnerCrypto.toPublicKeyPem` is removed, keys in any supported format are accepted directly
- license changed from GPL-2.0 to MIT

### Security
- TLS certificates are validated again (the IO adapter accepted any certificate)
- `PaywayPartner.toString()` no longer prints `partnerKey` / `partnerPrivateKey`

### Features
- `getMcInfo`: inquiry merchant info via merchant public key
- `decryptPushback` decodes the `return_params` PayWay sends to `pushback_url`
- typed `PaywayPartnerMerchantCredential` (`decryptMerchantCredential`, `toGetMcInfoMerchant`)
  and `PaywayPartnerMerchantInfo` (`decryptMcInfo`)
- `PaywayPartnerService` accepts injected `dio`, `clock`, `crypto` and `logger`; one HTTP client is reused for all calls
- `PaywayPartner.sandboxBaseUrl` / `productionBaseUrl`; endpoint paths as `PaywayPartnerService.*Path`
- register merchant sends `merchant_type` and `reference_id`, as per ABA docs
- `PaywayPartnerStatusCode`: named constants for every documented status code
- `registerMerchant`, `checkMerchant` and `getMcInfo` accept a `CancelToken` (re-exported from `dio`)
- `PaywayPartnerException.type` (`PaywayPartnerErrorType`) and `isRetryable`
- `User-Agent: payway-partner-dart/<version>` header; `PaywayPartnerService.sdkVersion`
- RSA keys accepted as PEM `PUBLIC KEY` / `RSA PUBLIC KEY` / bare base64, and `RSA PRIVATE KEY` / `PRIVATE KEY` (PKCS#8)

### Fixes
- ABA's real status is kept on error responses (e.g. `PTL02 Wrong Hash`) instead of always `PTL46`
- `request_time` is generated in UTC, as per ABA docs, and validated
- RSA chunk sizes are derived from the key, so 2048 bit keys work (was hard-coded to 1024 bit)
- decryption no longer corrupts multi-byte (e.g. Khmer) text split across chunks
- merchant `rsa_public_key` is accepted as bare base64 (auto PEM wrap)

### Tooling
- `lints` 6 plus `public_member_api_docs`, strict casts and raw types; analysis passes with `--fatal-infos`
- every public API member is documented; code is `dart format`ted (checked in CI)
- GitHub Actions CI: generated code freshness, analysis, unit tests, optional sandbox tests, publish dry-run, example analysis

### Tests
- moved to the `kechankrisna/payway-partner` repository; conformance vectors shared with the Node and PHP SDKs
- offline unit tests (fake HTTP adapter, throwaway keys); sandbox tests tagged `integration` and skipped without `.env`

## 1.0.2+3
- add ABA_PARTNER_REFERER_DOMAIN as Referer
- change from tran_id to support trace_id and correlation_id 

## 1.0.2+2

- fix date_format from yMddhhmmss to yMMddhhmmss

## 1.0.2+1

- add ABA_PARTNER_REFERER_DOMAIN as Referer

## 1.0.2

- fixed kIsWeb
  
## 1.0.1

- fixed env base uri
- add comment as doc


## 1.0.0

- Initial version.
