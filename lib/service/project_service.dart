import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';
import 'auth_service.dart';
import 'dart:io';
class ProjectService {

  // ===============================
  // 🟢 CREATE PROJECT
  // ===============================
  /// Retourne `null` si succès, sinon message d’erreur.
  Future<String?> createProject(
    String title,
    String description,
    String budget,
    String email,
  ) async {
    try {
      String? token = await AuthService.getToken();

      final budgetNum = double.tryParse(budget.replaceAll(',', '.')) ?? 0;

      final res = await http.post(
        Uri.parse("${ApiConfig.baseURL}/projects/add"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "title": title,
          "description": description,
          "budget": budgetNum,
          "clientEmail": email,
        }),
      );

      debugPrint("CREATE STATUS: ${res.statusCode}");
      if (res.statusCode == 201) return null;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['message']?.toString() ??
            "Échec (${res.statusCode})";
      } catch (_) {
        return "Échec de publication (${res.statusCode})";
      }
    } catch (e) {
      debugPrint("❌ CREATE ERROR: $e");
      return "Erreur réseau : $e";
    }
  }

  // ===============================
  // 🟡 UPDATE PROJECT
  // ===============================
  static Future<void> updateProject(String id, Map<String, dynamic> data) async {
    final token = await AuthService.getToken();

    final res = await http.put(
      Uri.parse("${ApiConfig.baseURL}/projects/update/$id"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)["message"]);
    }
  }
  Future<List<dynamic>> getMyProjects({required String role}) async {
  try {
    final token = await AuthService.getToken();
   final endpoint = role == 'freelancer'
        ? "${ApiConfig.baseURL}/projects/freelancer"
        : "${ApiConfig.baseURL}/projects/my";

    final res = await http.get(
     Uri.parse(endpoint),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      debugPrint("❌ ERROR: ${res.body}");
      return [];
    }
  } catch (e) {
    debugPrint("❌ EXCEPTION: $e");
    return [];
  }
}

  // ===============================
  // 🔴 DELETE PROJECT (retourne null si succès, sinon message serveur)
  // ===============================
  static Future<String?> deleteProject(String id) async {
    final token = await AuthService.getToken();

    final res = await http.delete(
      Uri.parse("${ApiConfig.baseURL}/projects/delete/$id"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) return null;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['message']?.toString() ??
          'Suppression impossible (${res.statusCode})';
    } catch (_) {
      return 'Suppression impossible (${res.statusCode})';
    }
  }

  // ===============================
  // ✋ DEMANDE D’ANNULATION (mission en escrow — validation admin)
  // ===============================
  static Future<String?> requestMissionCancellation(
    String projectId, {
    String reason = '',
  }) async {
    try {
      final token = await AuthService.getToken();

      final res = await http.post(
        Uri.parse(
          "${ApiConfig.baseURL}/projects/$projectId/request-cancellation",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"reason": reason}),
      );

      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['message']?.toString() ??
            'Demande refusée (${res.statusCode})';
      } catch (_) {
        return 'Demande refusée (${res.statusCode})';
      }
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  /// Infos mission pour le chat (statut livrable admin, paiement…).
  static Future<Map<String, dynamic>?> fetchParticipantMeta(
    String projectId,
  ) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse("${ApiConfig.baseURL}/projects/$projectId/participant-meta"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('fetchParticipantMeta: $e');
    }
    return null;
  }

  /// Client : missions avec livrable validé par l’admin (fichiers + liens).
  static Future<List<dynamic>> fetchClientConfirmedDeliveries() async {
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse(
          "${ApiConfig.baseURL}/projects/my/confirmed-deliveries",
        ),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (e) {
      debugPrint('fetchClientConfirmedDeliveries: $e');
    }
    return [];
  }

  /// Freelancer : envoie fichiers / lien / message au **client** (puis validation admin pour l’escrow).
  static Future<String?> submitAdminDelivery(
    String projectId, {
    String message = '',
    String demoLink = '',
    List<File> files = const [],
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        "${ApiConfig.baseURL}/projects/$projectId/submit-admin-delivery",
      );
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      if (message.isNotEmpty) req.fields['message'] = message;
      if (demoLink.isNotEmpty) req.fields['demoLink'] = demoLink;
      for (final f in files) {
        if (await f.exists()) {
          req.files.add(await http.MultipartFile.fromPath('files', f.path));
        }
      }
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] != null) {
          return body['message'].toString();
        }
      } catch (_) {}
      return 'Envoi impossible (${res.statusCode})';
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  /// Client : valide le livrable freelancer (l’admin libère ensuite l’escrow).
  static Future<String?> approveClientSubmission(String projectId) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.post(
        Uri.parse(
          "${ApiConfig.baseURL}/projects/$projectId/approve-client-submission",
        ),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] != null) {
          return body['message'].toString();
        }
      } catch (_) {}
      return 'Action impossible (${res.statusCode})';
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  /// Client : refuse le livrable (le freelancer peut renvoyer une version).
  static Future<String?> rejectClientSubmission(
    String projectId, {
    String note = '',
  }) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.post(
        Uri.parse(
          "${ApiConfig.baseURL}/projects/$projectId/reject-client-submission",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"note": note}),
      );
      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] != null) {
          return body['message'].toString();
        }
      } catch (_) {}
      return 'Action impossible (${res.statusCode})';
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  // ===============================
  // 💰 ACCEPT PROPOSAL
  // ===============================
  Future<bool> acceptProposal(String proposalId) async {
    try {
      final token = await AuthService.getToken();

      final res = await http.put(
        Uri.parse("${ApiConfig.baseURL}/proposals/$proposalId/accept"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("ACCEPT STATUS: ${res.statusCode}");
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("❌ ACCEPT ERROR: $e");
      return false;
    }
  }

  // ===============================
  // 📦 DELIVER WORK
  // ===============================
Future<bool> deliverProject(String projectId, String link, String message) async {
  try {
    final token = await AuthService.getToken();
    
    debugPrint("=== DELIVER projectId: $projectId ===");
    debugPrint("=== token: $token ===");
    debugPrint("=== URL: ${ApiConfig.baseURL}/projects/$projectId/deliver ===");
    
    final res = await http.put(
      Uri.parse("${ApiConfig.baseURL}/projects/$projectId/deliver"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "link": link,
        "message": message,
      }),
    );
    
    debugPrint("=== STATUS: ${res.statusCode} ===");
    debugPrint("=== BODY: ${res.body} ===");
    
    return res.statusCode == 200;
  } catch (e) {
    debugPrint("❌ Error delivering: $e");
    return false;
  }
}
  // ===============================
  // 💸 RELEASE PAYMENT
  // ===============================
Future<bool> releasePayment(String projectId) async {
  try {
    final token = await AuthService.getToken();

    // ✅ POST au lieu de PUT, projectId dans le body
    final res = await http.post(
      Uri.parse("${ApiConfig.baseURL}/payment/release"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "projectId": projectId,  // ✅ dans le body
      }),
    );

    debugPrint("=== RELEASE STATUS: ${res.statusCode} ===");
    debugPrint("=== RELEASE BODY: ${res.body} ===");

    return res.statusCode == 200;
  } catch (e) {
    debugPrint("❌ RELEASE ERROR: $e");
    return false;
  }
}
 Future<Map<String, dynamic>> createPaymentIntent(String projectId) async {
  // Récupère le token pour que le serveur sache qui paie
  final token = await AuthService.getToken();

  final response = await http.post(
    Uri.parse("${ApiConfig.baseURL}/payment/create-intent"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token", // Ajoute cette ligne
    },
    body: jsonEncode({
      "projectId": projectId,
    }),
  );

  return jsonDecode(response.body);
}
Future<bool> uploadDeliveryFile(
  String projectId,
  File? file,
  String link,
) async {
  final token = await AuthService.getToken();

  var request = http.MultipartRequest(
    'PUT',
    Uri.parse("${ApiConfig.baseURL}/projects/$projectId/deliver"),
  );

  request.headers['Authorization'] = "Bearer $token";

  request.fields['link'] = link;

  if (file != null) {
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );
  }

  var response = await request.send();

  return response.statusCode == 200;
}
Future<Map<String, dynamic>> getProjectById(String id) async {
  try {
    final token = await AuthService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseURL}/projects/$id"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load project");
    }
  } catch (e) {
    throw Exception("ERROR: $e");
  }
}
}  
    

