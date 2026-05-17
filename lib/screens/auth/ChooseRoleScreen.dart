import 'package:flutter/material.dart'; // Importation des composants graphiques de base
import 'package:google_fonts/google_fonts.dart'; // Importation de polices personnalisées pour le design
import 'register.dart'; // Importation de la page d'inscription pour la navigation

class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

// Utilisation de SingleTickerProviderStateMixin pour gérer les animations si nécessaire
class _ChooseRoleScreenState extends State<ChooseRoleScreen> with SingleTickerProviderStateMixin {
  // --- PALETTE DE COULEURS DU PROJET ---
  final Color mintCrystal = const Color(0xFF81E38F); // Couleur secondaire (Freelancer/Succès)
  final Color skyBlue = const Color(0xFF74C0FC);     // Couleur primaire (Client/Pro)
  final Color backgroundLight = const Color(0xFFF9FBFF); // Couleur de fond douce
  final Color darkText = const Color(0xFF1A1C1E);    // Couleur du texte principal

  String selectedRole = ""; // Variable d'état pour suivre le rôle choisi ("client" ou "freelancer")

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight, // Application de la couleur de fond
      body: Stack( // Utilisation d'un Stack pour superposer les éléments de design
        children: [
          // FORME DÉCORATIVE HAUT-DROITE
          Positioned(
            top: -100,
            right: -50,
            child: _buildCircle(300, skyBlue.withValues(alpha: 0.05)), // Cercle bleu très transparent
          ),
          // FORME DÉCORATIVE BAS-GAUCHE
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildCircle(200, mintCrystal.withValues(alpha: 0.08)), // Cercle vert très transparent
          ),
          
          SafeArea( // Empêche le contenu de chevaucher la barre d'état (encoche, heure)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BOUTON DE RETOUR PERSONNALISÉ
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)], // Ombre légère
                      ),
                      child: Icon(Icons.arrow_back_ios_new, color: skyBlue, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context), // Retour à l'écran précédent
                  ),
                ),
                
                Expanded( // Le contenu central prend tout l'espace restant
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // BADGE DE PROGRESSION (Étape 1 sur 2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: skyBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            "STEP 1 OF 2",
                            style: TextStyle(color: skyBlue, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2),
                          ),
                        ),
                        const SizedBox(height: 20), // Espacement
                        
                        // TITRE DE LA PAGE
                        Text(
                          "How would you like to use the platform?",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: darkText,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // CARTE POUR LE RÔLE CLIENT
                        _premiumRoleCard(
                          title: "I'm a Client",
                          subtitle: "I want to hire talent for my projects",
                          role: "client",
                          mainColor: skyBlue,
                          icon: Icons.business_center_rounded,
                        ),

                        const SizedBox(height: 20),

                        // CARTE POUR LE RÔLE FREELANCER
                        _premiumRoleCard(
                          title: "I'm a Freelancer",
                          subtitle: "I'm looking for work and AI opportunities",
                          role: "freelancer",
                          mainColor: mintCrystal,
                          icon: Icons.bolt_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PERSONNALISÉ POUR LES CARTES DE RÔLE ---
  Widget _premiumRoleCard({
    required String title,
    required String subtitle,
    required String role,
    required Color mainColor,
    required IconData icon,
  }) {
    bool isSelected = selectedRole == role; // Vérifie si cette carte est celle sélectionnée

    return GestureDetector( // Détecte les interactions de l'utilisateur
      onTapDown: (_) => setState(() => selectedRole = role), // Met à jour l'état visuel immédiatement au toucher
      onTap: () async {
        // Petit délai pour laisser l'animation de clic se terminer avant de naviguer
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(role: role, email: '')), // Passe le rôle à la page suivante
        );
      },
      child: AnimatedScale( // Animation de zoom/réduction lors du clic
        scale: isSelected ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer( // Animation de la bordure et de l'ombre
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? mainColor : Colors.transparent, // Bordure colorée si sélectionné
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected 
                    ? mainColor.withValues(alpha: 0.3) 
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row( // Organisation horizontale du contenu de la carte
            children: [
              // CONTENEUR DE L'ICÔNE
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient( // Dégradé léger pour l'icône
                    colors: [mainColor.withValues(alpha: 0.2), mainColor.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: mainColor, size: 30),
              ),
              const SizedBox(width: 20),
              // TEXTES (TITRE ET SOUS-TITRE)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: darkText.withValues(alpha: 0.5),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // INDICATEUR CIRCULAIRE (RADIO BUTTON CUSTOM)
              Container(
                height: 24,
                width: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? mainColor : Colors.grey.shade300,
                    width: isSelected ? 7 : 2, // Épaissit la bordure quand sélectionné
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MÉTHODE UTILITAIRE POUR CRÉER LES FORMES D'ARRIÈRE-PLAN
  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}