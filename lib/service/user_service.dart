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

  Future<bool> updateProfile({
    required String email,
    required String name,
    required String bio,
  }) async {
    try {
      final safe = Uri.encodeComponent(email.trim());
      final response = await http.put(
        // ✅ baseURL = http://IP:5001/api → donc /users/update/$safe
        Uri.parse("${ApiConfig.baseURL}/users/update/$safe"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "bio": bio}),
      );

      debugPrint("📡 updateProfile status: ${response.statusCode}");
      debugPrint("📡 updateProfile body: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Update error: $e");
      return false;
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