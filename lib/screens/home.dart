import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pfe/screens/ProfileScreen.dart';
import 'package:pfe/screens/chat_screen.dart';
import 'package:pfe/screens/notifications_screen.dart';
import 'package:pfe/screens/proposals_list_screen.dart';
import 'package:pfe/screens/send_proposal_screen.dart';
import 'package:pfe/screens/create_mission_screen.dart';
import 'package:pfe/screens/lancy_assistant_screen.dart';
import 'package:pfe/service/home_service.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/project_service.dart'; // Assure-toi que ce fichier contient update et delete
import 'package:pfe/service/user_service.dart';
import 'package:pfe/controllers/wallet_balance_controller.dart';
import 'package:pfe/controllers/main_tab_controller.dart';
import 'package:pfe/config/api_config.dart';
import 'package:pfe/constants/job_skills.dart';
import 'package:pfe/controllers/app_socket_controller.dart';

class HomeScreen extends StatefulWidget {
  final String email;
  final String role;
  final String? name;

  const HomeScreen({
    super.key,
    required this.email,
    required this.role,
    this.name,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ✅ Ajoute cette variable
  int _notificationCount = 0;
  String? _avatarUrl;
  final HomeService homeService = HomeService();
  final UserService _userService = UserService();
  final Color skyBlue = const Color(0xFF74C0FC);
  final Color mintCrystal = const Color(0xFF81E38F);
  final Color lancyPurple = const Color(0xFF8E2DE2);
  static const Color _cardBorder = Color(0xFFE8ECF2);
  static const Color _slateText = Color(0xFF475569);

  /// Not [late]: hot reload does not re-run [initState], which caused LateInitializationError.
  Future<List<dynamic>>? _projectsFuture;
  bool hasNotification = false;
  List<Map<String, dynamic>> notificationHistory = [];
  late final void Function(Map<String, dynamic>) _proposalSocketHandler;

  final TextEditingController _freelancerSearchCtrl = TextEditingController();
  bool _freelancerShowAllMissions = true;
  Set<String> _mySkillsNormalized = {};

  //socket ??= IO.io('http://192.168.1.100:5001', <String, dynamic>
  @override
  void initState() {
    super.initState();
    _proposalSocketHandler = _onProposalSocketFromServer;
    _ensureProjectsFuture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachProposalSocketBridge();
      _loadNotificationCount();
      _loadUserAvatar();
      _loadClientWalletIfNeeded();
      _registerMainTabRefresh();
      _loadFreelancerSkillsForMatching();
    });
  }

  void _attachProposalSocketBridge() {
    AppSocketController.to.onProposalPushHome = _proposalSocketHandler;
  }

  void _onProposalSocketFromServer(Map<String, dynamic> data) {
    if (!mounted) return;
    if (kDebugMode) debugPrint('🔔 SIGNAL REÇU !');
    setState(() {
      hasNotification = true;
      _notificationCount++;
      notificationHistory.insert(0, Map<String, dynamic>.from(data));
    });
  }

  Future<void> _loadClientWalletIfNeeded() async {
    if (widget.role != 'client') return;
    await Get.find<WalletBalanceController>().refreshFromApi();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final token = await AuthService.getToken();
      
      if (token == null) return;
      final response = await http.get(
        Uri.parse("${ApiConfig.baseURL}/notifications"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final unread = data.where((n) => n['read'] == false).length;
        if (mounted) {
          setState(() {
            _notificationCount = unread;
            hasNotification = unread > 0;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur notif count: $e");
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Only invoked during debug hot reload — re-bind future because [initState] does not run again.
    _projectsFuture = _loadProjectsList();
    _attachProposalSocketBridge();
  }

  void _ensureProjectsFuture() {
    _projectsFuture ??= _loadProjectsList();
  }

  Future<List<dynamic>> _loadProjectsList() async {
    final isClient = widget.role.toLowerCase() == 'client';
    return _getProjects(isClient);
  }

  Future<void> _reloadProjects() async {
    setState(() {
      _projectsFuture = _loadProjectsList();
    });
    await _projectsFuture;
  }

  void _registerMainTabRefresh() {
    if (!Get.isRegistered<MainTabController>()) return;
    final tabs = Get.find<MainTabController>();
    if (widget.role.toLowerCase() == 'client') {
      tabs.refreshHomeProjects = () async {
        if (mounted) await _reloadProjects();
      };
    }
    tabs.refreshHomeAvatar = () async {
      if (mounted) await _loadUserAvatar();
    };
  }

  Future<void> _loadUserAvatar() async {
    try {
      final user = await _userService.fetchProfile(widget.email);
      if (!mounted) return;
      final raw = user.avatar?.trim();
      setState(() {
        _avatarUrl = (raw != null && raw.isNotEmpty) ? raw : null;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement avatar: $e');
    }
  }

  String? _resolvedAvatarUrl() {
    final raw = _avatarUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiConfig.origin}/$raw';
  }

  Widget _buildAppBarProfileAvatar() {
    final url = _resolvedAvatarUrl();
    return CircleAvatar(
      radius: 18,
      backgroundColor: skyBlue.withValues(alpha: 0.2),
      backgroundImage: url != null ? NetworkImage(url) : null,
      onBackgroundImageError: url != null ? (_, __) {} : null,
      child: url == null
          ? const Icon(Icons.person, color: Colors.blue, size: 22)
          : null,
    );
  }

  Future<void> _loadFreelancerSkillsForMatching() async {
    if (widget.role.toLowerCase() != 'freelancer') return;
    try {
      final u = await UserService().fetchProfile(widget.email);
      if (!mounted) return;
      final raw = u.skills ?? [];
      setState(() {
        _mySkillsNormalized = raw
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toSet();
      });
    } catch (_) {}
  }

  Set<String> _normalizedSkillSet(dynamic raw) {
    if (raw is! List) return {};
    return raw
        .map((e) => e.toString().trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  List<String> _requiredSkillsLabels(dynamic item) {
    final r = item['requiredSkills'];
    if (r is! List) return [];
    return r.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  bool _projectMatchesFreelancerSkills(dynamic item) {
    final req = _normalizedSkillSet(item['requiredSkills']);
    if (req.isEmpty) return true;
    return req.intersection(_mySkillsNormalized).isNotEmpty;
  }

  bool _projectMatchesSearch(dynamic item, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return true;
    final title = item['title']?.toString().toLowerCase() ?? '';
    final desc = item['description']?.toString().toLowerCase() ?? '';
    final skillsBlob = _requiredSkillsLabels(item).join(' ').toLowerCase();
    return title.contains(query) ||
        desc.contains(query) ||
        skillsBlob.contains(query);
  }

  List<dynamic> _filterFreelancerMissions(List<dynamic> raw) {
    final q = _freelancerSearchCtrl.text;
    var list = raw.where((p) => _projectMatchesSearch(p, q)).toList();
    final showAll =
        _freelancerShowAllMissions || _mySkillsNormalized.isEmpty;
    if (!showAll) {
      list = list.where(_projectMatchesFreelancerSkills).toList();
    }
    return list;
  }

  Widget _buildFreelancerExploreBar() {
    final hasSkills = _mySkillsNormalized.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _freelancerSearchCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Rechercher une mission (titre, description, compétence…)',
              hintStyle:
                  GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: lancyPurple.withValues(alpha: 0.65)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'Pour moi',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  selected: !_freelancerShowAllMissions && hasSkills,
                  onSelected: hasSkills
                      ? (v) {
                          if (!v) return;
                          setState(() => _freelancerShowAllMissions = false);
                        }
                      : null,
                  selectedColor: lancyPurple.withValues(alpha: 0.15),
                  labelStyle: GoogleFonts.inter(
                    color: !_freelancerShowAllMissions && hasSkills
                        ? lancyPurple
                        : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'Toutes les missions',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  selected: _freelancerShowAllMissions || !hasSkills,
                  onSelected: (v) {
                    if (!v) return;
                    setState(() => _freelancerShowAllMissions = true);
                  },
                  selectedColor: skyBlue.withValues(alpha: 0.2),
                  labelStyle: GoogleFonts.inter(
                    color: _freelancerShowAllMissions || !hasSkills
                        ? const Color(0xFF185FA5)
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (!hasSkills)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ajoute jusqu’à $kMaxFreelancerSkills compétences sur ton profil pour activer « Pour moi ».',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<MainTabController>()) {
      final tabs = Get.find<MainTabController>();
      tabs.refreshHomeProjects = null;
      tabs.refreshHomeAvatar = null;
    }
    _freelancerSearchCtrl.dispose();
    final c = AppSocketController.to;
    if (identical(c.onProposalPushHome, _proposalSocketHandler)) {
      c.onProposalPushHome = null;
    }
    super.dispose();
  }

  // ... reste de ton code ...
  String get _emailNorm => widget.email.trim().toLowerCase();

  // --- RÉCUPÉRATION DES DONNÉES ---
  Future<List<dynamic>> _getProjects(bool isClient) async {
    final token = await AuthService.getToken();
    if (token == null) return [];
    // Si client, on récupère ses propres projets, sinon tous les projets (freelancer)
    return isClient
        ? homeService.fetchMyProjects(token)
        : homeService.fetchProjects(authToken: token);
  }

  // --- ACTION : SUPPRESSION ---
  void _confirmDeletion(String projectId) {
    Get.defaultDialog(
      title: "Suppression",
      middleText:
          "Le budget réservé pour cette mission sera recrédité sur votre wallet.",
      textConfirm: "Supprimer",
      textCancel: "Annuler",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        final err = await ProjectService.deleteProject(projectId);
        Get.back();
        if (err == null) {
          await _reloadProjects();
          if (widget.role.toLowerCase() == 'client') {
            await Get.find<WalletBalanceController>().refreshFromApi();
          }
          Get.snackbar(
            "Succès",
            "Projet supprimé — budget rendu sur le wallet",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.white,
          );
        } else {
          Get.snackbar("Impossible", err, snackPosition: SnackPosition.BOTTOM);
        }
      },
    );
  }

  void _showRequestCancellationDialog(String projectId) {
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text(
          "Demander l’annulation",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Un freelancer a été accepté et les fonds sont en escrow. "
                "L’administrateur examinera votre demande. "
                "Si elle est acceptée, le montant vous sera rendu sur le wallet et la mission sera supprimée.",
                style: GoogleFonts.inter(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Motif (optionnel)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Fermer")),
          FilledButton(
            onPressed: () async {
              final err = await ProjectService.requestMissionCancellation(
                projectId,
                reason: reasonCtrl.text.trim(),
              );
              Get.back();
              if (err == null) {
                await _reloadProjects();
                Get.snackbar(
                  "Envoyé",
                  "Demande transmise à l’administration",
                  snackPosition: SnackPosition.BOTTOM,
                );
              } else {
                Get.snackbar("Erreur", err, snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: const Text("Envoyer la demande"),
          ),
        ],
      ),
    );
  }

  // --- ACTION : MODIFICATION ---
  void _showEditProjectDialog(BuildContext context, dynamic item) {
    final title = TextEditingController(text: item["title"]);
    final desc = TextEditingController(text: item["description"]);
    final budget = TextEditingController(text: item["budget"].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Modifier la Mission",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(title, "Titre du projet", Icons.title),
              const SizedBox(height: 12),
              _buildDialogField(
                desc,
                "Description",
                Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                budget,
                "Budget (DT)",
                Icons.monetization_on,
                isNumber: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: skyBlue,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              try {
                await ProjectService.updateProject(item["_id"], {
                  "title": title.text,
                  "description": desc.text,
                  "budget": budget.text,
                });
                if (context.mounted) Navigator.pop(context);
                _reloadProjects();
                Get.snackbar("Succès", "Projet mis à jour");
              } catch (e) {
                Get.snackbar("Erreur", "Échec de la mise à jour");
              }
            },
            child: const Text(
              "Enregistrer",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLancyAssistantFab({required String heroTag}) {
    final isClient = widget.role.toLowerCase() == 'client';
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: 'Lancy Assistant',
      onPressed: () async {
        final token = await AuthService.getToken();
        if (!mounted || token == null || token.isEmpty) return;
        Get.to(
          () => LancyAssistantScreen(
            token: token,
            role: widget.role,
            userName: widget.name,
          ),
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 4,
      mini: isClient,
      child: Container(
        width: isClient ? 40 : 56,
        height: isClient ? 40 : 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [skyBlue, mintCrystal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: mintCrystal.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: isClient ? 22 : 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureProjectsFuture();
    bool isClient = widget.role.toLowerCase() == "client";

    return Scaffold(
       extendBody: true,
  resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8F9FA),

      appBar: AppBar(
        title: Text(
          "LANCY",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => hasNotification = false);
                    _notificationCount = 0;
                    Get.to(() => const NotificationsScreen());
                     _loadNotificationCount();
                  },
                  icon: Icon(
                    Icons.notifications_rounded,
                    size: 28,
                    color: hasNotification
                        ? const Color(0xFF2196F3)
                        : Colors.grey.shade500,
                  ),
                ),
                if (hasNotification && _notificationCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          _notificationCount > 9
    ? "9+"
    : "$_notificationCount",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Get.to(() => ProfileScreen(email: widget.email));
              if (mounted) await _loadUserAvatar();
            },
            icon: _buildAppBarProfileAvatar(),
          ),
        ],
      ),
      floatingActionButton: isClient
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildLancyAssistantFab(heroTag: 'lancy_assistant_fab_client'),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'client_post_mission_fab',
                  backgroundColor: lancyPurple,
                  onPressed: () => Get.to<bool>(
                        () => CreateMissionScreen(clientEmail: _emailNorm),
                      ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Poster",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : _buildLancyAssistantFab(heroTag: 'lancy_assistant_fab'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (!isClient) _buildFreelancerExploreBar(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: lancyPurple),
                  );
                }
                final raw = snapshot.data ?? [];
                final data =
                    isClient ? raw : _filterFreelancerMissions(raw);
                if (raw.isEmpty) {
                  return RefreshIndicator(
                    color: lancyPurple,
                    onRefresh: _reloadProjects,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(isClient),
                        ),
                      ],
                    ),
                  );
                }
                if (data.isEmpty) {
                  return RefreshIndicator(
                    color: lancyPurple,
                    onRefresh: _reloadProjects,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildFilteredEmptyFreelancerState(),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: lancyPurple,
                  onRefresh: _reloadProjects,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 4, 16, isClient ? 100 : 24),
                    itemCount: data.length,
                    itemBuilder: (context, index) =>
                        _projectCard(data[index], isClient),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isClient = widget.role.toLowerCase() == 'client';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bonjour, ${widget.name ?? 'Utilisateur'} 👋",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isClient
                ? "Gérez vos missions publiées"
                : "Trouvez votre prochaine mission",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.35,
            ),
          ),
          if (!isClient) ...[
            const SizedBox(height: 10),
            Text(
              "Recherche, filtres par compétences, ou parcours toutes les missions.",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isClient) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isClient
                  ? "Vous n'avez pas encore publié de mission"
                  : "Aucune mission pour le moment",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isClient
                  ? "Utilisez le bouton « Poster » pour attirer des freelances."
                  : "Revenez plus tard ou tirez pour actualiser la liste.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyFreelancerState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_rounded,
                size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "Aucune mission ne correspond",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Essaie une autre recherche, active « Toutes les missions », ou complète tes compétences sur ton profil.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectCard(dynamic item, bool isClient) {
    final bool isAccepted = item["acceptedFreelancer"] != null;

    if (isClient) {
      return _buildClientMissionCard(item, isAccepted);
    }
    return _buildFreelancerMissionCard(item);
  }

  /// Budget projet (nombre entier DT) pour l’API / lecture seule proposition.
  int _budgetAsInt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw.toString()) ?? 0;
  }

  BoxDecoration _missionCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _cardBorder),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  ({String label, Color bg, Color fg}) _statusStyle(String? status) {
    switch ((status ?? 'open').toLowerCase()) {
      case 'open':
        return (
          label: 'Ouverte',
          bg: const Color(0xFFE0F2FE),
          fg: const Color(0xFF0369A1),
        );
      case 'in_progress':
        return (
          label: 'En cours',
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFB45309),
        );
      case 'delivered':
        return (
          label: 'Livrée',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF047857),
        );
      case 'completed':
        return (
          label: 'Terminée',
          bg: const Color(0xFFE5E7EB),
          fg: const Color(0xFF374151),
        );
      default:
        return (
          label: status ?? '—',
          bg: const Color(0xFFF1F5F9),
          fg: _slateText,
        );
    }
  }

  Widget _statusBadge(String? status) {
    final s = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.fg,
        ),
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBudget(dynamic raw) {
    if (raw == null) return '—';
    final n = raw is num ? raw : num.tryParse(raw.toString());
    if (n == null) return '$raw DT';
    final intPart = n.round();
    if ((n - intPart).abs() < 1e-9) {
      return '${NumberFormat.decimalPattern('fr_FR').format(intPart)} DT';
    }
    return '${NumberFormat.decimalPattern('fr_FR').format(n)} DT';
  }

  String _ownerDisplayName(dynamic item) {
    final o = item['owner'];
    if (o is Map) {
      final name = o['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final mail = o['email']?.toString();
      if (mail != null && mail.isNotEmpty) {
        final local = mail.split('@').first;
        return local.isNotEmpty ? local : 'Client';
      }
    }
    return 'Client';
  }

  /// Nom du freelance retenu pour le chat côté client (API populate `acceptedFreelancer`).
  String _acceptedFreelancerChatName(dynamic item) {
    final f = item['acceptedFreelancer'];
    if (f is Map) {
      final name = f['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final mail = f['email']?.toString();
      if (mail != null && mail.isNotEmpty) {
        final local = mail.split('@').first;
        if (local.isNotEmpty) return local;
      }
    }
    final legacy = item['freelancerName']?.toString().trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return 'Freelancer';
  }

  String _postedRelative(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return DateFormat.yMMMd('fr_FR').format(dt);
  }

  String _normalizedUserId(dynamic v) {
    if (v == null) return '';
    if (v is Map) {
      final id = v['_id'] ?? v['id'];
      if (id == null) return '';
      if (id is Map && id[r'$oid'] != null) {
        return id[r'$oid'].toString().trim();
      }
      return id.toString().trim();
    }
    return v.toString().trim();
  }

  Future<void> _openMissionChat(
    dynamic item, {
    required bool isClient,
    required bool isRejected,
    required bool isAccepted,
  }) async {
    if (!isClient && isRejected) {
      Get.snackbar(
        "Accès refusé",
        "Vous ne pouvez plus contacter le client car votre offre a été refusée.",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
      return;
    }
    if (!isClient) {
      final ps = item["userProposalStatus"]?.toString() ?? "none";
      if (ps != "accepted") {
        Get.snackbar(
          "Chat verrouillé",
          "Le client doit accepter votre proposition pour ouvrir la messagerie.",
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange.shade900,
        );
        return;
      }
    }
    if (isClient && !isAccepted) {
      Get.snackbar(
        "Action requise",
        "Vous devez accepter une proposition pour débloquer le chat.",
        backgroundColor: Colors.orange[100],
      );
      return;
    }

    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) return;

    String receiverId = '';
    String receiverName = "Utilisateur";

    if (isClient) {
      final fData = item["acceptedFreelancer"];
      receiverId = _normalizedUserId(fData);
      receiverName = _acceptedFreelancerChatName(item);
    } else {
      final oData = item["owner"];
      receiverId = _normalizedUserId(oData);
      receiverName = (oData is Map) ? (oData["name"] ?? "Client") : "Client";
    }

    if (receiverId.isNotEmpty) {
      Get.to(
        () => ChatScreen(
          currentUserId: currentUserId,
          receiverId: receiverId,
          receiverName: receiverName,
          projectId: item["_id"].toString(),
          isFreelancerMissionChat: !isClient,
        ),
      );
    } else {
      Get.snackbar("Erreur", "Impossible de trouver l'interlocuteur.");
    }
  }

  Widget _buildFreelancerMissionCard(dynamic item) {
    final owner = item['owner'] is Map ? item['owner'] : {};
    final String clientName = owner['name'] ?? "Client";
    final String? clientAvatar = owner['avatar'];
    final title = item["title"] ?? "Sans titre";
    final desc = (item["description"] ?? "").toString();
    final status = item["status"]?.toString();
    final posted = _postedRelative(item["createdAt"]);
    final skills = _requiredSkillsLabels(item);
    final String proposalStatus =
        item["userProposalStatus"]?.toString() ?? "none";
    final bool isRejected = proposalStatus == "rejected";
    final bool hasActiveProposal =
        proposalStatus == "pending" || proposalStatus == "accepted";
    final bool canPostuler = !isRejected && !hasActiveProposal;

    final bool proposalAccepted = proposalStatus == "accepted";
    final chatEnabled = proposalAccepted;
    final chatColor = chatEnabled
        ? const Color(0xFF059669)
        : Colors.grey.withValues(alpha: 0.45);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _missionCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 ICI tu ajoutes le nouveau HEADER (avatar + nom + date + status)
            Row(
              children: [
           CircleAvatar(
  radius: 18,
  backgroundColor: skyBlue.withValues(alpha: 0.2),
  backgroundImage: (clientAvatar != null && clientAvatar.isNotEmpty)
      ? NetworkImage("${ApiConfig.origin}/$clientAvatar")
      : null,
  // ✅ onBackgroundImageError seulement si backgroundImage != null
  onBackgroundImageError: (clientAvatar != null && clientAvatar.isNotEmpty)
      ? (_, _) => debugPrint("❌ Avatar non chargé")
      : null,
  child: (clientAvatar == null || clientAvatar.isEmpty)
      ? Text(
          clientName.isNotEmpty ? clientName[0].toUpperCase() : "?",
          style: const TextStyle(fontSize: 12, color: Colors.blue),
        )
      : null,
),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      posted,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(
                  icon: Icons.payments_outlined,
                  label: _formatBudget(item["budget"]),
                ),
                _metaChip(
                  icon: Icons.person_outline_rounded,
                  label: _ownerDisplayName(item),
                ),
              ],
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.map((s) {
                  final match = _mySkillsNormalized
                      .contains(s.trim().toLowerCase());
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: match
                          ? lancyPurple.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: match
                            ? lancyPurple.withValues(alpha: 0.35)
                            : _cardBorder,
                      ),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: match ? lancyPurple : _slateText,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              desc.isEmpty ? 'Pas de description.' : desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: _slateText,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canPostuler
                        ? () async {
                            final token = await AuthService.getToken();
                            if (token != null && mounted) {
                              final sent = await Get.to<bool>(
                                () => SendProposalScreen(
                                  projectId: item["_id"].toString(),
                                  token: token,
                                  projectTitle:
                                      title?.toString() ?? 'Sans titre',
                                  clientBudget: _budgetAsInt(item["budget"]),
                                ),
                              );
                              if (sent == true && mounted) {
                                await _reloadProjects();
                              }
                            }
                          }
                        : null,
                    icon: Icon(
                      canPostuler ? Icons.send_rounded : Icons.block_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isRejected
                          ? 'Proposition refusée'
                          : hasActiveProposal
                          ? 'Proposition envoyée'
                          : 'Postuler',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: canPostuler
                          ? skyBlue
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: chatEnabled
                      ? const Color(0xFFECFDF5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: chatEnabled
                        ? () => _openMissionChat(
                            item,
                            isClient: false,
                            isRejected: isRejected,
                            isAccepted: item["acceptedFreelancer"] != null,
                          )
                        : null,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: chatColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientMissionCard(dynamic item, bool isAccepted) {
    final title = item["title"] ?? "Sans titre";
    final desc = (item["description"] ?? "").toString();
    final status = item["status"]?.toString();
    final proposalStatus = item["userProposalStatus"] ?? "none";
    final isRejected = proposalStatus == "rejected";
    final paymentStatus = item["paymentStatus"]?.toString() ?? "not_locked";
    final hasAcceptedFreelancer = item["acceptedFreelancer"] != null;
    final escrowLocked = paymentStatus == "escrow_locked";
    final canDirectDelete =
        !hasAcceptedFreelancer && !escrowLocked && status == "open";
    final canRequestCancellation =
        escrowLocked && item["cancellationRequested"] != true;
    final pendingCancellation = item["cancellationRequested"] == true;
    final adminRejectNote =
        (item["cancellationReviewNote"]?.toString() ?? "").trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _missionCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _statusBadge(status)),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditProjectDialog(context, item);
                    } else if (value == 'delete') {
                      _confirmDeletion(item["_id"].toString());
                    } else if (value == 'request_cancel') {
                      _showRequestCancellationDialog(item["_id"].toString());
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded, color: Colors.blue),
                          title: Text("Modifier"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ];
                    if (canDirectDelete) {
                      items.add(
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                            ),
                            title: Text("Supprimer"),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      );
                    }
                    if (canRequestCancellation) {
                      items.add(
                        const PopupMenuItem(
                          value: 'request_cancel',
                          child: ListTile(
                            leading: Icon(
                              Icons.flag_outlined,
                              color: Colors.orange,
                            ),
                            title: Text("Demander l’annulation (admin)"),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      );
                    }
                    return items;
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (pendingCancellation) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 18, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Annulation demandée — en attente de l’administration",
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (adminRejectNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Message administration : $adminRejectNote",
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.red.shade800,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(
                  icon: Icons.payments_outlined,
                  label: _formatBudget(item["budget"]),
                ),
                if (_postedRelative(item["createdAt"]).isNotEmpty)
                  _metaChip(
                    icon: Icons.calendar_today_outlined,
                    label: _postedRelative(item["createdAt"]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              desc.isEmpty ? 'Pas de description.' : desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: _slateText,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.group_outlined, size: 20),
                    label: const Text('Voir les propositions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lancyPurple,
                      side: BorderSide(
                        color: lancyPurple.withValues(alpha: 0.65),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Get.to(
                      () => ProposalsListScreen(projectId: item["_id"]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: !isAccepted
                      ? Colors.grey.shade100
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openMissionChat(
                      item,
                      isClient: true,
                      isRejected: isRejected,
                      isAccepted: isAccepted,
                    ),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: !isAccepted
                            ? Colors.grey.withValues(alpha: 0.45)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: skyBlue),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
