// Demo only: this app embeds partner keys to call the PayWay sandbox directly.
// In production, run PaywayPartnerService on your server and never ship
// partnerKey or partnerPrivateKey inside an app.
//
// Run with the repository's sandbox .env:
//   flutter run --dart-define-from-file=../../.env
import 'dart:convert';

import 'package:payway_partner/payway_partner.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

// values from --dart-define-from-file; empty when not provided
const _apiUrl = String.fromEnvironment('ABA_PARTNER_API_URL');
const _partnerName = String.fromEnvironment('ABA_PARTNER_NAME');
const _partnerId = String.fromEnvironment('ABA_PARTNER_ID');
const _partnerKey = String.fromEnvironment('ABA_PARTNER_KEY');
const _privateKey = String.fromEnvironment('ABA_PARTNER_PRIVATE_KEY');
const _publicKey = String.fromEnvironment('ABA_PARTNER_PUBLIC_KEY');
const _referer = String.fromEnvironment('ABA_PARTNER_REFERER_DOMAIN');
const _merchantKey = String.fromEnvironment('ABA_MERCHANT_KEY');
const _merchantCurrency =
    String.fromEnvironment('ABA_MERCHANT_CURRENCY', defaultValue: 'USD');
const _merchantPublicKey = String.fromEnvironment('ABA_MERCHANT_PUBLIC_KEY');

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayWay Partner Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'PayWay Partner Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const registerRef = "ke_chankrisna";

  late final PaywayPartnerService service;

  @override
  void initState() {
    super.initState();
    String pem(String base64Pem) => utf8.decode(base64.decode(base64Pem));

    service = PaywayPartnerService(
      partner: PaywayPartner(
        partnerName: _partnerName,
        partnerID: _partnerId,
        partnerKey: _partnerKey,
        partnerPrivateKey: pem(_privateKey),
        partnerPublicKey: pem(_publicKey),
        partnerReferer: _referer,
        baseApiUrl: _apiUrl.isEmpty ? PaywayPartner.sandboxBaseUrl : _apiUrl,
      ),
      logger: debugPrint,
    );
  }

  Future<void> registerMerchant() async {
    try {
      final response = await service.registerMerchant(
        merchant: const PaywayPartnerRegisterMerchant(
          pushbackUrl: 'https://stage.mylekha.app/',
          redirectUrl: 'https://stage.mylekha.app/',
          registerRef: registerRef,
          currency: 'USD',
        ),
      );
      // on success, open response.url for the merchant to finish registration
      debugPrint('$response');
    } on PaywayPartnerException catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> checkMerchant() async {
    try {
      final response = await service.checkMerchant(
        merchant: const PaywayPartnerCheckMerchant(registerRef: registerRef),
      );
      if (response.isSuccess) {
        debugPrint('${service.decryptMerchantCredential(response.data)}');
      } else {
        debugPrint('${response.status}');
      }
    } on PaywayPartnerException catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> getMcInfo() async {
    try {
      final response = await service.getMcInfo(
        merchant: const PaywayPartnerGetMcInfoMerchant(
          merchantKey: _merchantKey,
          currency: _merchantCurrency,
          publicKey: _merchantPublicKey,
        ),
      );
      if (response.isSuccess) {
        debugPrint('${service.decryptMcInfo(response.data)}');
      } else {
        debugPrint('${response.status}');
      }
    } on PaywayPartnerException catch (e) {
      debugPrint('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
                onPressed: registerMerchant,
                child: const Text("register merchant")),
            TextButton(
                onPressed: checkMerchant, child: const Text("check merchant")),
            TextButton(onPressed: getMcInfo, child: const Text("get mc info")),
          ],
        ),
      ),
    );
  }
}
