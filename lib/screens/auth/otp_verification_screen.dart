import 'package:flutter/material.dart'; // Importation des widgets de base
import 'package:google_fonts/google_fonts.dart'; // Police personnalisée
import 'package:pfe/screens/main_screen.dart';
import 'package:pfe/service/auth_service.dart'; // Logique API pour la vérification
import 'reset_password_screen.dart'; // Destination si "Mot de passe oublié"

class OTPVerificationScreen extends StatefulWidget {
  final String email; // Email pour lequel on vérifie le code
  final bool isFromRegister; // Flag pour savoir si on vient de Register ou de ForgotPassword
  /// Rôle choisi à l’inscription (`client` / `freelancer`) — requis pour afficher la bonne liste sur l’accueil.
  final String role;

  const OTPVerificationScreen({
    super.key,
    required this.email,
    required this.isFromRegister,
    this.role = '',
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  // Génération de 6 contrôleurs pour les 6 chiffres du code OTP
  final List<TextEditingController> otpControllers = List.generate(6, (_) => TextEditingController());
  // Génération de 6 FocusNodes pour déplacer automatiquement le curseur d'une case à l'autre
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  // Thème de couleurs Lancy
  final Color mintCrystal = const Color(0xFF81E38F);
  final Color skyBlue = const Color(0xFF74C0FC);
  final Color backgroundLight = const Color(0xFFF9FBFF);
  final Color darkText = const Color(0xFF1A1C1E);

  String msg = ""; // Pour afficher les erreurs
  bool loading = false; // Pour l'état du bouton

  @override
  void initState() {
    super.initState();
    // Donne le focus à la première case automatiquement après un court délai
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) FocusScope.of(context).requestFocus(focusNodes[0]);
    });
  }

  @override
  void dispose() {
    // Libère la mémoire des contrôleurs et des focus nodes
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // LOGIQUE DE DÉPLACEMENT AUTOMATIQUE DU CURSEUR
  void _onOTPChanged(int index, String value) {
    // Si un chiffre est saisi, on passe à la case suivante
    if (value.length == 1 && index < 5) {
      focusNodes[index + 1].requestFocus();
    } 
    // Si on efface, on revient à la case précédente
    else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    // Si on arrive à la dernière case et qu'elle est remplie, on lance la vérification
    if (index == 5 && value.isNotEmpty) {
      final allFilled = otpControllers.every((c) => c.text.isNotEmpty);
      if (allFilled) verifyOTP();
    }
  }

  // APPEL API POUR VÉRIFIER LE CODE
  Future<void> verifyOTP() async {
    FocusScope.of(context).unfocus(); // Ferme le clavier
    final code = otpControllers.map((c) => c.text).join(); // Fusionne les 6 chiffres en un seul String

    if (code.length != 6) {
      setState(() => msg = "Please enter the complete 6-digit code");
      return;
    }

    setState(() {
      loading = true;
      msg = "";
    });

    try {
      // Appel du service AuthService
      await AuthService.verifyOTP(
        email: widget.email,
        code: code,
        isFromRegister: widget.isFromRegister,
      );

      if (!mounted) return;

      // LOGIQUE DE REDIRECTION CONDITIONNELLE
      if (widget.isFromRegister) {
        final savedEmail = await AuthService.getUserEmail();
        final savedRole = await AuthService.getUserRole();
        final savedName = await AuthService.getUserName();
        if (!mounted) return;
  Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(
    builder: (_) => MainScreen(
      email: savedEmail ?? widget.email.trim().toLowerCase(),
      role: savedRole ?? widget.role,
      name: savedName,
    ),
  ),
  (route) => false,
);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account verified! Welcome 🌸")),
        );
      } else {
        // Cas 2: Reset Password -> Go Reset Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(email: widget.email, code: code),
          ),
        );
      }
    } catch (e) {
      setState(() => msg = e.toString().replaceAll("Exception: ", ""));
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Icône d'email vérifié
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: mintCrystal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_read_outlined, size: 60, color: mintCrystal),
                ),
                const SizedBox(height: 32),
                Text(
                  "Verification Code",
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: darkText),
                ),
                const SizedBox(height: 12),
                // Texte explicatif avec l'email dynamique
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15),
                    children: [
                      const TextSpan(text: "We have sent the OTP code to \n"),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(color: darkText, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Ligne contenant les 6 cases de saisie
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) => _buildOTPBox(index)),
                ),
                const SizedBox(height: 25),
                if (msg.isNotEmpty)
                  Text(msg, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                const SizedBox(height: 35),
                _buildVerifyButton(),
                const SizedBox(height: 30),
                // Lien pour renvoyer le code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Didn't receive code? ", style: GoogleFonts.inter(color: Colors.grey[600])),
                    TextButton(
                      onPressed: () {}, // À implémenter : AuthService.resendOTP
                      child: Text("Resend", style: GoogleFonts.inter(color: skyBlue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET POUR UNE CASE DE SAISIE OTP
  Widget _buildOTPBox(int index) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: otpControllers[index],
        focusNode: focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1, // Un seul caractère par case
        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: skyBlue),
        decoration: InputDecoration(
          counterText: "", // Masque le compteur de caractères par défaut
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: skyBlue, width: 2),
          ),
        ),
        onChanged: (value) => _onOTPChanged(index, value),
      ),
    );
  }

  // WIDGET POUR LE BOUTON DE VÉRIFICATION
  Widget _buildVerifyButton() {
    return InkWell(
      onTap: loading ? null : verifyOTP,
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
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text("VERIFY NOW", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
        ),
      ),
    );
  }
}