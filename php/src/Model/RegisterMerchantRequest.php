<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/** Request of `new-merchant` (register a merchant). */
final readonly class RegisterMerchantRequest
{
    /**
     * @param string $pushbackUrl PayWay POSTs the merchant details here once registration completes
     * @param string $redirectUrl embedded in the button on PayWay's success screen; native app
     *     (`type` 1): `{"ios_scheme":"...","android_scheme":"..."}`, web (`type` 0): a URL
     * @param string $registerRef your unique reference for this registration (letters, numbers, `_`, `-`)
     * @param 'USD'|'KHR' $currency merchant currency to register
     * @param 0|1 $type activation platform: `0` web, `1` native app
     * @param 0|1|null $merchantType `0` in-store merchant, `1` online merchant (ABA default when null)
     */
    public function __construct(
        public string $pushbackUrl,
        public string $redirectUrl,
        public string $registerRef,
        public string $currency,
        public int $type = 0,
        public ?int $merchantType = null,
    ) {
    }

    /**
     * The `request_data` payload, with PayWay's field names.
     *
     * @return array<string, int|string>
     */
    public function toArray(): array
    {
        $payload = [
            'pushback_url' => $this->pushbackUrl,
            'redirect_url' => $this->redirectUrl,
            'type' => $this->type,
            'register_ref' => $this->registerRef,
        ];
        if ($this->merchantType !== null) {
            $payload['merchant_type'] = $this->merchantType;
        }
        $payload['currency'] = $this->currency;

        return $payload;
    }
}
