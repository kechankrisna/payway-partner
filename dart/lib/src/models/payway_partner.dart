import 'package:json_annotation/json_annotation.dart';

part 'payway_partner.g.dart';

/// Partner credentials provided by ABA Bank.
///
/// ```dart
/// final partner = PaywayPartner(
///   partnerName: 'your partner name',
///   partnerID: 'your partner id',
///   partnerKey: 'your partner key',
///   partnerPrivateKey: '-----BEGIN RSA PRIVATE KEY-----...',
///   partnerPublicKey: '-----BEGIN PUBLIC KEY-----...',
///   partnerReferer: 'https://your-whitelisted-domain.com',
///   baseApiUrl: PaywayPartner.sandboxBaseUrl,
/// );
/// ```
///
/// [fromJson] / [toJson] use the field names as keys, for loading this
/// configuration from your own secret store. [toJson] contains the secrets.
@JsonSerializable()
class PaywayPartner {
  /// PayWay sandbox (testing) environment
  static const String sandboxBaseUrl = 'https://sandbox.payway.com.kh';

  /// PayWay production (live) environment
  static const String productionBaseUrl = 'https://merchant.payway.com.kh';

  /// your partner name registered with ABA
  final String partnerName;

  /// encrypted partner id provided by ABA
  final String partnerID;

  /// HMAC key used to sign every request (secret)
  final String partnerKey;

  /// PEM private key, decrypts PayWay data (secret)
  final String partnerPrivateKey;

  /// PEM public key, encrypts `request_data`
  final String partnerPublicKey;

  /// domain whitelisted by ABA, sent as the `Referer` header
  final String partnerReferer;

  /// [sandboxBaseUrl] or [productionBaseUrl]
  final String baseApiUrl;

  /// Creates a [PaywayPartner].
  const PaywayPartner({
    required this.partnerName,
    required this.partnerID,
    required this.partnerKey,
    required this.partnerPrivateKey,
    required this.partnerPublicKey,
    required this.partnerReferer,
    required this.baseApiUrl,
  });

  /// Reads a configuration written by [toJson].
  factory PaywayPartner.fromJson(Map<String, dynamic> json) =>
      _$PaywayPartnerFromJson(json);

  /// JSON keyed by field name; contains the secrets.
  Map<String, dynamic> toJson() => _$PaywayPartnerToJson(this);

  /// Returns a copy with the given fields replaced.
  PaywayPartner copyWith({
    String? partnerName,
    String? partnerID,
    String? partnerKey,
    String? partnerPrivateKey,
    String? partnerPublicKey,
    String? partnerReferer,
    String? baseApiUrl,
  }) {
    return PaywayPartner(
      partnerName: partnerName ?? this.partnerName,
      partnerID: partnerID ?? this.partnerID,
      partnerKey: partnerKey ?? this.partnerKey,
      partnerPrivateKey: partnerPrivateKey ?? this.partnerPrivateKey,
      partnerPublicKey: partnerPublicKey ?? this.partnerPublicKey,
      partnerReferer: partnerReferer ?? this.partnerReferer,
      baseApiUrl: baseApiUrl ?? this.baseApiUrl,
    );
  }

  /// partnerKey and partnerPrivateKey are secrets, keep them out of logs
  @override
  String toString() =>
      'PaywayPartner(partnerName: $partnerName, partnerID: $partnerID, partnerKey: ***, partnerPrivateKey: ***, partnerReferer: $partnerReferer, baseApiUrl: $baseApiUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywayPartner &&
          other.partnerName == partnerName &&
          other.partnerID == partnerID &&
          other.partnerKey == partnerKey &&
          other.partnerPrivateKey == partnerPrivateKey &&
          other.partnerPublicKey == partnerPublicKey &&
          other.partnerReferer == partnerReferer &&
          other.baseApiUrl == baseApiUrl;

  @override
  int get hashCode => Object.hash(
    partnerName,
    partnerID,
    partnerKey,
    partnerPrivateKey,
    partnerPublicKey,
    partnerReferer,
    baseApiUrl,
  );
}
