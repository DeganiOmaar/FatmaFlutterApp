import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;

import 'guess_backend_host_stub.dart'
    if (dart.library.io) 'guess_backend_host_io.dart' as nw;

/// Central API configuration — avoids hardcoding a fixed LAN IP in Dart.
///
/// **On a REAL phone**, `localhost` / `127.0.0.1` points to the phone, not your PC.
/// Use one of:
///
/// 1. **File:** edit `assets/backend_config.json`, set `"apiOrigin": "http://VOTRE_IP_PC:5001"`
///    (same Wi‑Fi). Hot restart after saving.
///
/// 2. **Run:** `flutter run --dart-define=LANCY_API_BASE_URL=http://VOTRE_IP_PC:5001`
///
/// 3. **USB Android:** optional `adb reverse tcp:5001 tcp:5001` then `"apiOrigin": "http://127.0.0.1:5001"`
///
/// 4. **Android debug build:** Gradle injects your PC’s LAN IPv4 when you compile (`flutter run`). Same Wi‑Fi as the phone. Rebuild after changing network; releases use dart-define / assets only.
///
/// Emulators without config: Android → `10.0.2.2`, iOS simulator → `127.0.0.1`.
class ApiConfig {
  /// Backend origin **without** trailing slash / `/api`, e.g. `http://10.0.0.5:5001`.
  static const String apiBaseUrlFromEnv = String.fromEnvironment(
    'LANCY_API_BASE_URL',
    defaultValue: '',
  );

  /// Used only when [apiBaseUrlFromEnv] is empty.
  static const String apiHostFromEnv = String.fromEnvironment(
    'LANCY_API_HOST',
    defaultValue: '',
  );

  /// Must match LANCY-Backend `PORT` in `.env`.
  static const int apiPort = int.fromEnvironment(
    'LANCY_API_PORT',
    defaultValue: 5001,
  );

  /// True → app shows a hint dialog (real device but no reachable PC URL configured).
  static bool needsPhysicalDeviceBackendHint = false;

  static String _origin = 'http://127.0.0.1:5001';
  static bool _ready = false;

  static String _stripTrailingApi(String s) {
    var t = s.trim();
    if (t.endsWith('/')) t = t.substring(0, t.length - 1);
    if (t.endsWith('/api')) t = t.substring(0, t.length - 4);
    return t;
  }

  static Future<String?> _androidDebugLanHostFromGradle() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      const ch = MethodChannel('dev.lancy/config');
      final dynamic raw = await ch.invokeMethod<String>('debugLanHost');
      final String? host = raw is String ? raw : null;
      if (host == null || host.trim().isEmpty) return null;
      return host.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _loadApiOriginFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/backend_config.json');
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final o = map['apiOrigin'];
      if (o is! String) return null;
      final t = o.trim();
      return t.isEmpty ? null : t;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('assets/backend_config.json: $e\n$st');
      }
      return null;
    }
  }

  /// Initialise HTTP/Socket origin (call from `main()` after [WidgetsFlutterBinding.ensureInitialized]).
  static Future<void> ensureInitialized() async {
    if (_ready) return;
    needsPhysicalDeviceBackendHint = false;

    if (apiBaseUrlFromEnv.isNotEmpty) {
      _origin = _stripTrailingApi(apiBaseUrlFromEnv);
    } else if (apiHostFromEnv.isNotEmpty) {
      _origin = 'http://${apiHostFromEnv.trim()}:$apiPort';
    } else {
      final fromJson = await _loadApiOriginFromAsset();
      if (fromJson != null) {
        _origin = _stripTrailingApi(fromJson);
      } else if (kIsWeb) {
        _origin = 'http://localhost:$apiPort';
      } else {
        final plugin = DeviceInfoPlugin();
        var host = '127.0.0.1';
        var isPhysicalMobile = false;
        try {
          if (defaultTargetPlatform == TargetPlatform.android) {
            final info = await plugin.androidInfo;
            isPhysicalMobile = info.isPhysicalDevice;
            host = info.isPhysicalDevice ? '127.0.0.1' : '10.0.2.2';
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            final info = await plugin.iosInfo;
            isPhysicalMobile = info.isPhysicalDevice;
            host = '127.0.0.1';
          }
        } catch (_) {}

        if (isPhysicalMobile && host == '127.0.0.1') {
          final guessed = await nw.guessBackendHostFromInterfaces();
          if (guessed != null) {
            host = guessed;
            if (kDebugMode) {
              debugPrint(
                '📶 Adresse backend déduite (partage connexion / point d’accès) : $host',
              );
            }
          } else {
            final gradleLan = await _androidDebugLanHostFromGradle();
            if (gradleLan != null && gradleLan.isNotEmpty) {
              host = gradleLan;
              if (kDebugMode) {
                debugPrint(
                  '🔧 IP du PC (build Android debug / Gradle) : $host',
                );
              }
            } else {
              needsPhysicalDeviceBackendHint = true;
              if (kDebugMode) {
                debugPrint(
                  '⚠️ Téléphone physique : configure apiOrigin dans assets/backend_config.json, '
                  'ou reconstruis en debug sur le même Wi‑Fi, ou LANCY_API_BASE_URL en dart-define.',
                );
              }
            }
          }
        }

        _origin = 'http://$host:$apiPort';
      }
    }

    _ready = true;
    if (kDebugMode) {
      debugPrint('🚀 Lancy API origin: $_origin');
      debugPrint('🔗 REST base: $baseURL');
    }
  }

  /// Runs after `runApp` when the Flutter engine is fully wired (MethodChannel sometimes fails earlier in `main()`).
  static Future<void> applyAndroidGradleHostAfterFirstFrameIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (apiBaseUrlFromEnv.isNotEmpty || apiHostFromEnv.isNotEmpty) return;
    final fromAsset = await _loadApiOriginFromAsset();
    if (fromAsset != null && fromAsset.trim().isNotEmpty) return;

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (!info.isPhysicalDevice) return;
    } catch (_) {
      return;
    }

    if (!_looksLikeUnreachablePhysicalBackend()) return;

    final h = await _androidDebugLanHostFromGradle();
    if (h == null || h.isEmpty) return;

    _origin = 'http://$h:$apiPort';
    needsPhysicalDeviceBackendHint = false;
    if (kDebugMode) {
      debugPrint('🔧 Backend corrigé (Gradle, après premier frame) : $_origin');
    }
  }

  /// Physical phone wrongly targeting loopback → nothing listens on-device.
  static bool _looksLikeUnreachablePhysicalBackend() =>
      _origin.startsWith('http://127.0.0.1:');

  /// Shown when login/API calls hit a network timeout — usually wrong IP or firewall on the PC.
  static String get unreachableBackendUserHint =>
      'Pas de réponse depuis $_origin · même Wi‑Fi que le PC · backend actif '
      '(port $apiPort) · pare‑feu ouvrant ce port · si besoin mets ton IP dans '
      'assets/backend_config.json puis redémarrage.';

  /// Secours si l’API ne répond pas ; doit être la **même** paire que `STRIPE_PUBLISHABLE_KEY` dans `.env`.
  static const String stripePublishableKeyFallback =
      "pk_test_51RC0sfPjBWqUfqpFgpwv30qIv2nlhJQ0QcyKydbPMJlMXC4be1KW7qw0CDJok56oSFg5ESACmN7s7plFXfM9vcKt00zNFP42ff";

  static String get baseURL => '$_origin/api';

  static String get socketUrl => _origin;

  static String get origin => _origin;
}
