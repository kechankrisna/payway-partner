<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Crypto;

/**
 * RSA and HMAC helpers matching the PHP samples in the PayWay partner docs:
 * `openssl_public_encrypt` / `openssl_private_decrypt` (PKCS#1 v1.5) applied
 * in chunks, and `hash_hmac`.
 *
 * Implement this interface to plug in another crypto backend.
 */
interface PaywayPartnerCrypto
{
    /**
     * JSON-encode `$data`, RSA-encrypt it in chunks and base64 the result.
     *
     * @param array<string, mixed> $data
     */
    public function encryptJson(array $data, string $publicKey): string;

    /** RSA-encrypt `$data` in chunks with a PEM or bare base64 public key. */
    public function encryptString(string $data, string $publicKey): string;

    /**
     * Reverse of {@see encryptJson()}.
     *
     * @return array<string, mixed>
     */
    public function decryptJson(string $data, string $privateKey): array;

    /** Reverse of {@see encryptString()}, with a PEM private key. */
    public function decryptString(string $data, string $privateKey): string;

    /** Lowercase hex HMAC-SHA256, like `hash_hmac('sha256', ...)`. */
    public function hmacSha256(string $message, string $key): string;

    /** Lowercase hex HMAC-SHA512, like `hash_hmac('sha512', ...)`. */
    public function hmacSha512(string $message, string $key): string;
}
