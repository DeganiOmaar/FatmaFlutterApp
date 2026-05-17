import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';

class AssistantSessionSummary {
  final String id;
  final String title;
  final DateTime? updatedAt;

  AssistantSessionSummary({
    required this.id,
    required this.title,
    this.updatedAt,
  });

  factory AssistantSessionSummary.fromJson(Map<String, dynamic> json) {
    return AssistantSessionSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Conversation',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

class AssistantChatMessage {
  final String? id;
  final String content;
  final bool isUser;
  final DateTime? createdAt;

  AssistantChatMessage({
    this.id,
    required this.content,
    required this.isUser,
    this.createdAt,
  });

  factory AssistantChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString() ?? 'user';
    return AssistantChatMessage(
      id: json['id']?.toString(),
      content: json['content']?.toString() ?? '',
      isUser: role == 'user',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class AssistantService {
  final String token;

  AssistantService(this.token);

  String get _base => '${ApiConfig.baseURL}/assistant';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<AssistantSessionSummary>> listSessions() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/sessions'),
        headers: _headers,
      );
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['sessions'] is! List) return [];
      return (decoded['sessions'] as List)
          .whereType<Map>()
          .map((e) => AssistantSessionSummary.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((s) => s.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('assistant listSessions: $e');
      return [];
    }
  }

  Future<AssistantSessionSummary?> createSession() async {
    try {
      final res = await http.post(
        Uri.parse('$_base/sessions'),
        headers: _headers,
      );
      if (res.statusCode != 201 && res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['session'] is! Map) return null;
      return AssistantSessionSummary.fromJson(
        Map<String, dynamic>.from(decoded['session'] as Map),
      );
    } catch (e) {
      debugPrint('assistant createSession: $e');
      return null;
    }
  }

  Future<({String? sessionTitle, List<AssistantChatMessage> messages})?>
      loadSession(String sessionId) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/sessions/$sessionId/messages'),
        headers: _headers,
      );
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final title = decoded['session'] is Map
          ? decoded['session']['title']?.toString()
          : null;
      final list = decoded['messages'] is List ? decoded['messages'] as List : [];
      final messages = list
          .whereType<Map>()
          .map((m) => AssistantChatMessage.fromJson(
                Map<String, dynamic>.from(m),
              ))
          .toList();
      return (sessionTitle: title, messages: messages);
    } catch (e) {
      debugPrint('assistant loadSession: $e');
      return null;
    }
  }

  Future<
      ({
        bool ok,
        String? error,
        AssistantChatMessage? assistant,
        String? sessionTitle,
      })> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/sessions/$sessionId/messages'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      );
      final decoded =
          res.body.isEmpty ? null : jsonDecode(res.body);

      if (res.statusCode == 200 && decoded is Map) {
        String? sessionTitle;
        final sess = decoded['session'];
        if (sess is Map && sess['title'] != null) {
          sessionTitle = sess['title'].toString();
        }
        final am = decoded['assistantMessage'];
        if (am is Map) {
          return (
            ok: true,
            error: null,
            assistant: AssistantChatMessage.fromJson(
              Map<String, dynamic>.from(am),
            ),
            sessionTitle: sessionTitle,
          );
        }
        return (
          ok: true,
          error: null,
          assistant: null,
          sessionTitle: sessionTitle,
        );
      }

      final msg = decoded is Map && decoded['message'] != null
          ? decoded['message'].toString()
          : 'Erreur (${res.statusCode})';
      return (
        ok: false,
        error: msg,
        assistant: null,
        sessionTitle: null,
      );
    } catch (e) {
      return (
        ok: false,
        error: e.toString(),
        assistant: null,
        sessionTitle: null,
      );
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/sessions/$sessionId'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('assistant deleteSession: $e');
      return false;
    }
  }
}
