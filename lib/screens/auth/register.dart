import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/service/api_service.dart';
import 'package:pfe/constants/job_skills.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String email;
  final String role;

  const RegisterScreen({super.key, required this.email, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final Color mintCrystal = const Color(0xFF81E38F);
  final Color skyBlue = const Color(0xFF74C0FC);
  final Color backgroundLight = const Color(0xFFF9FBFF);
  final Color darkText = const Color(0xFF1A1C1E);

  // Controllers
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final confirmPassC = TextEditingController();
  final bioC = TextEditingController();
  final specialityC = TextEditingController();
  final rateC = TextEditingController();
  final _customSkillCtrl = TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool loading = false;

  // Compétences (max [kMaxFreelancerSkills] — même catalogue que les missions)
  final List<String> _selectedSkills = [];

  // Langues
  final List<String> _languages = ['Arabe', 'Français', 'Anglais'];
  final List<String> _selectedLanguages = [];

  @override
  void initState() {
    super.initState();
    emailC.text = widget.email;
  }

  @override
  void dispose() {
    nameC.dispose();
    emailC.dispose();
    passC.dispose();
    confirmPassC.dispose();
    bioC.dispose();
    specialityC.dispose();
    rateC.dispose();
    _customSkillCtrl.dispose();
    super.dispose();
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (passC.text != confirmPassC.text) {
      Get.snackbar("Erreur ", "Les mots de passe ne correspondent pas",
          backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
          colorText: Colors.white);
      return;
    }

    if (widget.role == "freelancer" &&
        (_selectedSkills.isEmpty ||
            _selectedSkills.length > kMaxFreelancerSkills)) {
      Get.snackbar(
          "Erreur",
          _selectedSkills.isEmpty
              ? "Sélectionne entre 1 et $kMaxFreelancerSkills compétences"
              : "Maximum $kMaxFreelancerSkills compétences",
          backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
          colorText: Colors.white);
      return;
    }

    Map<String, dynamic> userData = {
      "name": nameC.text.trim(),
      "email": emailC.text.trim().toLowerCase(),
      "password": passC.text,
      "role": widget.role,
      "bio": widget.role == "freelancer" ? bioC.text.trim() : "",
      "speciality": widget.role == "freelancer" ? specialityC.text.trim() : "",
      "skills": widget.role == "freelancer" ? _selectedSkills : [],
      "hourlyRate": widget.role == "freelancer" ? rateC.text.trim() : "",
      "languages": widget.role == "freelancer" ? _selectedLanguages : [],
    };

    setState(() => loading = true);
    try {
      await ApiService.register(userData);

      if (!mounted) return;

      Get.snackbar("Presque fini ! ", "Un code de vérification a été envoyé.",
          backgroundColor: mintCrystal.withValues(alpha: 0.9),
          colorText: Colors.white);

      Get.to(() => OTPVerificationScreen(
            email: emailC.text.trim(),
            isFromRegister: true,
            role: widget.role,
          ));
    } catch (e) {
      if (!mounted) return;
      Get.snackbar("Erreur ", e.toString().replaceAll("Exception: ", ""),
          backgroundColor:Colors.redAccent.withValues(alpha: 0.8),
          colorText: Colors.white);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFreelancer = widget.role == "freelancer";

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
              // Titre
              Text(
                isFreelancer ? "Join as\nExpert " : "Start as\nClient ",
                style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                    height: 1.1),
              ),
              const SizedBox(height: 10),
              Text(
                "Créez votre compte pour commencer l'aventure.",
                style: GoogleFonts.inter(
                    color: Colors.grey[600], fontSize: 15),
              ),
              const SizedBox(height: 35),

              // Nom
              _buildModernField(
                controller: nameC,
                hint: "Nom Complet",
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.isEmpty ? "Nom requis" : null,
              ),
              const SizedBox(height: 20),

              // Email
              _buildModernField(
                controller: emailC,
                hint: "Adresse Email",
                icon: Icons.alternate_email_rounded,
                validator: (v) =>
                    v == null || !v.contains("@") ? "Email invalide" : null,
              ),
              const SizedBox(height: 20),

              // Mot de passe
              _buildModernField(
                controller: passC,
                hint: "Mot de passe",
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                hidePass: hidePassword,
                togglePass: () =>
                    setState(() => hidePassword = !hidePassword),
                validator: (v) => v == null || v.length < 6
                    ? "Minimum 6 caractères"
                    : null,
              ),
              const SizedBox(height: 20),

              // Confirmation
              _buildModernField(
                controller: confirmPassC,
                hint: "Confirmer le mot de passe",
                icon: Icons.lock_reset_rounded,
                isPassword: true,
                hidePass: hideConfirmPassword,
                togglePass: () => setState(
                    () => hideConfirmPassword = !hideConfirmPassword),
                validator: (v) =>
                    v != passC.text ? "Mots de passe différents" : null,
              ),

              // ===========================
              // CHAMPS FREELANCER
              // ===========================
              if (isFreelancer) ...[
                const SizedBox(height: 28),
                _sectionDivider("Profil professionnel"),
                const SizedBox(height: 16),

                // Spécialité
                _buildModernField(
                  controller: specialityC,
                  hint: "Spécialité (ex: Développeur Flutter)",
                  icon: Icons.work_outline,
                  validator: (v) => v == null || v.isEmpty
                      ? "Spécialité requise"
                      : null,
                ),
                const SizedBox(height: 20),

                // Bio
                _buildModernField(
                  controller: bioC,
                  hint: "Biographie courte...",
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                  validator: (v) =>
                      v == null || v.isEmpty ? "Bio requise" : null,
                ),
                const SizedBox(height: 20),

                // Taux horaire
                _buildModernField(
                  controller: rateC,
                  hint: "Taux horaire (DT/heure) — optionnel",
                  icon: Icons.payments_outlined,
                  type: TextInputType.number,
                  validator: null,
                ),
                const SizedBox(height: 28),

                // Compétences
                _sectionDivider("Compétences"),
                const SizedBox(height: 12),
                Text(
                  "Choisis jusqu’à $kMaxFreelancerSkills compétences (domaines variés : dev, design, marketing…)",
                  style: GoogleFonts.inter(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kJobSkillsCatalog.map((skill) {
                    final isSelected = _selectedSkills.contains(skill);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedSkills.remove(skill);
                          } else if (_selectedSkills.length <
                              kMaxFreelancerSkills) {
                            _selectedSkills.add(skill);
                          } else {
                            Get.snackbar(
                              "Limite",
                              "Maximum $kMaxFreelancerSkills compétences — retire-en une pour en ajouter une autre.",
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? skyBlue.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: isSelected
                                ? skyBlue
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(skill,
                                style: GoogleFonts.inter(
                                    color: isSelected
                                        ? const Color(0xFF185FA5)
                                        : Colors.grey.shade700,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.check_circle,
                                  color: skyBlue, size: 14),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Compétence personnalisée
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _customSkillCtrl,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Ajouter une compétence...",
                            hintStyle: GoogleFonts.inter(
                                color: Colors.grey.shade400,
                                fontSize: 14),
                            prefixIcon: Icon(
                                Icons.add_circle_outline,
                                color: skyBlue,
                                size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        final skill = _customSkillCtrl.text.trim();
                        if (skill.isEmpty) return;
                        if (_selectedSkills.contains(skill)) return;
                        if (_selectedSkills.length >= kMaxFreelancerSkills) {
                          Get.snackbar(
                            "Limite",
                            "Maximum $kMaxFreelancerSkills compétences.",
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          return;
                        }
                        setState(() {
                          _selectedSkills.add(skill);
                          _customSkillCtrl.clear();
                        });
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: skyBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Langues
                _sectionDivider("Langues parlées"),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _languages.map((lang) {
                    final isSelected = _selectedLanguages.contains(lang);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedLanguages.remove(lang);
                          } else {
                            _selectedLanguages.add(lang);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? mintCrystal.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: isSelected
                                ? mintCrystal
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(lang,
                                style: GoogleFonts.inter(
                                    color: isSelected
                                        ? const Color(0xFF0F6E56)
                                        : Colors.grey.shade700,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.check_circle,
                                  color: mintCrystal, size: 14),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 40),
              _buildSubmitButton(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Section divider avec titre
  Widget _sectionDivider(String title) {
    return Row(
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkText)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool? hidePass,
    VoidCallback? togglePass,
    int maxLines = 1,
    TextInputType type = TextInputType.text,
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
              offset: const Offset(0, 8)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? (hidePass ?? true) : false,
        maxLines: isPassword ? 1 : maxLines,
        keyboardType: type,
        validator: validator,
        style: GoogleFonts.inter(
            color: darkText, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: skyBlue, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    (hidePass ?? true)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: togglePass,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 20, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return InkWell(
      onTap: loading ? null : _doRegister,
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
                offset: const Offset(0, 10)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(
                  "CRÉER MON COMPTE",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1),
                ),
        ),
      ),
    );
  }
}