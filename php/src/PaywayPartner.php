<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner;

/**
 * Partner credentials provided by ABA Bank.
 *
 * `partnerKey` and `partnerPrivateKey` are secrets: keep them on your server.
 */
final readonly class PaywayPartner
{
    /** PayWay sandbox (testing) environment */
    public const string SANDBOX_URL = 'https://sandbox.payway.com.kh';

    /** PayWay production (live) environment */
    public const string PRODUCTION_URL = 'https://merchant.payway.com.kh';

    /**
     * @param string $partnerName your partner name registered with ABA
     * @param string $partnerId encrypted partner id provided by ABA
     * @param string $partnerKey HMAC key used to sign every request (secret)
     * @param string $partnerPrivateKey PEM private key, decrypts PayWay data (secret)
     * @param string $partnerPublicKey PEM public key, encrypts `request_data`
     * @param string $partnerReferer domain whitelisted by ABA, sent as `Referer`
     * @param string $baseApiUrl {@see SANDBOX_URL} or {@see PRODUCTION_URL}
     */
    public function __construct(
        public string $partnerName,
        public string $partnerId,
        #[\SensitiveParameter] public string $partnerKey,
        #[\SensitiveParameter] public string $partnerPrivateKey,
        public string $partnerPublicKey,
        public string $partnerReferer,
        public string $baseApiUrl = self::SANDBOX_URL,
    ) {
    }

    /** Returns a copy with the given fields replaced. */
    public function with(
        ?string $partnerName = null,
        ?string $partnerId = null,
        ?string $partnerKey = null,
        ?string $partnerPrivateKey = null,
        ?string $partnerPublicKey = null,
        ?string $partnerReferer = null,
        ?string $baseApiUrl = null,
    ): self {
        return new self(
            $partnerName ?? $this->partnerName,
            $partnerId ?? $this->partnerId,
            $partnerKey ?? $this->partnerKey,
            $partnerPrivateKey ?? $this->partnerPrivateKey,
            $partnerPublicKey ?? $this->partnerPublicKey,
            $partnerReferer ?? $this->partnerReferer,
            $baseApiUrl ?? $this->baseApiUrl,
        );
    }

    /**
     * Keeps the secrets out of var_dump() and print_r().
     *
     * @return array<string, string>
     */
    public function __debugInfo(): array
    {
        return [
            'partnerName' => $this->partnerName,
            'partnerId' => $this->partnerId,
            'partnerKey' => '***',
            'partnerPrivateKey' => '***',
            'partnerReferer' => $this->partnerReferer,
            'baseApiUrl' => $this->baseApiUrl,
        ];
    }
}
