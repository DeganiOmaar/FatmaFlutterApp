import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService {
  static const String baseUrl = "http://10.0.2.2:3000"; // IP émulateur

  static Future<void> makePayment({
    required String amount,
    required String projectId,
    required String freelancerId,
  }) async {
    try {
      // 1. Créer l'intention de paiement sur ton serveur
      final response = await http.post(
        Uri.parse('$baseUrl/payments/create-intent'),
        body: {
          'amount': amount,
          'projectId': projectId,
          'freelancerId': freelancerId,
        },
      );

      final jsonResponse = jsonDecode(response.body);
      String clientSecret = jsonResponse['clientSecret'];

      // 2. Initialiser la feuille de paiement (Payment Sheet)
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Lancy Freelance PFE',
          style: ThemeMode.light,
        ),
      );

      // 3. Afficher l'interface Stripe à l'utilisateur
      await Stripe.instance.presentPaymentSheet();

      debugPrint("Paiement Séquestre réussi !");
    } catch (e) {
      debugPrint("Erreur de paiement : $e");
      rethrow;
    }
  }
}