import 'package:get/get.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/user_service.dart';

/// Solde wallet client en €, partagé entre Accueil, Profil, Wallet, après recharge Stripe.
class WalletBalanceController extends GetxController {
  final Rxn<double> balanceEu = Rxn<double>();

  final UserService _userService = UserService();

  /// Met à jour depuis l’API (source de vérité).
  Future<void> refreshFromApi() async {
    final token = await AuthService.getToken();
    if (token == null) {
      balanceEu.value = null;
      return;
    }
    try {
      final w = await _userService.getWallet();
      balanceEu.value = (w['balance'] as num?)?.toDouble();
    } catch (_) {
      // garde la dernière valeur connue
    }
  }

  /// Après réponse `confirm-topup` ou tout solde serveur connu.
  void applyServerBalance(dynamic raw) {
    if (raw == null) return;
    if (raw is num) {
      balanceEu.value = raw.toDouble();
    }
  }

  static void notifyTopUpFromApi(dynamic balanceFromConfirmResponse) {
    if (!Get.isRegistered<WalletBalanceController>()) return;
    Get.find<WalletBalanceController>()
        .applyServerBalance(balanceFromConfirmResponse);
  }
}
