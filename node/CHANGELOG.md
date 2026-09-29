## 1.0.0

- First release: register a merchant, decrypt the pushback, inquiry merchant
  info via register ref and via merchant public key.
- Typed `PaywayPartnerError` (`type`, `isRetryable`), `PaywayPartnerStatusCode`.
- Injectable `fetch`, clock, crypto and logger; `AbortSignal` and timeout.
- Passes the shared conformance vectors of the Dart and PHP SDKs.
