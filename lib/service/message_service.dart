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

  static Future<Map<String, dynamic>> _authJsonRequest(
    String method,
    Uri url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await AuthService.getToken();
    final headers = <String, String>{
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty)
        "Authorization": "Bearer $token",
    };

    final http.Response res;
    switch (method) {
      case "PATCH":
        res = await http.patch(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case "DELETE":
        res = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception("Méthode HTTP non supportée");
    }

    dynamic decoded;
    try {
      decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    final errMsg =
        decoded is Map
            ? (decoded['message'] ?? decoded['error'])?.toString()
            : null;
    throw Exception(errMsg ?? 'Erreur (${res.statusCode})');
  }

  /// PATCH — modifier un message (auteur uniquement, côté serveur).
  static Future<Map<String, dynamic>> editMessage(
    String messageId,
    String text,
  ) async {
    final id = messageId.trim();
    final url = Uri.parse("${ApiConfig.baseURL}/messages/$id");
    return _authJsonRequest(
      "PATCH",
      url,
      body: {"text": text.trim()},
    );
  }

  /// DELETE — supprimer un message (soft delete, auteur uniquement).
  static Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    final id = messageId.trim();
    final url = Uri.parse("${ApiConfig.baseURL}/messages/$id");
    return _authJsonRequest("DELETE", url);
  }
}
