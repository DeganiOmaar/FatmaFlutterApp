import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/controllers/wallet_balance_controller.dart';
import 'package:pfe/screens/auth/ChooseRoleScreen.dart';
import 'package:pfe/screens/auth/forgot_password_screen.dart';
import 'package:pfe/screens/main_screen.dart';
import 'package:pfe/service/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  String msg = "";
  bool loading = false;
  bool hidePassword = true;

  final Color mintCrystal = const Color(0xFF81E38F);
  final Color skyBlue = const Color(0xFF74C0FC);
  final Color backgroundLight = const Color(0xFFF9FBFF);
  final Color darkText = const Color(0xFF1A1C1E);

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  String _cleanError(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) s = s.substring(11);
    return s;
  }

  Future<void> doLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      msg = "";
    });

    try {
      final data = await AuthService.login(
        email: emailC.text.trim(),
        password: passC.text,
      );

      String email = emailC.text.trim();
      String role = 'client';
      String? name;
      final user = data['user'];
      if (user is Map) {
        email = user['email']?.toString() ?? email;
        role = user['role']?.toString() ?? 'client';
        name = user['name']?.toString();
      }

      if (!mounted) return;

      if (Get.isRegistered<WalletBalanceController>()) {
        await Get.find<WalletBalanceController>().refreshFromApi();
      }

      if (!mounted) return;
  Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => MainScreen(email: email, role: role, name: name),
  ),
);
    } catch (e) {
      if (mounted) {
        setState(() => msg = _cleanError(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bon retour\nsur Lancy ✨",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Connecte-toi pour retrouver tes missions et ton réseau.",
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15),
              ),
              const SizedBox(height: 35),
              _buildModernField(
                controller: emailC,
                hint: "Adresse Email",
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || !v.contains("@") ? "Email invalide" : null,
              ),
              const SizedBox(height: 20),
              _buildModernField(
                controller: passC,
                hint: "Mot de passe",
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                validator: (v) =>
                    v == null || v.isEmpty ? "Mot de passe requis" : null,
              ),
              if (msg.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  msg,
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "Mot de passe oublié ?",
                    style: GoogleFonts.inter(
                      color: skyBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildSubmitButton(),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChooseRoleScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "Pas encore de compte ? S'inscrire",
                    style: GoogleFonts.inter(
                      color: darkText.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? hidePassword : false,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.inter(color: darkText, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: skyBlue, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      setState(() => hidePassword = !hidePassword),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return InkWell(
      onTap: loading ? null : doLogin,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [skyBlue, mintCrystal]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: skyBlue.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  "SE CONNECTER",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
        ),
      ),
    );
  }
}
