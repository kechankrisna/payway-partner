<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/**
 * Decrypted merchant details, sent to your `pushback_url` and returned by the
 * inquiry via register ref. Store these securely.
 */
final readonly class MerchantCredential
{
    /**
     * @param string $partnerName your official partner name registered in PayWay
     * @param string $merchantName outlet name
     * @param string $mid MID representing the outlet
     * @param string $merchantKey `merchant_id` used for purchase, refund and other merchant APIs
     * @param string $publicKey merchant public key (secret)
     * @param string $registerRef your register reference id
     * @param string $currency merchant currency code: `USD`, `KHR` or both
     * @param string $rsaPublicKey merchant RSA public key
     */
    public function __construct(
        public string $partnerName,
        public string $merchantName,
        public string $mid,
        public string $merchantKey,
        #[\SensitiveParameter]
        public string $publicKey,
        public string $registerRef,
        public string $currency,
        public string $rsaPublicKey,
    ) {}

    /**
     * Parses decrypted PayWay JSON.
     *
     * @param array<array-key, mixed> $json
     */
    public static function fromArray(array $json): self
    {
        return new self(
            Json::string($json, 'partner_name'),
            Json::string($json, 'merchant_name'),
            Json::string($json, 'mid'),
            Json::string($json, 'merchant_key'),
            Json::string($json, 'public_key'),
            Json::string($json, 'register_ref'),
            Json::string($json, 'currency'),
            Json::string($json, 'rsa_public_key'),
        );
    }

    /**
     * PayWay's field names, for storing; contains the merchant keys.
     *
     * @return array<string, string>
     */
    public function toArray(): array
    {
        return [
            'partner_name' => $this->partnerName,
            'merchant_name' => $this->merchantName,
            'mid' => $this->mid,
            'merchant_key' => $this->merchantKey,
            'public_key' => $this->publicKey,
            'register_ref' => $this->registerRef,
            'currency' => $this->currency,
            'rsa_public_key' => $this->rsaPublicKey,
        ];
    }

    /** Builds the request of the inquiry via public key from these credentials. */
    public function toGetMcInfoRequest(?string $currency = null): GetMcInfoRequest
    {
        return new GetMcInfoRequest(
            $this->merchantKey,
            $currency ?? $this->currency,
            $this->publicKey,
            $this->rsaPublicKey === '' ? null : $this->rsaPublicKey,
        );
    }

    /**
     * Keeps the keys out of var_dump() and print_r().
     *
     * @return array<string, string>
     */
    public function __debugInfo(): array
    {
        return ['public_key' => '***'] + $this->toArray();
    }
}
