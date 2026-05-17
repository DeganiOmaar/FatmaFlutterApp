import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../controllers/app_socket_controller.dart';

class AuthService {
  // --- PERSISTENCE ---
static Future<void> _persistAuthPayload(Map<String, dynamic> data) async {
  final token = data["token"];
  if (token is! String || token.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString("token", token);

  final user = data["user"];
  if (user is Map) {
    final u = Map<String, dynamic>.from(user);

    if (u["_id"] != null) {
      await prefs.setString("user_id", u["_id"].toString());
    }

    if (u["email"] != null) {
      await prefs.setString("user_email", u["email"].toString());
    }

    if (u["role"] != null) {
      await prefs.setString("user_role", u["role"].toString());
    }

    if (u["name"] != null) {
      await prefs.setString("user_name", u["name"].toString());
    }
  }
}

  // --- REGISTER ---
  static Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? skills,
    String? bio,
  }) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/register");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email.trim().toLowerCase(),
        "password": password,
        "role": role,
        "skills": skills ?? "",
        "bio": bio ?? "",
      }),
    );

    if (res.statusCode != 201) {
      throw Exception(jsonDecode(res.body)["message"] ?? "Register failed");
    }
  }

  // --- LOGIN ---
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/login");
    final http.Response res;
    try {
      res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email.trim().toLowerCase(),
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'Délai dépassé (15 s) — le serveur ne répond pas.\n'
        '${ApiConfig.unreachableBackendUserHint}',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Erreur réseau (${e.message}).\n${ApiConfig.unreachableBackendUserHint}',
      );
    }

    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data["message"] ?? "Login failed");
    }

    await _persistAuthPayload(data);
    return Map<String, dynamic>.from(data);
  }

  // --- CHECK USER VALIDITY ---
  /// Returns false only when the token is missing or the server explicitly rejects it.
  /// Network/offline errors return true so reopening the app does not force logout.
  static Future<bool> checkUserExists() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final url = Uri.parse("${ApiConfig.baseURL}/auth/profile");
      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);
          if (body is Map) {
            await _persistAuthPayload({
              "token": token,
              "user": Map<String, dynamic>.from(body),
            });
          }
        } catch (_) {}
        return true;
      }
      if (res.statusCode == 401 ||
          res.statusCode == 403 ||
          res.statusCode == 404) {
        return false;
      }
      return true;
    } on TimeoutException {
      return true;
    } on http.ClientException {
      return true;
    } catch (_) {
      return true;
    }
  }

  // --- GETTERS ---
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_email");
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_role");
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_name");
  }

  static void _disposeAppSocketIfAny() {
    try {
      if (Get.isRegistered<AppSocketController>()) {
        Get.find<AppSocketController>().disconnectLogout();
      }
    } catch (_) {}
  }

  // --- LOGOUT & CLEANUP ---
  static Future<void> removeToken() async {
    _disposeAppSocketIfAny();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> logout() async {
    await removeToken();
  }

  // --- OTP & PASSWORD RESET ---
  static Future<void> forgotPassword({required String email}) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/forgot-password");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    if (res.statusCode != 200) throw Exception("Failed to send OTP");
  }

  static Future<void> verifyOTP({
    required String email,
    required String code,
    required bool isFromRegister,
  }) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/verify-otp");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "code": code,
        "isFromRegister": isFromRegister,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(data["message"] ?? "OTP failed");
    if (data["token"] != null) await _persistAuthPayload(data);
  }
  // --- RESET PASSWORD ---
  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final url = Uri.parse("${ApiConfig.baseURL}/auth/reset-password");
    
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email.trim().toLowerCase(),
        "code": code,
        "newPassword": newPassword,
        "confirmPassword": confirmPassword,
      }),
    );

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data["message"] ?? "Password reset failed");
    }
  }
  static Future<void> changePassword({
  required String email,
  required String oldPassword,
  required String newPassword,
}) async {
  final response = await http.put(
    Uri.parse("${ApiConfig.origin}/api/users/change-password/$email"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "oldPassword": oldPassword,
      "newPassword": newPassword,
    }),
  );

  if (response.statusCode != 200) {
    final data = jsonDecode(response.body);
    throw Exception(data['message'] ?? "Erreur serveur");
  }
}

static Future<String?> getUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString("user_id");
}
}