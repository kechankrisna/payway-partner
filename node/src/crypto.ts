import {
  constants,
  createHmac,
  createPrivateKey,
  createPublicKey,
  privateDecrypt,
  publicEncrypt,
  type KeyObject,
} from 'node:crypto';

/**
 * RSA and HMAC helpers matching the PHP samples in the PayWay partner docs:
 * `openssl_public_encrypt` / `openssl_private_decrypt` (PKCS#1 v1.5) applied
 * in chunks, and `hash_hmac`. Chunk sizes are derived from the key, so 1024
 * and 2048 bit keys both work.
 *
 * Implement this interface to plug in another crypto backend.
 */
export interface PaywayPartnerCrypto {
  /** JSON-encode `data`, RSA-encrypt it in chunks and base64 the result */
  encryptJson(data: Record<string, unknown>, publicKey: string): string;
  /** RSA-encrypt `data` in chunks with a PEM or bare base64 public key */
  encryptString(data: string, publicKey: string): string;
  /** reverse of {@link encryptJson} */
  decryptJson(data: string, privateKey: string): Record<string, unknown>;
  /** reverse of {@link encryptString}, with a PEM private key */
  decryptString(data: string, privateKey: string): string;
  /** lowercase hex HMAC-SHA256, like PHP `hash_hmac('sha256', ...)` */
  hmacSha256(message: string, key: string): string;
  /** lowercase hex HMAC-SHA512, like PHP `hash_hmac('sha512', ...)` */
  hmacSha512(message: string, key: string): string;
}

/** PKCS#1 v1.5 padding takes 11 bytes of every block */
const PKCS1_PADDING_LENGTH = 11;

/** Default {@link PaywayPartnerCrypto}, backed by `node:crypto`. */
export class NodePaywayPartnerCrypto implements PaywayPartnerCrypto {
  encryptJson(data: Record<string, unknown>, publicKey: string): string {
    return this.encryptString(JSON.stringify(data), publicKey);
  }

  encryptString(data: string, publicKey: string): string {
    const key = parsePublicKey(publicKey);
    const chunkSize = keyLength(key) - PKCS1_PADDING_LENGTH;
    const source = Buffer.from(data, 'utf8');
    const blocks: Buffer[] = [];
    for (let i = 0; i < source.length; i += chunkSize) {
      blocks.push(
        publicEncrypt(
          { key, padding: constants.RSA_PKCS1_PADDING },
          source.subarray(i, i + chunkSize),
        ),
      );
    }
    return Buffer.concat(blocks).toString('base64');
  }

  decryptJson(data: string, privateKey: string): Record<string, unknown> {
    const value: unknown = JSON.parse(this.decryptString(data, privateKey));
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new SyntaxError('decrypted data is not a JSON object');
    }
    return value as Record<string, unknown>;
  }

  decryptString(data: string, privateKey: string): string {
    const key = parsePrivateKey(privateKey);
    const blockSize = keyLength(key);
    const source = Buffer.from(data, 'base64');
    if (source.length === 0 || source.length % blockSize !== 0) {
      throw new RangeError(
        `encrypted data is not a multiple of the ${String(blockSize)} byte key size`,
      );
    }
    const blocks: Buffer[] = [];
    for (let i = 0; i < source.length; i += blockSize) {
      blocks.push(
        privateDecrypt(
          { key, padding: constants.RSA_PKCS1_PADDING },
          source.subarray(i, i + blockSize),
        ),
      );
    }
    // decode utf8 once all blocks are joined, so multi-byte characters
    // (e.g. Khmer) split across blocks stay intact
    return new TextDecoder('utf-8', { fatal: true }).decode(
      Buffer.concat(blocks),
    );
  }

  hmacSha256(message: string, key: string): string {
    return createHmac('sha256', key).update(message, 'utf8').digest('hex');
  }

  hmacSha512(message: string, key: string): string {
    return createHmac('sha512', key).update(message, 'utf8').digest('hex');
  }
}

/**
 * Parses an RSA public key: PEM `PUBLIC KEY` / `RSA PUBLIC KEY`, or a bare
 * base64 SubjectPublicKeyInfo.
 */
export function parsePublicKey(key: string): KeyObject {
  const trimmed = key.trim();
  if (trimmed.includes('-----BEGIN')) return createPublicKey(trimmed);
  const der = Buffer.from(trimmed.replace(/\s/g, ''), 'base64');
  try {
    return createPublicKey({ key: der, format: 'der', type: 'spki' });
  } catch {
    return createPublicKey({ key: der, format: 'der', type: 'pkcs1' });
  }
}

/** Parses a PEM RSA private key: `RSA PRIVATE KEY` or `PRIVATE KEY`. */
export function parsePrivateKey(key: string): KeyObject {
  return createPrivateKey(key.trim());
}

function keyLength(key: KeyObject): number {
  const bits = key.asymmetricKeyDetails?.modulusLength;
  if (bits === undefined) throw new TypeError('not an RSA key');
  return Math.ceil(bits / 8);
}
