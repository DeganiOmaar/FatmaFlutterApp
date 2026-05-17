import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';

class HomeService {
  // --- 1. POUR LE CLIENT : VOIR LES FREELANCERS ---
  Future<List<dynamic>> fetchFreelancers() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.origin}/api/users/all-freelancers"),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur serveur lors de la récupération des freelancers");
    }
  }

  // --- 2. POUR LE FREELANCER : VOIR TOUTES LES MISSIONS (projets clients) ---
  /// Passe [authToken] pour recevoir `userProposalStatus` (déjà postulé ou non).
  Future<List<dynamic>> fetchProjects({String? authToken}) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.origin}/api/projects"),
        headers: {
          "Content-Type": "application/json",
          if (authToken != null && authToken.isNotEmpty)
            "Authorization": "Bearer $authToken",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is List ? decoded : <dynamic>[];
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      debugPrint("❌ Erreur fetchProjects: $e");
      return [];
    }
  }

  /// Projets publiés par le client connecté (JWT requis).
  Future<List<dynamic>> fetchMyProjects(String token) async {
  final response = await http.get(
    Uri.parse("${ApiConfig.origin}/api/projects/my"),
    headers: {"Authorization": "Bearer $token"},
  );
  
  // ✅ Ajoute ces logs
  debugPrint("📡 fetchMyProjects status: ${response.statusCode}");
  debugPrint("📡 fetchMyProjects body: ${response.body}");
  
  if (response.statusCode == 200) {
    final list = jsonDecode(response.body);
    return list is List ? list : <dynamic>[];
  }
  if (response.statusCode == 401) {
    throw Exception("Session expirée — reconnecte-toi.");
  }
  throw Exception("Erreur lors du chargement de tes projets");
}
  // --- 3. POUR LE CLIENT : POSTER UN NOUVEAU PROJET ---
  // On ajoute le 'token' car ta route backend utilise 'requireAuth'
  /// Retourne `null` si succès, sinon message d'erreur serveur.
  Future<String?> addProject(
    Map<String, dynamic> projectData,
    String token,
  ) async {
    try {
      if (projectData.containsKey('budget')) {
        projectData['budget'] =
            double.tryParse(projectData['budget'].toString()) ?? 0;
      }

      final response = await http.post(
        Uri.parse("${ApiConfig.origin}/api/projects/add"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(projectData),
      );

      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");

      if (response.statusCode == 201) {
        return null;
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['message']?.toString() ??
            "Échec de la publication (${response.statusCode})";
      } catch (_) {
        return "Échec de la publication (${response.statusCode})";
      }
    } catch (e) {
      debugPrint("Erreur connexion: $e");
      return "Erreur réseau : $e";
    }
  }
}
