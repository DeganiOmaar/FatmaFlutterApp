import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pfe/Model/User.dart';
import 'package:pfe/config/api_config.dart';
import 'package:http_parser/http_parser.dart';
import 'package:pfe/service/auth_service.dart';

class UserService {

  Future<UserModel> fetchProfile(String email) async {
    final safe = Uri.encodeComponent(email.trim());
    final response = await http.get(
      // ✅ baseURL = http://IP:5001/api → donc /users/profile/$safe
      Uri.parse('${ApiConfig.baseURL}/users/profile/$safe'),
    );

    debugPrint("📡 fetchProfile status: ${response.statusCode}");
    debugPrint("📡 fetchProfile body: ${response.body}");

    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Erreur lors du chargement du profil');
    }
  }

  Future<({bool ok, String? error})> updateProfile({
    required String email,
    required String name,
    required String bio,
  }) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        return (ok: false, error: "Le nom ne peut pas être vide");
      }

      final safe = Uri.encodeComponent(email.trim().toLowerCase());
      final token = await AuthService.getToken();
      final headers = <String, String>{
        "Content-Type": "application/json",
      };
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }

      final response = await http.put(
        Uri.parse("${ApiConfig.baseURL}/users/update/$safe"),
        headers: headers,
        body: jsonEncode({
          "name": trimmedName,
          "bio": bio.trim(),
        }),
      );

      debugPrint("📡 updateProfile status: ${response.statusCode}");
      debugPrint("📡 updateProfile body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data["user"] != null) {
            return (ok: true, error: null);
          }
        } catch (_) {}
        return (ok: false, error: "Réponse serveur invalide");
      }

      String? msg;
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data["message"] != null) {
          msg = data["message"].toString();
        }
      } catch (_) {}
      return (
        ok: false,
        error: msg ?? "Échec de la mise à jour (${response.statusCode})",
      );
    } catch (e) {
      debugPrint("❌ Update error: $e");
      return (ok: false, error: "Pas de connexion au serveur");
    }
  }
  

Future<String?> uploadAvatar({
  required String email,
  required String filePath,
}) async {
  try {
    final safe = Uri.encodeComponent(email.trim());
    final uri = Uri.parse("${ApiConfig.baseURL}/users/upload-avatar/$safe");

    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath(
      "avatar",
      filePath,
      contentType: MediaType("image", "jpeg"),
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);

    debugPrint("📡 Upload status: ${response.statusCode}");
    debugPrint("📡 Avatar URL: ${data['avatarUrl']}");

    if (response.statusCode == 200) {
      return data['avatarUrl'];
    }
    return null;
  } catch (e) {
    debugPrint("❌ Upload error: $e");
    return null;
  }
}
Future<Map<String, dynamic>> getWallet() async {
  final token = await AuthService.getToken();
  final res = await http.get(
    Uri.parse("${ApiConfig.baseURL}/users/wallet"),
    headers: {"Authorization": "Bearer $token"},
  );
  if (res.statusCode == 200) return jsonDecode(res.body);
  return {"balance": 0, "transactions": []};
}
}