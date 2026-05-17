import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/screens/payment_screen.dart';
import 'package:pfe/screens/send_proposal_screen.dart';
import 'package:pfe/service/auth_service.dart';

class ProjectDetailScreen extends StatelessWidget {
  final dynamic project;

  const ProjectDetailScreen({super.key, required this.project, required String userRole});

  @override
  Widget build(BuildContext context) {
    final Color lancyPurple = const Color(0xFF8E2DE2);
    final Color skyBlue = const Color(0xFF74C0FC);

    // ✅ Date formatée
    String formatDate(String? dateStr) {
      if (dateStr == null) return "Date inconnue";
      try {
        final dt = DateTime.parse(dateStr).toLocal();
        return "${dt.day}/${dt.month}/${dt.year}";
      } catch (_) {
        return "Date inconnue";
      }
    }

    final String clientName = project["clientId"]?["name"] ??
        project["owner"]?["name"] ??
        "Client";
    final String date = formatDate(project["createdAt"]);
    final String title = project["title"] ?? "Sans titre";
    final String description =
        project["description"] ?? "Aucune description";
    final String budget = "${project["budget"] ?? 0} DT";
    final String proposalStatus =
        project["userProposalStatus"]?.toString() ?? "none";
    final bool isRejected = proposalStatus == "rejected";
    final bool hasActiveProposal =
        proposalStatus == "pending" || proposalStatus == "accepted";
    final bool canApply = !isRejected && !hasActiveProposal;
    final int clientBudgetNum = () {
      final b = project["budget"];
      if (b == null) return 0;
      if (b is int) return b;
      if (b is num) return b.round();
      return int.tryParse(b.toString()) ?? 0;
    }();
    final String status = project["status"] ?? "open";

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ✅ Header avec gradient
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: lancyPurple,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [lancyPurple, skyBlue],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Badge statut
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          status == "open" ? "🟢 Ouvert" : "🔴 Fermé",
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Titre
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ✅ Contenu
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Infos rapides
                Row(
                  children: [
                    Expanded(
                      child: _infoTile(
                        icon: Icons.payments_outlined,
                        label: "Budget",
                        value: budget,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoTile(
                        icon: Icons.calendar_today_outlined,
                        label: "Publié le",
                        value: date,
                        color: skyBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _infoTile(
                        icon: Icons.person_outline,
                        label: "Client",
                        value: clientName,
                        color: lancyPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoTile(
                        icon: Icons.work_outline,
                        label: "Statut",
                        value: status == "open" ? "Ouvert" : "Fermé",
                        color: status == "open"
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Description
                Text(
                  "Description du projet",
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Text(
                    description,
                    style: GoogleFonts.inter(
                        height: 1.6,
                        color: Colors.grey[700],
                        fontSize: 14),
                  ),
                ),

                const SizedBox(height: 24),

                // Compétences requises (si disponibles)
                if (project["skills"] != null &&
                    (project["skills"] as List).isNotEmpty) ...[
                  Text(
                    "Compétences requises",
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (project["skills"] as List)
                        .map((skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: lancyPurple.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(99),
                                border: Border.all(
                                    color: lancyPurple
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                skill.toString(),
                                style: GoogleFonts.inter(
                                    color: lancyPurple,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // À propos du client
                Text(
                  "À propos du client",
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: lancyPurple.withValues(alpha: 0.1),
                        child: Text(
                          clientName.isNotEmpty
                              ? clientName[0].toUpperCase()
                              : "C",
                          style: GoogleFonts.poppins(
                              color: lancyPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                          ),
                          Text(
                            "Membre depuis ${formatDate(project["createdAt"])}",
                            style: GoogleFonts.inter(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ✅ Bouton postuler
                if (status == "open")
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      onPressed: canApply
                          ? () async {
                              final token = await AuthService.getToken();
                              if (token == null) {
                                Get.snackbar(
                                    "Erreur", "Veuillez vous reconnecter");
                                return;
                              }
                              final sent = await Get.to<bool>(
                                () => SendProposalScreen(
                                  projectId:
                                      project["_id"].toString(),
                                  projectTitle: title,
                                  token: token,
                                  clientBudget: clientBudgetNum,
                                ),
                              );
                              if (!context.mounted) return;
                              if (sent == true) {
                                final m =
                                    Map<String, dynamic>.from(project as Map);
                                m["userProposalStatus"] = "pending";
                                Get.off(
                                  () =>
                                      ProjectDetailScreen(project: m, userRole: '',),
                                );
                              }
                            }
                          : null,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: canApply
                              ? LinearGradient(
                                  colors: [skyBlue, lancyPurple])
                              : null,
                          color:
                              canApply ? null : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                canApply
                                    ? Icons.send_outlined
                                    : Icons.block_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                !canApply
                                    ? (isRejected
                                        ? "Proposition refusée"
                                        : "Proposition envoyée")
                                    : "Envoyer ma proposition",
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              if (project["status"] == "accepted") ...[
  SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton(
      onPressed: () {
        final String currentProjectTitle = project["title"] ?? "Projet";
        final dynamic currentClient = project["owner"] ?? project["clientId"];
        Navigator.push(
          context,
          MaterialPageRoute(
            
            builder: (_) => PaymentScreen(
           projectId: project["_id"].toString(),
          amount: project["price"],
          projectTitle: currentProjectTitle, // Récupère "test"
          client: currentClient,           // Récupère l'objet de Fatma
          freelancer: project["selectedFreelancer"],// Envoie l'objet freelancer complet (Map)
          ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.payment, color: Colors.white),
          SizedBox(width: 8),
          Text(
            "Payer 💳",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  ),
]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey)),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}