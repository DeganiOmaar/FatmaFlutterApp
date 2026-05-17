import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:pfe/config/api_config.dart';
import 'package:pfe/controllers/wallet_balance_controller.dart';
import 'package:pfe/service/auth_service.dart';

class PaymentService {
  static Future<Map<String, dynamic>?> createPaymentIntent(String projectId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseURL}/payment/create-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'projectId': projectId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint("Erreur PaymentService: $e");
      return null;
    }
  }
  static Future<void> initAndPresentPaymentSheet(String projectId, String token, BuildContext context) async {
    try {
      final data = await createPaymentIntent(projectId, token);

      if (data == null) {
        throw Exception("Impossible de récupérer le secret de paiement");
      }

      if (data['paidFromWallet'] == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Budget confirmé depuis votre wallet — escrow activé ✅"),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      final clientSecret = data['clientSecret'];
      if (clientSecret == null || clientSecret.toString().isEmpty) {
        throw Exception("Secret de paiement manquant");
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret.toString(),
          merchantDisplayName: 'Lancy Freelance',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paiement séquestre réussi ! ✅"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (e is StripeException) {
        debugPrint("Erreur Stripe: ${e.error.localizedMessage}");
      } else {
        debugPrint("Erreur générale: $e");
      }
    }
  }

  /// Recharge le wallet client (montant en euros, carte via Stripe).
  /// Retourne `true` seulement si le serveur a bien crédité le wallet après succès Stripe.
  static Future<bool> topUpWalletEuros(double amountEuros, BuildContext context) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseURL}/payment/wallet/topup-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amountEuros': amountEuros}),
      );

      if (response.statusCode != 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recharge refusée : ${response.body}')),
          );
        }
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final secret = data['clientSecret']?.toString();
      final paymentIntentId = data['paymentIntentId']?.toString();
      if (secret == null || secret.isEmpty) return false;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: secret,
          merchantDisplayName: 'Lancy — Recharge wallet',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (paymentIntentId == null || paymentIntentId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur : identifiant de paiement manquant')),
          );
        }
        return false;
      }

      final confirm = await http.post(
        Uri.parse('${ApiConfig.baseURL}/payment/wallet/confirm-topup'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'paymentIntentId': paymentIntentId}),
      );

      if (confirm.statusCode != 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Paiement OK mais crédit wallet refusé : ${confirm.body}',
              ),
            ),
          );
        }
        return false;
      }

      final confirmData = jsonDecode(confirm.body) as Map<String, dynamic>;
      final balance = confirmData['balance'];
      WalletBalanceController.notifyTopUpFromApi(balance);
      await Get.find<WalletBalanceController>().refreshFromApi();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              balance != null
                  ? 'Wallet mis à jour : $balance € ✅'
                  : 'Wallet rechargé avec succès ✅',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur Stripe : $e')),
        );
      }
      return false;
    }
  }
  Future<bool> releasePayment(String projectId) async {
  try {
    final token = await AuthService.getToken();

    debugPrint("=== RELEASE projectId: $projectId ===");
    debugPrint("=== URL: ${ApiConfig.baseURL}/payment/$projectId/release ===");

    final res = await http.put(
      Uri.parse("${ApiConfig.baseURL}/payment/$projectId/release"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("=== STATUS: ${res.statusCode} ===");
    debugPrint("=== BODY: ${res.body} ===");

    return res.statusCode == 200;
  } catch (e) {
    debugPrint("❌ RELEASE ERROR: $e");
    return false;
  }
}
}
