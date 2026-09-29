<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/** Request of `get-mc-credential-info` (inquiry merchant info via register ref). */
final readonly class CheckMerchantRequest
{
    /** @param string $registerRef the `registerRef` used when registering the merchant */
    public function __construct(
        public string $registerRef,
    ) {}

    /**
     * The `request_data` payload, with PayWay's field names.
     *
     * @return array{register_ref: string}
     */
    public function toArray(): array
    {
        return ['register_ref' => $this->registerRef];
    }
}
