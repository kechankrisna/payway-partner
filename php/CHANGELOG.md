## 1.0.0

- First release: register a merchant, decrypt the pushback, inquiry merchant
  info via register ref and via merchant public key.
- Typed `PaywayPartnerException` (`ErrorType`, `isRetryable()`), `StatusCode`.
- Injectable PSR-18 HTTP client, PSR-20 clock, PSR-3 logger and crypto;
  built-in cURL client with TLS verification.
- Passes the shared conformance vectors of the Dart and Node SDKs.
