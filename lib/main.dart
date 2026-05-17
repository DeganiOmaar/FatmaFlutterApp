import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pfe/config/api_config.dart';
import 'package:pfe/config/stripe_keys.dart';
import 'package:pfe/controllers/app_socket_controller.dart';
import 'package:pfe/controllers/wallet_balance_controller.dart';
import 'package:pfe/screens/main_screen.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/screens/splash/logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await ApiConfig.ensureInitialized();
  await StripeKeys.ensureApplied();
  final String? token = await AuthService.getToken();

  Get.put(WalletBalanceController(), permanent: true);
  Get.put(AppSocketController(), permanent: true);
  if (token != null && token.isNotEmpty) {
    await Get.find<WalletBalanceController>().refreshFromApi();
  }

  if (kDebugMode) {
    debugPrint("--- DÉMARRAGE APP : Token trouvé = $token ---");
  }

  runApp(MyApp(hasSession: token != null && token.isNotEmpty));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await ApiConfig.applyAndroidGradleHostAfterFirstFrameIfNeeded();
  });
}


class MyApp extends StatefulWidget {
  final bool hasSession;
  const MyApp({super.key, required this.hasSession});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _backendHintQueued = false;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Lancy PFE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) {
        if (ApiConfig.needsPhysicalDeviceBackendHint &&
            !_backendHintQueued &&
            child != null) {
          _backendHintQueued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future<void>.delayed(const Duration(milliseconds: 600), () {
              if (!context.mounted) return;
              if (!ApiConfig.needsPhysicalDeviceBackendHint) return;
              showDialog<void>(
                context: context,
                barrierDismissible: true,
                builder: (ctx) => AlertDialog(
                  title: const Text('Connexion au serveur'),
                  content: const Text(
                    'Sur un téléphone réel, 127.0.0.1 désigne le téléphone, pas ton PC.\n\n'
                    '• Android : après un rebuild `flutter run`, l’IP de ton PC (même Wi‑Fi) peut être injectée automatiquement.\n\n'
                    '• Sinon édite assets/backend_config.json (ex. "apiOrigin": "http://192.168.1.10:5001") puis redémarre l’app.\n\n'
                    '• Ou : flutter run --dart-define=LANCY_API_BASE_URL=http://IP_DE_TON_PC:5001\n\n'
                    '• Ou (Android USB) : adb reverse tcp:5001 tcp:5001 puis "apiOrigin" avec 127.0.0.1.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            });
          });
        }
        return child ?? const SizedBox.shrink();
      },
      // Ken famma session, n'addiweh lel Launcher bch nthabtou el validity
      home: widget.hasSession ? const _SessionLauncher() : const SplashPage(),
    );
  }
}


class _SessionLauncher extends StatefulWidget {
  const _SessionLauncher();
  @override
  State<_SessionLauncher> createState() => _SessionLauncherState();
}

class _SessionLauncherState extends State<_SessionLauncher> {
  @override
  void initState() {
    super.initState();
    _openHome();
  }

  Future<void> _openHome() async {
    try {
      // 1. On ajoute un timeout de 5 secondes max
      // Si le serveur ne répond pas après 5s, on considère que le check a échoué
      final bool isUserStillValid = await AuthService.checkUserExists().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (!isUserStillValid) {
        await AuthService.removeToken();
        if (!mounted) return;
        Get.offAll(
          () => const SplashPage(),
        ); // On utilise Get pour nettoyer la pile
        return;
      }

      // 2. Récupération des infos locales (stockées dans SharedPreferences/SecureStorage)
      final email = await AuthService.getUserEmail();
      final role = await AuthService.getUserRole();
      final name = await AuthService.getUserName();
  
      if (!mounted) return;

      // 3. Navigation vers HomeScreen
      Get.offAll(() => MainScreen(email: email ?? '', role: role ?? 'client', name: name));
    } catch (e) {
      debugPrint("Erreur réseau ou session : $e");
      // En cas d'erreur (serveur éteint), on redirige vers le Splash/Login
      if (!mounted) return;
      Get.offAll(() => const SplashPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pinkAccent),
            SizedBox(height: 20),
            Text(
              "Vérification de la session...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
