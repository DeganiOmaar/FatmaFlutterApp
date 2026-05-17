import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';

/// Applique la clé publique Stripe **alignée sur le backend** (évite l’erreur
/// « client_secret does not match … publishable key » quand .env et l’app divergent).
class StripeKeys {
  static Future<void> ensureApplied() async {
    try {
      final uri =
          Uri.parse('${ApiConfig.baseURL}/config/stripe-publishable-key');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pk = data['publishableKey'] as String?;
        if (pk != null && pk.isNotEmpty) {
          Stripe.publishableKey = pk.trim();
          if (kDebugMode) {
            debugPrint(
              '✅ Stripe publishable key chargée depuis le backend (prefix: ${pk.substring(0, pk.length >= 12 ? 12 : pk.length)}…)',
            );
          }
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Impossible de charger la clé Stripe depuis l’API : $e');
      }
    }

    Stripe.publishableKey = ApiConfig.stripePublishableKeyFallback;
    if (kDebugMode) {
      debugPrint(
        '⚠️ Utilisation du fallback ApiConfig.stripePublishableKeyFallback (vérifie qu’il correspond à STRIPE_SECRET_KEY).',
      );
    }
  }
}
