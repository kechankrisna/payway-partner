<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/**
 * Decrypted merchant info returned by the inquiry via public key.
 * Payment method maps are `code => label`, e.g. `['abapay_khqr' => 'ABA Pay KHQR']`.
 */
final readonly class MerchantInfo
{
    /**
     * @param string $outletName outlet (merchant) name
     * @param string $abaAccountKhr ABA account receiving KHR payments, empty when none
     * @param string $abaAccountUsd ABA account receiving USD payments, empty when none
     * @param array<string, string> $availablePaymentMethods payment methods the merchant can apply for
     * @param array<string, string> $enabledPaymentMethods payment methods the merchant can accept now
     * @param array<string, string> $pendingPaymentMethods payment methods awaiting approval
     */
    public function __construct(
        public string $outletName,
        public string $abaAccountKhr,
        public string $abaAccountUsd,
        public array $availablePaymentMethods = [],
        public array $enabledPaymentMethods = [],
        public array $pendingPaymentMethods = [],
    ) {}

    /**
     * Parses decrypted PayWay JSON.
     *
     * @param array<array-key, mixed> $json
     */
    public static function fromArray(array $json): self
    {
        return new self(
            Json::string($json, 'outlet_name'),
            Json::string($json, 'aba_account_khr'),
            Json::string($json, 'aba_account_usd'),
            Json::methods($json, 'available_payment_methods'),
            Json::methods($json, 'enabled_payment_methods'),
            Json::methods($json, 'pending_payment_methods'),
        );
    }

    /**
     * PayWay's field names.
     *
     * @return array<string, string|array<string, string>>
     */
    public function toArray(): array
    {
        return [
            'outlet_name' => $this->outletName,
            'aba_account_khr' => $this->abaAccountKhr,
            'aba_account_usd' => $this->abaAccountUsd,
            'available_payment_methods' => $this->availablePaymentMethods,
            'enabled_payment_methods' => $this->enabledPaymentMethods,
            'pending_payment_methods' => $this->pendingPaymentMethods,
        ];
    }
}
