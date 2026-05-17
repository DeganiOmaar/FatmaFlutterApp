import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class MessageService {
  /// GET messages history
  static Future<List<dynamic>> getMessages(String projectId) async {
    final url = Uri.parse("${ApiConfig.baseURL}/messages/$projectId");
    final token = await AuthService.getToken();
    final res = await http.get(
      url,
      headers: {
        if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) return [];
    try {
      final decoded = jsonDecode(res.body);
      return decoded is List ? decoded : [];
    } catch (_) {
      return [];
    }
  }

  /// POST message — persists on server et déclenche le broadcast websocket.
  static Future<Map<String, dynamic>> sendMessage(
    String projectId,
    String senderId,
    String receiverId,
    String text,
  ) async {
    final url = Uri.parse("${ApiConfig.baseURL}/messages");
    final token = await AuthService.getToken();

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        if (token != null && token.isNotEmpty)
          "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "projectId": projectId,
        "senderId": senderId,
        "receiverId": receiverId,
        "text": text,
      }),
    );

    dynamic body;
    try {
      body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      body = null;
    }

    if (res.statusCode == 201 && body is Map) {
      return Map<String, dynamic>.from(body);
    }

    final errMsg =
        body is Map
            ? (body['message'] ?? body['error'])?.toString()
            : null;
    throw Exception(errMsg ?? 'Erreur envoi message (${res.statusCode})');
  }
}
