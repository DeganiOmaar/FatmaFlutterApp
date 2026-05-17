import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/screens/auth/login.dart'; // Importation de l'écran de login pour le retour
import 'package:pfe/service/auth_service.dart'; // Service pour l'appel API final

class ResetPasswordScreen extends StatefulWidget {
  final String email; // Email transmis depuis l'écran OTP
  final String code;  // Code OTP validé à renvoyer pour sécurité côté serveur

  const ResetPasswordScreen({super.key, required this.email, required this.code});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // Contrôleurs pour récupérer les deux saisies de mot de passe
  final newPasswordC = TextEditingController();
  final confirmPasswordC = TextEditingController();

  // Palette Lancy
  final Color mintCrystal = const Color(0xFF81E38F);
  final Color skyBlue = const Color(0xFF74C0FC);
  final Color backgroundLight = const Color(0xFFF9FBFF);
  final Color darkText = const Color(0xFF1A1C1E);

  String msg = ""; // Message d'erreur local
  bool loading = false; // État de chargement du bouton
  bool hideNewPassword = true; // Visibilité du premier champ
  bool hideConfirmPassword = true; // Visibilité du second champ

  // MÉTHODE DE RÉINITIALISATION
  Future<void> resetPassword() async {
    FocusScope.of(context).unfocus(); // Ferme le clavier

    // 1. Validation : Champs vides
    if (newPasswordC.text.isEmpty || confirmPasswordC.text.isEmpty) {
      setState(() => msg = "Please fill all fields ✍️");
      return;
    }

    // 2. Validation : Correspondance
    if (newPasswordC.text != confirmPasswordC.text) {
      setState(() => msg = "Passwords do not match ❌");
      return;
    }

    // 3. Validation : Longueur minimale
    if (newPasswordC.text.length < 6) {
      setState(() => msg = "Use at least 6 characters 🛡️");
      return;
    }

    setState(() {
      loading = true;
      msg = "";
    });

    try {
      // 4. Appel au service AuthService pour mettre à jour la DB via Node.js
      await AuthService.resetPassword(
        email: widget.email,
        code: widget.code,
        newPassword: newPasswordC.text,
        confirmPassword: confirmPasswordC.text,
      );

      if (!mounted) return;

      // 5. Notification de succès stylisée
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Success! Your password is now updated.", 
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: mintCrystal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // 6. Navigation finale : Retour au Login et effacement de la pile de navigation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      // Gestion des erreurs provenant du serveur
      setState(() => msg = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
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
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête avec Icône de sécurité
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: skyBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.security_update_good_rounded, size: 70, color: skyBlue),
                ),
                const SizedBox(height: 32),

                Text(
                  "New Password",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: darkText),
                ),
                const SizedBox(height: 12),
                Text(
                  "Create a strong password to keep your account secure.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15),
                ),

                const SizedBox(height: 40),

                // Champ : Nouveau mot de passe
                _buildPasswordField(
                  controller: newPasswordC,
                  hint: "New Password",
                  isObscure: hideNewPassword,
                  toggle: () => setState(() => hideNewPassword = !hideNewPassword),
                ),
                const SizedBox(height: 16),
                
                // Champ : Confirmation
                _buildPasswordField(
                  controller: confirmPasswordC,
                  hint: "Confirm Password",
                  isObscure: hideConfirmPassword,
                  toggle: () => setState(() => hideConfirmPassword = !hideConfirmPassword),
                ),

                // Affichage dynamique de l'erreur
                if (msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                    ),
                  ),

                const SizedBox(height: 35),

                // Bouton de mise à jour avec Gradient
                _buildSubmitButton(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET RÉUTILISABLE POUR LES CHAMPS MOT DE PASSE
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8)),
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
            icon: Icon(isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
              color: Colors.grey[400], size: 20),
            onPressed: toggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  // WIDGET BOUTON DE VALIDATION
  Widget _buildSubmitButton() {
    return InkWell(
      onTap: loading ? null : resetPassword,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [skyBlue, mintCrystal]),
          boxShadow: [
            BoxShadow(color: skyBlue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(
                  "UPDATE PASSWORD",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1),
                ),
        ),
      ),
    );
  }
}