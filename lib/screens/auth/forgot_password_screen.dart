import 'package:flutter/material.dart'; // Importation des composants graphiques Material Design
import 'package:google_fonts/google_fonts.dart'; // Importation des polices Google pour un design moderne
import 'package:pfe/service/auth_service.dart'; // Importation du service d'authentification (API)
import 'otp_verification_screen.dart'; // Importation de l'écran suivant pour la navigation

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Contrôleur pour récupérer le texte saisi dans le champ email
  final emailC = TextEditingController();
  
  // Variables d'état pour gérer les messages d'erreur et l'indicateur de chargement
  String msg = "";
  bool loading = false;

  // Définition de la palette de couleurs "Lancy" (cohérence visuelle)
  final Color mintCrystal = const Color(0xFF81E38F); // Vert
  final Color skyBlue = const Color(0xFF74C0FC);     // Bleu
  final Color backgroundLight = const Color(0xFFF9FBFF); // Fond clair
  final Color darkText = const Color(0xFF1A1C1E);    // Texte sombre

  // MÉTHODE POUR ENVOYER L'OTP
  Future<void> sendOTP() async {
    // Ferme le clavier dès que l'utilisateur appuie sur le bouton
    FocusScope.of(context).unfocus();

    // Validation locale : vérifie si le champ est vide
    if (emailC.text.trim().isEmpty) {
      setState(() => msg = "Please enter your email 📧");
      return;
    }

    // Active l'état de chargement et réinitialise les messages
    setState(() {
      loading = true;
      msg = "";
    });

    try {
      // Appel API : demande au serveur d'envoyer un code à cet email
      await AuthService.forgotPassword(email: emailC.text.trim());

      // Vérifie si le widget est toujours affiché avant de naviguer (sécurité Flutter)
      if (!mounted) return;

      // Navigation vers l'écran OTP en remplaçant l'écran actuel
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OTPVerificationScreen(
            email: emailC.text.trim(), 
            isFromRegister: false, // Indique que c'est une récupération et non une inscription
          ),
        ),
      );
    } catch (e) {
      // Affiche l'erreur du serveur en nettoyant le texte "Exception: "
      setState(() => msg = e.toString().replaceAll("Exception: ", ""));
    } finally {
      // Désactive le chargement, que l'appel ait réussi ou échoué
      if (mounted) setState(() => loading = false);
    }
  }

  // Nettoyage de la mémoire quand on quitte l'écran
  @override
  void dispose() {
    emailC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar( // Barre haute transparente pour le bouton retour
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea( // Évite les zones d'encoche du téléphone
        child: Center(
          child: SingleChildScrollView( // Permet de scroller si le clavier dépasse
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icône de cadenas stylisée en haut
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: skyBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset_rounded, size: 70, color: skyBlue),
                  ),
                ),
                const SizedBox(height: 32),

                // Titre principal
                Text(
                  "Forgot Password?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: darkText),
                ),
                const SizedBox(height: 12),
                
                // Texte explicatif pour l'utilisateur
                Text(
                  "Enter your email address and we will send you a code to reset your password.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15, height: 1.5),
                ),

                const SizedBox(height: 40),

                // Widget personnalisé pour le champ de saisie
                _buildEmailField(),

                // Affichage dynamique du message d'erreur s'il existe
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

                // Widget personnalisé pour le bouton de validation
                _buildSubmitButton(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DESIGN DU CHAMP EMAIL ---
  Widget _buildEmailField() {
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
      child: TextField(
        controller: emailC,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: darkText),
        decoration: InputDecoration(
          hintText: "Enter your email",
          hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.email_outlined, color: skyBlue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  // --- DESIGN DU BOUTON AVEC DÉGRADÉ ---
  Widget _buildSubmitButton() {
    return InkWell(
      onTap: loading ? null : sendOTP, // Désactive le clic si en chargement
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient( // Dégradé de bleu à vert
            colors: [skyBlue, mintCrystal],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: skyBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox( // Affiche un loader si loading est vrai
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text( // Sinon affiche le texte normal
                  "SEND CODE",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
        ),
      ),
    );
  }
}