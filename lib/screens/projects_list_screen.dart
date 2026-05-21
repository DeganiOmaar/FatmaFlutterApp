import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/screens/SuiviProjectScreen.dart';
import 'package:pfe/screens/project_tracking_screen.dart';
import 'package:pfe/service/project_service.dart';

class ProjectsListScreen extends StatefulWidget {
  final String role;
  final Function(Map<String, dynamic> project)? onOpenProject;

  const ProjectsListScreen({
    super.key,
    required this.role,
    this.onOpenProject,
  });

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  final ProjectService _service = ProjectService();

  // Lancy colors
  final Color lancyPurple = const Color(0xFF8E2DE2);
  final Color lightBlue   = const Color(0xFF00D2FF);

  List projects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() => isLoading = true);
    final data = await _service.getMyProjects(role: widget.role);
    setState(() {
      projects  = data;
      isLoading = false;
    });
  }

  // ── Navigation vers le tracking ───────────────────────
  Future<void> _openProject(Map<String, dynamic> project) async {
    // ✅ Navigation directe selon le rôle
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => widget.role == 'client'
            ? SuiviProjectScreen(
                project: Map<String, dynamic>.from(project))
            : ProjectTrackingScreen(
                project: Map<String, dynamic>.from(project),
                role: widget.role,
              ),
      ),
    );

    // ✅ Recharge la liste après retour
    // (capte le refus, la livraison, la validation...)
    if (mounted) loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          widget.role == 'client' ? "Mes Projets" : "Mes Missions",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: lancyPurple))
          : projects.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: lancyPurple,
                  onRefresh: loadProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: projects.length,
                    itemBuilder: (_, i) => _buildCard(projects[i]),
                  ),
                ),
    );
  }

  // ── Project card ──────────────────────────────────────
  Widget _buildCard(dynamic project) {
    final status     = project['status']?.toString() ?? '';
    final statusMeta = _statusMeta(status);

    return GestureDetector(
      onTap: () => _openProject(
          Map<String, dynamic>.from(project as Map)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône statut
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusMeta.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusMeta.$3,
                  color: statusMeta.$2, size: 22),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project['title'] ?? 'Sans titre',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF1A1C1E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Badge statut
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusMeta.$2.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          statusMeta.$1,
                          style: TextStyle(
                            color: statusMeta.$2,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Budget
                      Text(
                        "${project['budget'] ?? '--'} DT",
                        style: GoogleFonts.inter(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  ...() {
                    final hint = _freelancerDeliveryHint(project);
                    if (hint == null) return <Widget>[];
                    final refused = hint.$1 == 'refused';
                    final color = refused
                        ? Colors.orange.shade700
                        : Colors.blue.shade700;
                    return [
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            refused
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded,
                            color: color,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hint.$2,
                              style: GoogleFonts.inter(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ];
                  }(),
                ],
              ),
            ),

            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            widget.role == 'client'
                ? "Aucun projet en cours"
                : "Aucune mission en cours",
            style: GoogleFonts.poppins(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Tirez vers le bas pour actualiser",
            style: GoogleFonts.inter(
                color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// `(kind, message)` — kind: `refused` | `waiting` | `delivered`
  (String, String)? _freelancerDeliveryHint(dynamic project) {
    if (widget.role != 'freelancer') return null;
    final status = project['status']?.toString() ?? '';
    if (status != 'in_progress') return null;

    final delivery = project['delivery'];
    if (delivery is! Map) return null;

    final deliveryStatus =
        delivery['status']?.toString().trim().toLowerCase() ?? 'pending';

    switch (deliveryStatus) {
      case 'refused':
        return (
          'refused',
          'Livraison refusée — correction requise',
        );
      case 'delivered':
        return (
          'delivered',
          'Livré — en attente de validation client',
        );
      case 'pending':
      default:
        return (
          'waiting',
          'En attente — livrez votre travail',
        );
    }
  }

  // ── Status meta ───────────────────────────────────────
  (String, Color, IconData) _statusMeta(String status) {
    switch (status) {
      case 'in_progress':
        return ('En cours', Colors.orange,
            Icons.autorenew_rounded);
      case 'delivered':
        return ('Livré', Colors.blue,
            Icons.inventory_2_outlined);
      case 'completed':
        return ('Terminé', Colors.green,
            Icons.check_circle_outline_rounded);
      default:
        return ('Ouvert', Colors.grey,
            Icons.work_outline_rounded);
    }
  }
}
