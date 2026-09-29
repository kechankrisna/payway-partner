import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// RSA and HMAC helpers matching the PHP samples in the PayWay partner docs:
/// `openssl_public_encrypt` / `openssl_private_decrypt` (PKCS#1 v1.5) applied
/// in chunks, and `hash_hmac`.
///
/// Chunk sizes are derived from the key, so 1024 and 2048 bit keys both work.
/// Implement this class to plug in another crypto backend.
class PaywayPartnerCrypto {
  /// Creates the default implementation, backed by pointycastle.
  const PaywayPartnerCrypto();

  /// JSON-encode [data], RSA-encrypt it in chunks and base64 the result
  String encryptJson(Map<String, dynamic> data, String publicKey) =>
      encryptString(json.encode(data), publicKey);

  /// RSA-encrypt [data] in chunks with [publicKey] (PEM or bare base64) and
  /// base64 the result
  String encryptString(String data, String publicKey) {
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(parsePublicKey(publicKey)));
    // PKCS#1 v1.5 padding takes 11 bytes of every key-size block
    final chunkSize = cipher.inputBlockSize;

    final source = utf8.encode(data);
    final output = BytesBuilder(copy: false);
    for (var i = 0; i < source.length; i += chunkSize) {
      output.add(
        cipher.process(
          Uint8List.sublistView(source, i, min(i + chunkSize, source.length)),
        ),
      );
    }
    return base64.encode(output.toBytes());
  }

  /// reverse of [encryptJson]
  Map<String, dynamic> decryptJson(String data, String privateKey) =>
      json.decode(decryptString(data, privateKey)) as Map<String, dynamic>;

  /// reverse of [encryptString], with a PEM [privateKey]
  String decryptString(String data, String privateKey) {
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(
        false,
        PrivateKeyParameter<RSAPrivateKey>(parsePrivateKey(privateKey)),
      );
    final blockSize = cipher.inputBlockSize;

    final source = base64.decode(data);
    if (source.length % blockSize != 0) {
      throw FormatException(
        'encrypted data is not a multiple of the $blockSize byte key size',
      );
    }
    // join all blocks before decoding utf8, so multi-byte characters
    // (e.g. Khmer) split across blocks stay intact
    final output = BytesBuilder(copy: false);
    for (var i = 0; i < source.length; i += blockSize) {
      output.add(
        cipher.process(Uint8List.sublistView(source, i, i + blockSize)),
      );
    }
    return utf8.decode(output.toBytes());
  }

  /// lowercase hex HMAC-SHA256, like PHP `hash_hmac('sha256', ...)`
  String hmacSha256(String message, String key) => crypto.Hmac(
    crypto.sha256,
    utf8.encode(key),
  ).convert(utf8.encode(message)).toString();

  /// lowercase hex HMAC-SHA512, like PHP `hash_hmac('sha512', ...)`
  String hmacSha512(String message, String key) => crypto.Hmac(
    crypto.sha512,
    utf8.encode(key),
  ).convert(utf8.encode(message)).toString();

  /// Parses an RSA public key: PEM `PUBLIC KEY` (X.509 SubjectPublicKeyInfo),
  /// PEM `RSA PUBLIC KEY` (PKCS#1), or either as bare base64.
  static RSAPublicKey parsePublicKey(String key) {
    try {
      var sequence = _sequence(_derBytes(key));
      if (sequence.elements!.first is! ASN1Integer) {
        // SubjectPublicKeyInfo: algorithm, BIT STRING wrapping PKCS#1
        final bits = sequence.elements![1] as ASN1BitString;
        sequence = _sequence(Uint8List.fromList(bits.stringValues!));
      }
      final values = _integers(sequence);
      return RSAPublicKey(values[0], values[1]);
    } catch (error) {
      throw FormatException('Invalid RSA public key: $error');
    }
  }

  /// Parses a PEM RSA private key: `RSA PRIVATE KEY` (PKCS#1) or
  /// `PRIVATE KEY` (PKCS#8).
  static RSAPrivateKey parsePrivateKey(String key) {
    try {
      var sequence = _sequence(_derBytes(key));
      final elements = sequence.elements!;
      if (elements.length == 3 && elements[2] is ASN1OctetString) {
        // PKCS#8: version, algorithm, OCTET STRING wrapping PKCS#1
        sequence = _sequence((elements[2] as ASN1OctetString).octets!);
      }
      // PKCS#1: version, n, e, d, p, q, dp, dq, qInv
      final values = _integers(sequence);
      return RSAPrivateKey(values[1], values[3], values[4], values[5]);
    } catch (error) {
      throw FormatException('Invalid RSA private key: $error');
    }
  }

  /// DER bytes of a PEM block, or of bare base64
  static Uint8List _derBytes(String key) {
    final body = key
        .split('\n')
        .where((line) => !line.trim().startsWith('-----'))
        .join()
        .replaceAll(RegExp(r'\s'), '');
    return base64.decode(body);
  }

  static ASN1Sequence _sequence(Uint8List bytes) =>
      ASN1Parser(bytes).nextObject() as ASN1Sequence;

  static List<BigInt> _integers(ASN1Sequence sequence) => [
    for (final element in sequence.elements!) (element as ASN1Integer).integer!,
  ];
}
