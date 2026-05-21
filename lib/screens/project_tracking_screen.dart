import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final String role;

  const ProjectTrackingScreen({
    super.key,
    required this.project,
    required this.role,
  });


  @override
  State<ProjectTrackingScreen> createState() => _ProjectTrackingScreenState();
}

class _ProjectTrackingScreenState extends State<ProjectTrackingScreen> {
  final Color lancyPurple = const Color(0xFF8E2DE2);
  final Color lightBlue   = const Color(0xFF00D2FF);

late Map<String, dynamic> projectData;

@override
void initState() {
  super.initState();
  projectData = widget.project;
}
  // ✅ Calcul de l'index du Stepper selon le statut
  int get _stepIndex {
    switch (widget.project['status']?.toLowerCase()) {
      case 'in_progress': return 1;
      case 'delivered':   return 2;
      case 'completed':
      case 'paid':        return 3;
      default:            return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: AppBar(
          title: Text("Project tracking",
              style: GoogleFonts.inter(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStepper(),
                    const SizedBox(height: 20),
                    _buildEscrowNotice(),
                    const SizedBox(height: 20),

                    // --- LOGIQUE FREELANCER ---
                    if (widget.role == 'freelancer' &&
                        projectData['status'] == 'in_progress') ...[
                      if (projectData['delivery'] != null &&
                          projectData['delivery']['status'] == 'refused')
                        _buildRejectionNotice(),
                      if (projectData['delivery'] == null ||
                          projectData['delivery']['status'] == 'pending')
                        _buildPendingDeliveryCard(),
                    ],

                    if (widget.role == 'freelancer' && projectData['status'] == 'delivered')
                      _buildWaitingCard(),

                    // --- ÉTATS GÉNÉRAUX ---
                    if (projectData['status'] == 'completed')
                      _buildCompletedCard(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE COMPOSANTS ---

Widget _buildRejectionNotice() {
  final delivery = projectData['delivery'];

  if (delivery == null || delivery['status'] != 'refused') {
    return const SizedBox.shrink();
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "Livraison refusée : ${delivery['refusedReason'] ?? ''}",
          ),
        ),
      ],
    ),
  );
}

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lightBlue, const Color(0xFF928DFF), lancyPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  projectData['title'] ?? "Projet",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "${projectData['budget'] ?? '0'}\nDT",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sync, color: Colors.white, size: 16),
                const SizedBox(width: 5),
                Text(
                  _statusLabel(projectData['status']),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final step = _stepIndex;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stepCircle(Icons.check, step >= 0),
              _stepLine(step > 0),
              _stepCircle(Icons.sync, step >= 1),
              _stepLine(step > 1),
              _stepCircle(Icons.inventory_2_outlined, step >= 2),
              _stepLine(step > 2),
              _stepCircle(Icons.payment, step >= 3),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stepLabel("Démarré",   step >= 0),
              _stepLabel("En cours", step >= 1),
              _stepLabel("Livré",     step >= 2),
              _stepLabel("Payé",      step >= 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(IconData icon, bool isActive) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? lancyPurple.withValues(alpha: 0.8) : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: isActive ? Colors.white : Colors.grey, size: 18),
      );

  Widget _stepLine(bool isActive) => Container(
        width: 20, height: 2,
        color: isActive ? lightBlue : Colors.grey[300],
      );

  Widget _stepLabel(String text, bool isActive) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: isActive ? lancyPurple : Colors.grey,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      );

  Widget _buildEscrowNotice() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Paiement sécurisé en escrow — libéré au freelancer après votre validation et celle de la plateforme",
                style: GoogleFonts.inter(
                  color: const Color(0xFF2E7D32),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildPendingDeliveryCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_rounded,
                color: Colors.blue.shade600, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "En attente de livraison",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Envoyez votre livrable depuis le chat mission "
                    "(fichiers, lien et message).",
                    style: GoogleFonts.inter(
                      color: Colors.blue.shade700,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildWaitingCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.hourglass_top_rounded,
                size: 48, color: Colors.blue.shade400),
            const SizedBox(height: 12),
            Text("En attente de validation",
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700)),
            const SizedBox(height: 8),
            Text(
              "Le client vérifie votre travail.\nLe paiement sera libéré après validation.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.blue.shade600,
                  fontSize: 13,
                  height: 1.5),
            ),
          ],
        ),
      );

  Widget _buildCompletedCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 56, color: Colors.green),
            const SizedBox(height: 12),
            Text("Projet Terminé 🎉",
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700)),
            const SizedBox(height: 8),
            Text(
              "Paiement reçu sur votre wallet !",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.green.shade600, fontSize: 13),
            ),
          ],
        ),
      );

  String _statusLabel(String? status) {
    switch (status) {
      case 'in_progress': return 'En cours';
      case 'delivered':   return 'Livré';
      case 'completed':   return 'Terminé';
      default:            return 'Ouvert';
    }
  }
}