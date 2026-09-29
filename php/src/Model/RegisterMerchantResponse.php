<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/** Response of `new-merchant`. */
final readonly class RegisterMerchantResponse
{
    /**
     * @param string $url onboarding form: redirect the merchant here to complete registration
     * @param string $token unique token of this registration session
     * @param Status $status PayWay's `status` object
     */
    public function __construct(
        public string $url,
        public string $token,
        public Status $status,
    ) {
    }

    /** Whether PayWay answered `00` (success). */
    public function isSuccess(): bool
    {
        return $this->status->isSuccess();
    }

    /**
     * Parses a PayWay response body.
     *
     * @param array<array-key, mixed> $json
     */
    public static function fromArray(array $json): self
    {
        return new self(
            // the documented sample url has a leading space
            trim(Json::string($json, 'url')),
            Json::string($json, 'token'),
            Status::fromArray(Json::object($json, 'status')),
        );
    }

    /**
     * PayWay's field names.
     *
     * @return array{url: string, token: string, status: array<string, string>}
     */
    public function toArray(): array
    {
        return ['url' => $this->url, 'token' => $this->token, 'status' => $this->status->toArray()];
    }
}
