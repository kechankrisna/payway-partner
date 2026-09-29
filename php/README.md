# kechankrisna/payway-partner

ABA PayWay partner API client for PHP 8.3+.

```sh
composer require kechankrisna/payway-partner
```

| Feature | Method |
|---|---|
| Register a merchant | `registerMerchant` |
| Receive the pushback on your `pushback_url` | `decryptPushback` |
| Inquiry merchant info via register ref | `checkMerchant` + `decryptMerchantCredential` |
| Inquiry merchant info via merchant public key | `getMcInfo` + `decryptMcInfo` |

## Setup

```php
use Kechankrisna\PaywayPartner\PaywayPartner;
use Kechankrisna\PaywayPartner\PaywayPartnerService;

$payway = new PaywayPartnerService(new PaywayPartner(
    partnerName: 'your partner name',
    partnerId: 'partner id provided by ABA',
    partnerKey: getenv('ABA_PARTNER_KEY'),
    partnerPrivateKey: file_get_contents('/secure/partner-private.pem'),
    partnerPublicKey: file_get_contents('/secure/partner-public.pem'),
    partnerReferer: 'https://your-whitelisted-domain.com',
    baseApiUrl: PaywayPartner::SANDBOX_URL, // or PaywayPartner::PRODUCTION_URL
));
```

The default HTTP client uses ext-curl and always verifies TLS certificates.

## Register a merchant

```php
use Kechankrisna\PaywayPartner\Model\RegisterMerchantRequest;

$response = $payway->registerMerchant(new RegisterMerchantRequest(
    pushbackUrl: 'https://your-domain.com/payway/pushback',
    redirectUrl: 'https://your-domain.com',
    registerRef: 'merchant-001', // unique per request
    currency: 'USD',
));
if ($response->isSuccess()) {
    header('Location: ' . $response->url);
}
```

## Receive the pushback

PayWay POSTs `{"return_params": "<encrypted>"}` as `text/plain`:

```php
$credential = $payway->decryptPushback(file_get_contents('php://input'));
// store $credential->merchantKey, publicKey and rsaPublicKey securely
```

## Inquiries

```php
use Kechankrisna\PaywayPartner\Model\CheckMerchantRequest;

$byRef = $payway->checkMerchant(new CheckMerchantRequest('merchant-001'));
if ($byRef->isSuccess()) {
    $credential = $payway->decryptMerchantCredential($byRef->data);

    $byKey = $payway->getMcInfo($credential->toGetMcInfoRequest());
    if ($byKey->isSuccess()) {
        print_r($payway->decryptMcInfo($byKey->data)->enabledPaymentMethods);
    }
}
```

## Errors

- PayWay business errors are **returned** in `$response->status`; compare with
  `StatusCode` (e.g. `StatusCode::MERCHANT_NOT_FOUND`).
- `PaywayPartnerException` is **thrown** when PayWay could not be reached or
  did not answer with a status, and when data cannot be decrypted. Branch on
  `$e->type` (`ErrorType::Connection`, `Timeout`, `BadCertificate`,
  `UnexpectedResponse`, `Decryption`, `InvalidPushback`, ...);
  `$e->isRetryable()` tells whether retrying later may help.

## Dependency injection

Every dependency is optional and uses the PHP standards:

```php
use Kechankrisna\PaywayPartner\Http\Psr18HttpClient;

$factory = new \GuzzleHttp\Psr7\HttpFactory();
$payway = new PaywayPartnerService(
    $partner,
    httpClient: new Psr18HttpClient(new \GuzzleHttp\Client(['timeout' => 30]), $factory, $factory), // PSR-18
    clock: $psr20Clock,     // Psr\Clock\ClockInterface, source of request_time
    crypto: $myCrypto,      // implements Crypto\PaywayPartnerCrypto
    logger: $psr3Logger,    // Psr\Log\LoggerInterface, debug level
);
```

## License

MIT
