<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Crypto;

/**
 * Default {@see PaywayPartnerCrypto}, backed by ext-openssl. Chunk sizes are
 * derived from the key, so 1024 and 2048 bit keys both work.
 */
final class OpenSslCrypto implements PaywayPartnerCrypto
{
    /** PKCS#1 v1.5 padding takes 11 bytes of every block */
    private const int PKCS1_PADDING_LENGTH = 11;

    public function encryptJson(array $data, string $publicKey): string
    {
        return $this->encryptString(
            json_encode($data, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            $publicKey,
        );
    }

    public function encryptString(string $data, string $publicKey): string
    {
        $key = self::parsePublicKey($publicKey);
        $chunkSize = max(1, self::keyLength($key) - self::PKCS1_PADDING_LENGTH);
        $output = '';
        foreach ($data === '' ? [] : str_split($data, $chunkSize) as $chunk) {
            if (!openssl_public_encrypt($chunk, $encrypted, $key, OPENSSL_PKCS1_PADDING) || !\is_string($encrypted)) {
                throw new \RuntimeException('RSA encryption failed: ' . self::lastError());
            }
            $output .= $encrypted;
        }

        return base64_encode($output);
    }

    public function decryptJson(string $data, #[\SensitiveParameter] string $privateKey): array
    {
        $value = json_decode($this->decryptString($data, $privateKey), true, 512, JSON_THROW_ON_ERROR);
        if (!\is_array($value) || array_is_list($value) && $value !== []) {
            throw new \UnexpectedValueException('decrypted data is not a JSON object');
        }

        /** @var array<string, mixed> $value */
        return $value;
    }

    public function decryptString(string $data, #[\SensitiveParameter] string $privateKey): string
    {
        $key = openssl_pkey_get_private($privateKey);
        if ($key === false) {
            throw new \InvalidArgumentException('Invalid RSA private key: ' . self::lastError());
        }
        $blockSize = max(1, self::keyLength($key));
        $source = base64_decode($data, true);
        if ($source === false || $source === '' || \strlen($source) % $blockSize !== 0) {
            throw new \UnexpectedValueException(
                "encrypted data is not a multiple of the {$blockSize} byte key size",
            );
        }

        // join all blocks before checking utf8, so multi-byte characters
        // (e.g. Khmer) split across blocks stay intact
        $output = '';
        foreach (str_split($source, $blockSize) as $block) {
            if (!openssl_private_decrypt($block, $decrypted, $key, OPENSSL_PKCS1_PADDING) || !\is_string($decrypted)) {
                throw new \UnexpectedValueException('RSA decryption failed: ' . self::lastError());
            }
            $output .= $decrypted;
        }
        if (preg_match('//u', $output) !== 1) {
            throw new \UnexpectedValueException('decrypted data is not UTF-8');
        }

        return $output;
    }

    public function hmacSha256(string $message, #[\SensitiveParameter] string $key): string
    {
        return hash_hmac('sha256', $message, $key);
    }

    public function hmacSha512(string $message, #[\SensitiveParameter] string $key): string
    {
        return hash_hmac('sha512', $message, $key);
    }

    /**
     * Parses an RSA public key: PEM `PUBLIC KEY` / `RSA PUBLIC KEY`, or a
     * bare base64 SubjectPublicKeyInfo.
     */
    public static function parsePublicKey(string $key): \OpenSSLAsymmetricKey
    {
        $pem = trim($key);
        if (!str_contains($pem, '-----BEGIN')) {
            $body = preg_replace('/\s+/', '', $pem) ?? '';
            $pem = "-----BEGIN PUBLIC KEY-----\n" . chunk_split($body, 64, "\n") . '-----END PUBLIC KEY-----';
        }
        $parsed = openssl_pkey_get_public($pem);
        if ($parsed === false) {
            throw new \InvalidArgumentException('Invalid RSA public key: ' . self::lastError());
        }

        return $parsed;
    }

    private static function keyLength(\OpenSSLAsymmetricKey $key): int
    {
        $details = openssl_pkey_get_details($key);
        if ($details === false || ($details['type'] ?? null) !== OPENSSL_KEYTYPE_RSA || !\is_int($details['bits'] ?? null)) {
            throw new \InvalidArgumentException('not an RSA key');
        }

        return intdiv($details['bits'] + 7, 8);
    }

    private static function lastError(): string
    {
        $messages = [];
        while (($message = openssl_error_string()) !== false) {
            $messages[] = $message;
        }

        return implode('; ', $messages);
    }
}
