import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';
import 'package:pfe/screens/main_screen.dart';
import 'package:pfe/service/auth_service.dart';

class AuthController extends GetxController {
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  Future<String?> login(String email, String password) async {
    try {
      _isLoading.value = true;

      // 1. Logique el login
      await AuthService.login(
        email: email.trim(), 
        password: password
      );

      // 2. Nejbdou el ma3loumet mel AuthService ba3d ma t-sayivou f-el SharedPreferences
      final String? emailData = await AuthService.getUserEmail();
      final String? roleData = await AuthService.getUserRole();
      final String? nameData = await AuthService.getUserName();

      _isLoading.value = false;

      // 3. Taw n-hazzou lel MainScreen b-el ma3loumet el s-hiha
      Get.offAll(() => MainScreen(
        email: emailData ?? email.trim(),
        role: roleData ?? 'client', // Default 'client' ken malqach role
        name: nameData,
      ));

      return null; 
    } catch (e) {
      _isLoading.value = false;
      return e.toString().replaceAll("Exception:", "").trim();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? skills,
    String? bio,
  }) async {
    try {
      _isLoading.value = true;
      await AuthService.register(
        name: name,
        email: email.trim(),
        password: password,
        role: role,
        skills: skills,
        bio: bio,
      );
      _isLoading.value = false;
      return null;
    } catch (e) {
      _isLoading.value = false;
      return e.toString().replaceAll("Exception:", "").trim();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading.value = true;
      await AuthService.logout(); 
      Get.offAllNamed('/login'); 
      _isLoading.value = false;
    } catch (e) {
      _isLoading.value = false;
      debugPrint("Erreur logout: $e");
    }
  }

  Future<bool> checkUserValidity() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.get(
        Uri.parse("${ApiConfig.baseURL}/auth/profile"),
        headers: {"Authorization": "Bearer $token"},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}