import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/screens/auth/ChooseRoleScreen.dart';
import 'package:pfe/screens/auth/login.dart';

class SplashPage extends StatelessWidget {
  // Palette de couleurs Premium
  final Color mintCrystal = const Color(0xFF81E38F); // Version un peu plus vibrante
  final Color skyBlue = const Color(0xFF74C0FC);
  final Color backgroundLight = const Color(0xFFF9FBFF); // Blanc bleuté très propre
  final Color darkText = const Color(0xFF1A1C1E);

  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Léger halo de couleur en fond pour le côté moderne
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.5),
            radius: 1.2,
            colors: [skyBlue.withValues(alpha: 0.05), Colors.transparent],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 3),
            
            // --- LOGO AVEC EFFET DE PROFONDEUR ---
            _buildModernLogo(),
            
            const SizedBox(height: 40),
            
            // --- NOM DE LA MARQUE ---
            Text(
              "LANCY",
              style: GoogleFonts.poppins(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: darkText, 
                letterSpacing: 8,
              ),
            ),
            
            Text(
              "SkillBridge AI Platform",
              style: GoogleFonts.inter(
                color: darkText.withValues(alpha: 0.4), 
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),

            const Spacer(flex: 2),

            // --- ACTIONS D'AUTHENTIFICATION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  // Action principale : S'inscrire
                  _buildPremiumButton(
                    context: context,
                    text: "GET STARTED",
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const ChooseRoleScreen())
                    ),
                  ),
                  
                  const SizedBox(height: 18),
                  
                  // Action secondaire : Se connecter
                  _buildSecondaryButton(
                    text: "I already have an account",
                    onPressed: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  // Widget du logo avec design circulaire premium
  Widget _buildModernLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: skyBlue.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: mintCrystal.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: Image.asset(
        'assets/logo.png',
        width: 140,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.blur_on_rounded, size: 100, color: skyBlue),
      ),
    );
  }

  // Bouton Principal (Gradient)
  Widget _buildPremiumButton({required BuildContext context, required String text, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mintCrystal, skyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: skyBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          text, 
          style: GoogleFonts.poppins(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: Colors.white,
            letterSpacing: 1.2
          )
        ),
      ),
    );
  }

  // Bouton Secondaire (Minimaliste)
  Widget _buildSecondaryButton({required String text, required VoidCallback onPressed}) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: darkText.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}