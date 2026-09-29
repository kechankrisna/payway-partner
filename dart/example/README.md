# payway_partner example

A Flutter demo of the [`payway_partner`](https://pub.dev/packages/payway_partner)
SDK against the ABA PayWay **sandbox**: register a merchant, inquire merchant
info via register ref, and via merchant public key. Results are printed to the
debug console.

> Demo only. This app embeds partner keys to call PayWay directly. In
> production, run `PaywayPartnerService` on your server and never ship the
> partner key or private key inside an app.

## Run

1. Put your sandbox credentials in the repository's `.env` (copy
   `.env.example` at the repository root).
2. Run the app with those values as compile-time defines:

```sh
flutter run --dart-define-from-file=../../.env
```

Optional defines for the "get mc info" button: `ABA_MERCHANT_KEY`,
`ABA_MERCHANT_CURRENCY` and `ABA_MERCHANT_PUBLIC_KEY`.

## Test

```sh
flutter test
```
