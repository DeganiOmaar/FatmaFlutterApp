import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/controllers/main_tab_controller.dart';
import 'package:pfe/controllers/wallet_balance_controller.dart';
import 'package:pfe/constants/job_skills.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/home_service.dart';

/// Full-screen flow for clients posting a new mission (replaces modal/sheet).
class CreateMissionScreen extends StatefulWidget {
  final String clientEmail;

  const CreateMissionScreen({
    super.key,
    required this.clientEmail,
  });

  @override
  State<CreateMissionScreen> createState() => _CreateMissionScreenState();
}

class _CreateMissionScreenState extends State<CreateMissionScreen> {
  final HomeService _homeService = HomeService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _budget = TextEditingController();
  final TextEditingController _customMissionSkill = TextEditingController();

  final List<String> _missionSkills = [];

  static const Color _purple = Color(0xFF8E2DE2);
  static const Color _purpleSoft = Color(0xFFF5F0FF);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _pageBg = Color(0xFFF1F5F9);

  bool _submitting = false;

  String get _emailNorm => widget.clientEmail.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<WalletBalanceController>().refreshFromApi();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _budget.dispose();
    _customMissionSkill.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_submitting) return;

    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      Get.snackbar("Erreur", "Remplis le titre et la description");
      return;
    }

    final token = await AuthService.getToken();
    if (token == null) return;

    final budgetVal =
        double.tryParse(_budget.text.replaceAll(',', '.')) ?? 0;
    if (budgetVal <= 0) {
      Get.snackbar("Erreur", "Indique un budget valide en €");
      return;
    }

    final currentBal = Get.find<WalletBalanceController>().balanceEu.value;
    if (currentBal != null && budgetVal > currentBal) {
      Get.snackbar(
        "Solde insuffisant",
        "Ton wallet (${currentBal.toStringAsFixed(2)} €) est inférieur au budget. Recharge depuis Profil.",
      );
      return;
    }

    setState(() => _submitting = true);
    final err = await _homeService.addProject({
      "title": _title.text.trim(),
      "description": _desc.text.trim(),
      "budget": budgetVal,
      "clientEmail": _emailNorm,
      "requiredSkills": List<String>.from(_missionSkills),
    }, token);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (err == null) {
      _title.clear();
      _desc.clear();
      _budget.clear();
      _missionSkills.clear();
      _customMissionSkill.clear();
      await Get.find<WalletBalanceController>().refreshFromApi();

      if (Get.isRegistered<MainTabController>()) {
        await Get.find<MainTabController>().afterMissionPublished();
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      Get.snackbar(
        "Succès",
        "Mission publiée !",
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar("Erreur", err);
    }
  }

  void _addCustomMissionSkill() {
    final s = _customMissionSkill.text.trim();
    if (s.isEmpty) return;
    if (_missionSkills.contains(s)) {
      _customMissionSkill.clear();
      return;
    }
    if (_missionSkills.length >= kMaxMissionRequiredSkills) {
      Get.snackbar(
        'Limite',
        'Maximum $kMaxMissionRequiredSkills compétences pour cette mission.',
      );
      return;
    }
    setState(() {
      _missionSkills.add(s);
      _customMissionSkill.clear();
    });
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    final radius = BorderRadius.circular(14);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _slate600,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 15,
        color: _slate600.withValues(alpha: 0.55),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _slate200, width: 1.25),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _purple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  Widget _walletBanner(double? bal) {
    final loading = bal == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_purpleSoft, Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: _purple.withValues(alpha: 0.9),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solde disponible',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: _slate600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Chargement du solde…'
                      : '${bal.toStringAsFixed(2)} €',
                  style: GoogleFonts.poppins(
                    fontSize: loading ? 15 : 22,
                    fontWeight: FontWeight.w700,
                    color: loading ? _slate600 : _slate900,
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ce montant sera prélevé sur ton wallet à la publication.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: _slate600.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: _slate900,
                    tooltip: 'Retour',
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouvelle mission',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _slate900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Présente ton besoin clairement pour recevoir des propositions pertinentes.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.45,
                            color: _slate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Obx(() {
                final bal =
                    Get.find<WalletBalanceController>().balanceEu.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _walletBanner(bal),
                    const SizedBox(height: 28),
                    Text(
                      'Détails de la mission',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _slate900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu pourras modifier certaines informations plus tard si besoin.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _slate600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _slate200.withValues(alpha: 0.85)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _title,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _slate900,
                            ),
                            decoration: _decoration(
                              label: 'Titre',
                              hint: 'Ex. Application mobile iOS & Android',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _desc,
                            maxLines: 5,
                            minLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              height: 1.5,
                              color: _slate900,
                            ),
                            decoration: _decoration(
                              label: 'Description',
                              hint:
                                  'Contexte, livrables attendus, délais, stack technique…',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _budget,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _slate900,
                            ),
                            decoration: _decoration(
                              label: 'Budget',
                              hint: '0.00',
                              suffix: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Align(
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'EUR',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _purple,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Compétences recherchées',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _slate900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Optionnel — sélectionne jusqu’à $kMaxMissionRequiredSkills compétences (développement, design, marketing, etc.).',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _slate600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _slate200.withValues(alpha: 0.85),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: kJobSkillsCatalog.map((skill) {
                              final sel = _missionSkills.contains(skill);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (sel) {
                                      _missionSkills.remove(skill);
                                    } else if (_missionSkills.length <
                                        kMaxMissionRequiredSkills) {
                                      _missionSkills.add(skill);
                                    } else {
                                      Get.snackbar(
                                        'Limite',
                                        'Maximum $kMaxMissionRequiredSkills compétences.',
                                      );
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? _purpleSoft
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: sel
                                          ? _purple.withValues(alpha: 0.35)
                                          : _slate200,
                                    ),
                                  ),
                                  child: Text(
                                    skill,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: sel ? _purple : _slate600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customMissionSkill,
                                  style: GoogleFonts.inter(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Ajouter une autre compétence…',
                                    hintStyle: GoogleFonts.inter(
                                      color:
                                          _slate600.withValues(alpha: 0.5),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: _slate200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: _slate200),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addCustomMissionSkill(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: _purple,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _missionSkills.length >=
                                        kMaxMissionRequiredSkills
                                    ? null
                                    : _addCustomMissionSkill,
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                          if (_missionSkills
                              .any((x) => !kJobSkillsCatalog.contains(x))) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _missionSkills
                                  .where((x) =>
                                      !kJobSkillsCatalog.contains(x))
                                  .map(
                                    (s) => Chip(
                                      label: Text(
                                        s,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      deleteIcon:
                                          const Icon(Icons.close, size: 18),
                                      onDeleted: () => setState(
                                        () => _missionSkills.remove(s),
                                      ),
                                      backgroundColor: _purpleSoft,
                                      side: BorderSide(
                                        color: _purple
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (_missionSkills.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                '${_missionSkills.length}/$kMaxMissionRequiredSkills sélectionnées',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _slate600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24 + bottomInset),
                  ],
                );
              }),
            ),
          ),
          Material(
            elevation: 12,
            shadowColor: Colors.black26,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _submitting ? null : () => Get.back(),
                      style: TextButton.styleFrom(
                        foregroundColor: _slate600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _publish,
                        style: FilledButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _purple.withValues(alpha: 0.45),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _submitting
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Publier la mission',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
