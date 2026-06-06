import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';

class ProposalService {
  String get _baseUrl => "${ApiConfig.baseURL}/proposals";

  /// 🔹 Génère un brouillon de proposition (Groq côté serveur — projet déjà publié par le client).
  Future<Map<String, dynamic>> generateAiProposalDraft({
    required String token,
    required String projectId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai-draft'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'projectId': projectId}),
      );

      final dynamic decoded = response.body.isEmpty
          ? null
          : jsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'ok': true,
          'coverLetter': decoded['coverLetter'],
          'deliveryDays': decoded['deliveryDays'],
          'priceSuggestion': decoded['priceSuggestion'],
        };
      }

      final msg = decoded is Map && decoded['message'] != null
          ? decoded['message'].toString()
          : 'Échec (${response.statusCode})';
      return {'ok': false, 'message': msg};
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  /// 🔹 CREATE PROPOSAL
  Future<bool> createProposal({
    required String token,
    required String projectId,
    required String coverLetter,
    required int price,
    required int deliveryTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "projectId": projectId,
          "price": price,
          "deliveryTime": deliveryTime,
          "coverLetter": coverLetter,
        }),
      );

      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("BODY: ${response.body}");

      return response.statusCode == 201;
    } catch (e) {
      debugPrint("❌ Create Error: $e");
      return false;
    }
  }

  /// 🔹 GET PROPOSALS
  Future<List<dynamic>> getProposals(String token, String projectId) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/project/$projectId"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return [];
    } catch (e) {
      debugPrint("❌ Get Error: $e");
      return [];
    }
  }

  /// 🔹 ACCEPT PROPOSAL — returns (success, server message).
  Future<(bool, String)> acceptProposal(String token, String id) async {
    try {
      final response = await http.put(
        Uri.parse("$_baseUrl/$id/accept"),
        headers: {"Authorization": "Bearer $token"},
      );
      final msg = _parseMessage(response.body, fallback: response.reasonPhrase);
      return (response.statusCode == 200, msg);
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// 🔹 REJECT PROPOSAL
  Future<(bool, String)> rejectProposal(String token, String id) async {
    try {
      final response = await http.put(
        Uri.parse("$_baseUrl/$id/reject"),
        headers: {"Authorization": "Bearer $token"},
      );
      final msg = _parseMessage(response.body, fallback: response.reasonPhrase);
      return (response.statusCode == 200, msg);
    } catch (e) {
      return (false, e.toString());
    }
  }

  String _parseMessage(String body, {String? fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return 'Erreur réseau';
  }
}