<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/**
 * Request of `get-mc-info` (inquiry merchant info via merchant public key).
 *
 * The keys are never sent as is: they key the hashes PayWay verifies.
 */
final readonly class GetMcInfoRequest
{
    /**
     * @param string $merchantKey merchant key provided by ABA
     * @param string $currency `USD` or `KHR`
     * @param string $publicKey merchant public key, keys `public_key_hash_encrypt` (HMAC-SHA512)
     * @param ?string $rsaPublicKey merchant RSA public key, encrypts `rsa_public_key_hash_encrypt`
     */
    public function __construct(
        public string $merchantKey,
        public string $currency,
        #[\SensitiveParameter] public string $publicKey,
        public ?string $rsaPublicKey = null,
    ) {
    }
}
