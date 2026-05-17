import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:pfe/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 25);

  static Map<String, dynamic>? _decodeJsonMap(String body) {
    final t = body.trim();
    if (t.isEmpty) return null;
    try {
      final v = jsonDecode(t);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
static Future<void> removeToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear(); 
}
  static String _bodyPreview(String body, [int max = 180]) {
    final t = body.trim();
    if (t.isEmpty) return '(vide)';
    return t.length > max ? '${t.substring(0, max)}…' : t;
  }

  static Exception _nonJsonResponse(http.Response res, String action) {
    final code = res.statusCode;
    return Exception(
      '$action : réponse HTTP $code sans JSON valide. '
      'Souvent un autre service occupe le port (sur Mac, AirPlay utilise le 5000). '
      'Backend attendu sur le port ${ApiConfig.apiPort}. Aperçu : ${_bodyPreview(res.body)}',
    );
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/register");

    try {
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(data),
          )
          .timeout(_requestTimeout);

      if (res.statusCode == 201) {
        final map = _decodeJsonMap(res.body);
        if (map != null) return map;
        throw Exception('Inscription : succès HTTP 201 mais corps JSON invalide ou vide.');
      }

      final errMap = _decodeJsonMap(res.body);
      if (errMap != null) {
        throw Exception(errMap['message']?.toString() ?? "Erreur lors de l'inscription");
      }
      throw _nonJsonResponse(res, 'Inscription');
    } on http.ClientException {
      throw Exception(
        "Impossible de se connecter au serveur 🌐 (vérifie que Node écoute sur le port ${ApiConfig.apiPort})",
      );
    } on TimeoutException {
      throw Exception("Le serveur ne répond pas à temps (timeout) — vérifie le backend et le réseau");
    }
  }

  static Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String code,
    required bool isFromRegister,
  }) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/verify-otp");

    try {
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email.trim().toLowerCase(),
              "code": code,
              "isFromRegister": isFromRegister,
            }),
          )
          .timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final map = _decodeJsonMap(res.body);
        if (map != null) return map;
        throw Exception('OTP : réponse HTTP 200 sans JSON valide.');
      }

      final errMap = _decodeJsonMap(res.body);
      if (errMap != null) {
        throw Exception(errMap['message']?.toString() ?? "Code invalide");
      }
      throw _nonJsonResponse(res, 'Vérification OTP');
    } on http.ClientException {
      throw Exception("Impossible de se connecter au serveur 🌐");
    } on TimeoutException {
      throw Exception("Le serveur ne répond pas à temps (timeout)");
    }
  }

  static Future<void> forgotPassword(String email) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/forgot-password");

    try {
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email}),
          )
          .timeout(_requestTimeout);

      if (res.statusCode == 200) return;

      final errMap = _decodeJsonMap(res.body);
      if (errMap != null) {
        throw Exception(errMap['message']?.toString() ?? "Erreur d'envoi");
      }
      throw _nonJsonResponse(res, 'Mot de passe oublié');
    } on http.ClientException {
      throw Exception("Serveur injoignable");
    } on TimeoutException {
      throw Exception("Serveur injoignable (timeout)");
    }
  }
  String? validatePassword(String v) {
  // Regex pour Flutter
  RegExp regex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)(?=.*[!@#$%^&*])[A-Za-z\d!@#$%^&*]{8,}$');
  
  if (v.isEmpty) {
    return 'Veuillez entrer un mot de passe';
  } else if (!regex.hasMatch(v)) {
    return 'Lettres, chiffres et symboles requis (min. 8)';
  }
  return null;
}
}
