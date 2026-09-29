<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

use Kechankrisna\PaywayPartner\StatusCode;

/** The `status` object of every PayWay partner response. */
final readonly class Status
{
    /**
     * @param string $code status code, `00` on success; see {@see StatusCode}
     * @param string $message human readable status message from PayWay
     * @param ?string $tranId transaction id (register and inquiry via register ref)
     * @param ?string $traceId PayWay log id for debugging (inquiry via public key)
     * @param ?string $correlationId PayWay correlation id for debugging
     */
    public function __construct(
        public string $code,
        public string $message,
        public ?string $tranId = null,
        public ?string $traceId = null,
        public ?string $correlationId = null,
    ) {}

    /** Whether PayWay answered `00` (success). */
    public function isSuccess(): bool
    {
        return $this->code === StatusCode::SUCCESS;
    }

    /**
     * Parses PayWay JSON.
     *
     * @param array<array-key, mixed> $json
     */
    public static function fromArray(array $json): self
    {
        return new self(
            Json::string($json, 'code'),
            Json::string($json, 'message'),
            Json::optionalString($json, 'tran_id'),
            Json::optionalString($json, 'trace_id'),
            Json::optionalString($json, 'correlation_id'),
        );
    }

    /**
     * PayWay's field names; absent ids are left out.
     *
     * @return array<string, string>
     */
    public function toArray(): array
    {
        return array_filter([
            'code' => $this->code,
            'message' => $this->message,
            'tran_id' => $this->tranId,
            'trace_id' => $this->traceId,
            'correlation_id' => $this->correlationId,
        ], static fn(?string $value): bool => $value !== null);
    }
}
