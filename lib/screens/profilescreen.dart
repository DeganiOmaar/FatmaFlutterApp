import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:pfe/Model/User.dart';
import 'package:pfe/screens/ChangePasswordScreen.dart';

import 'package:pfe/screens/auth/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pfe/controllers/wallet_balance_controller.dart';
import 'package:pfe/screens/walletScreen.dart';
import 'package:pfe/screens/create_mission_screen.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/user_service.dart';

class ProfileScreen extends StatefulWidget {
  final String email;

  const ProfileScreen({super.key, required this.email});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService    userService    = UserService();

  // ── Lancy colors ─────────────────────────────────────
  final Color mintCrystal    = const Color(0xFF81E38F);
  final Color skyBlue        = const Color(0xFF74C0FC);
  final Color darkText       = const Color(0xFF1A1C1E);
  final Color backgroundLight = const Color(0xFFF9FBFF);

  late Future<UserModel> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = userService.fetchProfile(widget.email.trim());
  }

  void _reloadProfile() {
    setState(() {
      _profileFuture = userService.fetchProfile(widget.email.trim());
    });
  }

  // ── Helpers ───────────────────────────────────────────
  String _initialFor(UserModel user) {
    final n = user.name?.trim();
    if (n != null && n.isNotEmpty) return n[0].toUpperCase();
    final e = user.email.trim();
    if (e.isNotEmpty) return e[0].toUpperCase();
    return '?';
  }

  String _roleLabel(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'client':     return 'Client';
      case 'freelancer': return 'Freelancer';
      default:           return role?.toUpperCase() ?? 'UTILISATEUR';
    }
  }

  InputDecoration _sheetInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: skyBlue, size: 22),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: skyBlue, width: 2)),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  // ── Logout ────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
            "Tu seras renvoyé à l'écran de connexion. Continuer ?",
            style: GoogleFonts.inter(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade700)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: skyBlue,
                foregroundColor: Colors.white),
            child: Text('Se déconnecter',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── Edit profile dialog ───────────────────────────────
  void _showEditProfileDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final bioCtrl  = TextEditingController(text: user.bio ?? '');

    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text("Modifier le profil",
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                  controller: nameCtrl,
                  decoration: _sheetInputDecoration(
                      "Nom", Icons.person_outline)),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                decoration:
                    _sheetInputDecoration("Bio", Icons.notes_rounded),
              ),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (sheetCtx, setSheetState) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: skyBlue,
                      disabledBackgroundColor: skyBlue.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            final result = await userService.updateProfile(
                              email: user.email,
                              name: nameCtrl.text,
                              bio: bioCtrl.text,
                            );
                            if (!sheetCtx.mounted) return;
                            setSheetState(() => saving = false);
                            if (!result.ok) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.error ??
                                        "Impossible d'enregistrer le profil",
                                    style: GoogleFonts.inter(),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(sheetCtx);
                            if (!mounted) return;
                            _reloadProfile();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Profil mis à jour ✅",
                                  style: GoogleFonts.inter(),
                                ),
                                backgroundColor: mintCrystal,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                    child: saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            "Enregistrer",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateMission() {
    Get.to<bool>(
      () => CreateMissionScreen(
        clientEmail: widget.email.trim().toLowerCase(),
      ),
    );
  }

  // ── Avatar upload ─────────────────────────────────────
  Future<void> _pickAndUploadImage(UserModel user) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 500,
    );
    if (picked == null) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Upload en cours...", style: GoogleFonts.inter()),
      backgroundColor: skyBlue,
      behavior: SnackBarBehavior.floating,
    ));

    final url = await userService.uploadAvatar(
      email: widget.email,
      filePath: picked.path,
    );

    if (!mounted) return;
    if (url != null) {
      _reloadProfile();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Photo mise à jour ✅", style: GoogleFonts.inter()),
        backgroundColor: mintCrystal,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Erreur upload ❌", style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: backgroundLight,
      body: FutureBuilder<UserModel>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: skyBlue, strokeWidth: 3));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorBody();
          }
          final user = snapshot.data!;
          final isFreelancer = user.role == 'freelancer';
          final isClient     = user.role == 'client';

          return RefreshIndicator(
            color: skyBlue,
            onRefresh: () async {
              final f = userService.fetchProfile(widget.email.trim());
              setState(() => _profileFuture = f);
              try { await f; } catch (_) {}
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: _buildHeader(context, user, topPad)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Stats ──────────────────────────
                      _buildStatsCard(user),
                      const SizedBox(height: 16),

                      // ── Contact ────────────────────────
                      _buildContactCard(user),
                      const SizedBox(height: 16),

                      // ── Bio ────────────────────────────
                      _buildAboutCard(user),

                      // ── Spécialité (freelancer) ────────
                      if (isFreelancer &&
                          (user.speciality?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 16),
                        _buildSpecialityCard(user.speciality!.trim()),
                      ],

                      // ── FREELANCER ONLY ────────────────
                      if (isFreelancer) ...[
                        const SizedBox(height: 16),
                        _buildSkillsSection(user),
                        const SizedBox(height: 20),
                        // ✅ Wallet card — freelancer uniquement
                        _buildWalletCard(),
                      ],

                      // ── CLIENT ONLY ────────────────────
                      if (isClient) ...[
                        const SizedBox(height: 20),
                        _buildClientWalletCard(),
                        const SizedBox(height: 20),
                        _buildSectionLabel('Mes actions'),
                        const SizedBox(height: 12),
                        _buildPrimaryCta(
                          label: 'Poster une nouvelle mission',
                          icon: Icons.add_circle_outline_rounded,
                          onTap: _openCreateMission,
                        ),
                      ],

                      // ── Sécurité ───────────────────────
                      const SizedBox(height: 28),
                      _buildSectionLabel('Sécurité'),
                      const SizedBox(height: 10),
                      _buildSecurityCard(),

                      // ── Déconnexion ────────────────────
                      const SizedBox(height: 20),
                      _buildSectionLabel('Connexion'),
                      const SizedBox(height: 10),
                      _buildLoginOutCard(),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // WIDGETS
  // ══════════════════════════════════════════════════════

  // ── Header ────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, UserModel user, double topPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          top: topPad + 8, left: 8, right: 20, bottom: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skyBlue, const Color(0xFF5BA9E8), mintCrystal],
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: skyBlue.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 8),

          // Avatar
          GestureDetector(
            onTap: () => _pickAndUploadImage(user),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        (user.avatar != null && user.avatar!.isNotEmpty)
                            ? NetworkImage(user.avatar!)
                            : null,
                    onBackgroundImageError:
                        (user.avatar != null && user.avatar!.isNotEmpty)
                            ? (_, _) {}
                            : null,
                    child: (user.avatar == null || user.avatar!.isEmpty)
                        ? Text(_initialFor(user),
                            style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: skyBlue))
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: skyBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(user.displayName,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15)),
          const SizedBox(height: 6),
          Text(user.email,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 14),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Text(_roleLabel(user.role),
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.white)),
          ),
          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(user),
            icon:
                const Icon(Icons.edit, size: 16, color: Colors.white),
            label: Text("Modifier le profil",
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────
  Widget _buildStatsCard(UserModel user) {
    final isClient = user.role == 'client';
    return Row(
      children: [
        Expanded(
          child: _statTile(
            value: isClient
                ? "${user.projectCount ?? 0}"
                : "${user.proposalCount ?? 0}",
            label: isClient ? "Projets publiés" : "Propositions",
            color: skyBlue,
            icon: isClient
                ? Icons.work_outline
                : Icons.send_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            value: isClient ? "0" : "${user.wonCount ?? 0}",
            label: isClient
                ? "Missions terminées"
                : "Missions gagnées",
            color: mintCrystal,
            icon: Icons.emoji_events_outlined,
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildClientWalletCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Mon wallet (€)'),
        const SizedBox(height: 10),
        Obx(() {
          final bal = Get.find<WalletBalanceController>().balanceEu.value;
          return GestureDetector(
            onTap: () async {
              await Get.to(() => const WalletScreen(forClient: true));
              await Get.find<WalletBalanceController>().refreshFromApi();
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [skyBlue, mintCrystal]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: skyBlue.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_card_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Solde pour tes missions",
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13),
                        ),
                        Text(
                          bal == null
                              ? "Chargement..."
                              : "${bal.toStringAsFixed(2)} €",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "Appuie pour recharger par carte (Stripe)",
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Wallet card (freelancer only) ─────────────────────
  Widget _buildWalletCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: userService.getWallet(),
      builder: (context, snap) {
        final balance = snap.data?['balance'] ?? 0;
        final txCount =
            (snap.data?['transactions'] as List?)?.length ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Mon Wallet 💰'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Get.to(() => const WalletScreen(forClient: false)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [skyBlue, mintCrystal]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: skyBlue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Solde disponible",
                              style: GoogleFonts.inter(
                                  color:
                                      Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13)),
                          Text(
                            snap.connectionState ==
                                    ConnectionState.waiting
                                ? "Chargement..."
                                : "$balance €",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "$txCount mission${txCount != 1 ? 's' : ''} complétée${txCount != 1 ? 's' : ''}",
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Contact ───────────────────────────────────────────
  Widget _buildContactCard(UserModel user) {
    return _surfaceCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: skyBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.alternate_email_rounded,
                color: skyBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('E-mail',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(user.email,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: darkText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── About ─────────────────────────────────────────────
  Widget _buildAboutCard(UserModel user) {
    final bio  = (user.bio ?? '').trim();
    final text = bio.isEmpty
        ? 'Aucune bio disponible pour le moment.'
        : bio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('À propos'),
        const SizedBox(height: 10),
        _surfaceCard(
          accent: true,
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: bio.isEmpty
                      ? Colors.grey.shade600
                      : darkText)),
        ),
      ],
    );
  }

  // ── Speciality ────────────────────────────────────────
  Widget _buildSpecialityCard(String speciality) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Spécialité'),
        const SizedBox(height: 10),
        _surfaceCard(
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  color: mintCrystal),
              const SizedBox(width: 12),
              Expanded(
                child: Text(speciality,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: darkText)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Skills ────────────────────────────────────────────
  Widget _buildSkillsSection(UserModel user) {
    final skills = user.skills ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Compétences'),
        const SizedBox(height: 10),
        if (skills.isEmpty)
          _surfaceCard(
            child: Text('Aucune compétence renseignée.',
                style: GoogleFonts.inter(
                    color: Colors.grey.shade600, fontSize: 15)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: skyBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: skyBlue.withValues(alpha: 0.25)),
                      ),
                      child: Text(s,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C5F8C),
                              fontSize: 13)),
                    ))
                .toList(),
          ),
      ],
    );
  }

  // ── Security ──────────────────────────────────────────
  Widget _buildSecurityCard() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: skyBlue, size: 22),
              const SizedBox(width: 10),
              Text("Mot de passe",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: darkText)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Modifie ton mot de passe pour sécuriser ton compte.",
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Get.to(
                  () => ChangePasswordScreen(email: widget.email)),
              icon: Icon(Icons.lock_reset_rounded,
                  color: skyBlue, size: 18),
              label: Text("Changer le mot de passe",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: skyBlue)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: skyBlue),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logout card ───────────────────────────────────────
  Widget _buildLoginOutCard() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.login_rounded, color: skyBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Déconnecte-toi pour te reconnecter avec un autre compte.',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: Icon(Icons.logout_rounded,
                  color: Colors.red.shade700),
              label: Text('Se déconnecter',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Primary CTA ───────────────────────────────────────
  Widget _buildPrimaryCta({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [skyBlue, mintCrystal]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: skyBlue.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error body ────────────────────────────────────────
  Widget _buildErrorBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Impossible de charger le profil',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: darkText)),
            const SizedBox(height: 8),
            Text('Vérifie ta connexion et réessaie.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _reloadProfile,
              style: FilledButton.styleFrom(
                backgroundColor: skyBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Réessayer',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────
  Widget _buildSectionLabel(String title) {
    return Text(title,
        style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: darkText));
  }

  // ── Surface card ──────────────────────────────────────
  Widget _surfaceCard({required Widget child, bool accent = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (accent)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [skyBlue, mintCrystal],
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      accent ? 14 : 18, 18, 18, 18),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}