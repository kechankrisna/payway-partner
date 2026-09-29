<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/**
 * Response of both merchant inquiries. `data` is encrypted: decrypt it with
 * `PaywayPartnerService::decryptMerchantCredential()` (inquiry via register
 * ref) or `decryptMcInfo()` (inquiry via public key).
 */
final readonly class InquiryResponse
{
    /**
     * @param string $data encrypted merchant details, empty unless successful
     * @param Status $status PayWay's `status` object
     */
    public function __construct(
        public string $data,
        public Status $status,
    ) {}

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
            Json::string($json, 'data'),
            Status::fromArray(Json::object($json, 'status')),
        );
    }

    /**
     * PayWay's field names.
     *
     * @return array{data: string, status: array<string, string>}
     */
    public function toArray(): array
    {
        return ['data' => $this->data, 'status' => $this->status->toArray()];
    }
}
