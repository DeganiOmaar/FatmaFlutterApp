import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/service/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String email;

  const ChangePasswordScreen({super.key, required this.email});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final oldPasswordC = TextEditingController();
  final newPasswordC = TextEditingController();
  final confirmPasswordC = TextEditingController();

  final Color mintCrystal = const Color(0xFF81E38F);
  final Color skyBlue = const Color(0xFF74C0FC);
  final Color backgroundLight = const Color(0xFFF9FBFF);
  final Color darkText = const Color(0xFF1A1C1E);

  String msg = "";
  bool loading = false;
  bool hideOld = true;
  bool hideNew = true;
  bool hideConfirm = true;

  Future<void> changePassword() async {
    FocusScope.of(context).unfocus();

    // Validations
    if (oldPasswordC.text.isEmpty ||
        newPasswordC.text.isEmpty ||
        confirmPasswordC.text.isEmpty) {
      setState(() => msg = "Remplis tous les champs ✍️");
      return;
    }

    if (newPasswordC.text != confirmPasswordC.text) {
      setState(() => msg = "Les mots de passe ne correspondent pas ❌");
      return;
    }

    if (newPasswordC.text.length < 6) {
      setState(() => msg = "Minimum 6 caractères 🛡️");
      return;
    }

    setState(() {
      loading = true;
      msg = "";
    });

    try {
      await AuthService.changePassword(
        email: widget.email,
        oldPassword: oldPasswordC.text,
        newPassword: newPasswordC.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Mot de passe modifié avec succès !",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: mintCrystal,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => msg = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    oldPasswordC.dispose();
    newPasswordC.dispose();
    confirmPasswordC.dispose();
    super.dispose();
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
        title: Text("Changer le mot de passe",
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkText)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Icône
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: skyBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_reset_rounded,
                      size: 70, color: skyBlue),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "Sécurise ton compte",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkText),
              ),
              const SizedBox(height: 8),
              Text(
                "Entre ton ancien mot de passe puis le nouveau.",
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
              ),

              const SizedBox(height: 36),

              // Ancien mot de passe
              _buildPasswordField(
                controller: oldPasswordC,
                hint: "Ancien mot de passe",
                isObscure: hideOld,
                toggle: () => setState(() => hideOld = !hideOld),
              ),
              const SizedBox(height: 14),

              // Nouveau mot de passe
              _buildPasswordField(
                controller: newPasswordC,
                hint: "Nouveau mot de passe",
                isObscure: hideNew,
                toggle: () => setState(() => hideNew = !hideNew),
              ),
              const SizedBox(height: 14),

              // Confirmation
              _buildPasswordField(
                controller: confirmPasswordC,
                hint: "Confirmer le mot de passe",
                isObscure: hideConfirm,
                toggle: () => setState(() => hideConfirm = !hideConfirm),
              ),

              // Message erreur
              if (msg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500),
                  ),
                ),

              const SizedBox(height: 32),

              // Bouton
              InkWell(
                onTap: loading ? null : changePassword,
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(colors: [skyBlue, mintCrystal]),
                    boxShadow: [
                      BoxShadow(
                          color: skyBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            "MODIFIER LE MOT DE PASSE",
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.1),
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool isObscure,
    required VoidCallback toggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.lock_outline_rounded, color: skyBlue),
          suffixIcon: IconButton(
            icon: Icon(
                isObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[400],
                size: 20),
            onPressed: toggle,
          ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}