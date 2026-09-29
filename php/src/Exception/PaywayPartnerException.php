<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Exception;

/**
 * Thrown when PayWay could not be reached, did not answer with a PayWay
 * status, or its data could not be decrypted. Branch on {@see $type}.
 *
 * Business errors such as `PTL02 Wrong Hash` or `PTL46 Merchant not found`
 * are not thrown: they are returned in the response `status`.
 */
final class PaywayPartnerException extends \RuntimeException
{
    /**
     * @param ErrorType $type what went wrong
     * @param ?int $statusCode HTTP status code, when a response was received
     */
    public function __construct(
        public readonly ErrorType $type,
        string $message,
        public readonly ?int $statusCode = null,
        ?\Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }

    /** Whether retrying the same call later may succeed. */
    public function isRetryable(): bool
    {
        return match ($this->type) {
            ErrorType::Connection, ErrorType::Timeout => true,
            ErrorType::UnexpectedResponse => ($this->statusCode ?? 0) >= 500,
            default => false,
        };
    }
}
