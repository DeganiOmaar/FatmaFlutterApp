import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/project_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SuiviProjectScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const SuiviProjectScreen({super.key, required this.project});

  @override
  State<SuiviProjectScreen> createState() => _SuiviProjectScreenState();
}

class _SuiviProjectScreenState extends State<SuiviProjectScreen> {
  final Color lancyPurple = const Color(0xFF8E2DE2);
  final Color lightBlue   = const Color(0xFF00D2FF);
  final Color darkText    = const Color(0xFF1A1C1E);

  final ProjectService _service = ProjectService();
  bool _isLoading = false;
  Map<String, dynamic>? _liveMeta;

  String _paymentSt() =>
      _liveMeta?['paymentStatus']?.toString() ??
      widget.project['paymentStatus']?.toString() ??
      '';

  bool get _isEscrow => _paymentSt() == 'escrow_locked';

  Map<String, dynamic>? _submissionMap() {
    final raw = _liveMeta?['adminWorkSubmission'] ??
        widget.project['adminWorkSubmission'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _submissionStatus() => _submissionMap()?['status']?.toString() ?? 'none';

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final id = widget.project['_id']?.toString();
    if (id == null || id.isEmpty) return;
    final m = await ProjectService.fetchParticipantMeta(id);
    if (!mounted) return;
    setState(() => _liveMeta = m);
  }

  // ── Step index ────────────────────────────────────────
  int get _stepIndex {
    switch (widget.project['status']?.toLowerCase()) {
      case 'in_progress': return 1;
      case 'delivered':   return 2;
      case 'completed':
      case 'paid':        return 3;
      default:            return 0;
    }
  }

  // ── Validate & release payment (hors escrow uniquement) ─────────────────
  Future<void> _releasePayment() async {
    if (_isEscrow) {
      _showError(
        "Les missions en escrow sont payées par l’administration après votre validation du livrable.",
      );
      return;
    }
    setState(() => _isLoading = true);
    final success =
        await _service.releasePayment(widget.project['_id']);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSuccess("Paiement libéré ✅",
          "Le freelancer a été payé avec succès !");
      Navigator.pop(context, true);
    } else {
      _showError("Erreur lors du paiement");
    }
  }

  // ── Reject delivery ───────────────────────────────────
  Future<void> _rejectDelivery(String reason) async {
    setState(() => _isLoading = true);
    try {
      if (_isEscrow) {
        final err = await ProjectService.rejectClientSubmission(
          widget.project['_id'].toString(),
          note: reason,
        );
        setState(() => _isLoading = false);
        if (!mounted) return;
        if (err == null) {
          await _loadMeta();
          if (!mounted) return;
          _showSuccess(
            "Retour envoyé",
            "Le freelancer peut corriger et renvoyer un livrable.",
          );
          Navigator.pop(context, true);
        } else {
          _showError(err);
        }
        return;
      }

      final token = await AuthService.getToken();
      final res = await http.put(
        Uri.parse(
            "${ApiConfig.baseURL}/projects/${widget.project['_id']}/reject-delivery"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"reason": reason}),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.statusCode == 200) {
        _showSuccess("Livraison refusée",
            "Le freelancer va corriger et relivrer.");
        Navigator.pop(context, true);
      } else {
        _showError("Impossible de refuser la livraison");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _approveClientSubmission() async {
    setState(() => _isLoading = true);
    final err = await ProjectService.approveClientSubmission(
      widget.project['_id'].toString(),
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (err == null) {
      await _loadMeta();
      if (!mounted) return;
      _showSuccess(
        "Livrable validé",
        "L’administration va libérer le paiement au freelancer.",
      );
      Navigator.pop(context, true);
    } else {
      _showError(err);
    }
  }

  // ── Open dispute ──────────────────────────────────────
Future<void> _openDispute(String reason) async {

  setState(() => _isLoading = true);

  try {

    final token = await AuthService.getToken();

    final response = await http.put(

      Uri.parse(
        "${ApiConfig.baseURL}/escrow/dispute/${widget.project['_id']}"
      ),

      headers: {

        "Content-Type": "application/json",

        "Authorization": "Bearer $token"

      },

      body: jsonEncode({

        "reason": reason

      }),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {

      _showSuccess(

        "Litige ouvert",

        "L'administrateur va intervenir"

      );

      Navigator.pop(context, true);

    } else {

      _showError(

        data["message"] ?? "Erreur"

      );

    }

  } catch (e) {

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showError(e.toString());

  }
}

  // ── Dialogs ───────────────────────────────────────────
  void _showRejectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined,
                color: Colors.orange.shade600, size: 22),
            const SizedBox(width: 8),
            Text("Refuser la livraison",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Expliquez ce qui doit être corrigé. Le freelancer recevra votre retour et pourra relivrer.",
              style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Ex: Le design ne correspond pas...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _rejectDelivery(ctrl.text.trim());
            },
            icon: const Icon(Icons.reply_rounded,
                color: Colors.white, size: 18),
            label: Text("Refuser & demander correction",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDisputeDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade600, size: 22),
            const SizedBox(width: 8),
            Text("Ouvrir un litige",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Un administrateur interviendra pour résoudre le litige. Le paiement sera bloqué jusqu'à résolution.",
              style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Décrivez le problème en détail...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _openDispute(ctrl.text.trim());
            },
            icon: const Icon(Icons.gavel_rounded,
                color: Colors.white, size: 18),
            label: Text("Confirmer le litige",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String title, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("$title — $msg",
          style: GoogleFonts.inter()),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final status = widget.project['status']?.toString() ?? '';

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: AppBar(
          title: Text("Suivi du projet",
              style: GoogleFonts.inter(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildStepper(),
              const SizedBox(height: 20),

              // ✅ Travail livré — client
              if (status == 'delivered') ...[
                if (_isEscrow) ...[
                  _buildEscrowClientDeliverableSection(),
                ] else ...[
                  _buildDeliverySection(),
                  const SizedBox(height: 20),
                  _buildClientActions(),
                ],
              ]

              // ✅ En attente de livraison
              else if (status == 'in_progress')
                _buildWaitingCard()

              // ✅ Terminé
              else if (status == 'completed')
                _buildCompletedCard(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lightBlue, const Color(0xFF928DFF), lancyPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.project['title'] ?? "Projet",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${widget.project['budget'] ?? '0'} DT",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(widget.project['status']),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stepper ───────────────────────────────────────────
  Widget _buildStepper() {
    final step = _stepIndex;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stepCircle(Icons.check,                step >= 0),
              _stepLine(step > 0),
              _stepCircle(Icons.sync,                 step >= 1),
              _stepLine(step > 1),
              _stepCircle(Icons.inventory_2_outlined,  step >= 2),
              _stepLine(step > 2),
              _stepCircle(Icons.payment,              step >= 3),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stepLabel("Démarré",  step >= 0),
              _stepLabel("En cours", step >= 1),
              _stepLabel("Livré",    step >= 2),
              _stepLabel("Payé",     step >= 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(IconData icon, bool isActive) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? lancyPurple.withValues(alpha: 0.8)
              : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: isActive ? Colors.white : Colors.grey,
            size: 18),
      );

  Widget _stepLine(bool isActive) => Container(
        width: 30, height: 3,
        color: isActive ? lightBlue : Colors.grey[300],
      );

  Widget _stepLabel(String text, bool isActive) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: isActive ? lancyPurple : Colors.grey,
          fontWeight:
              isActive ? FontWeight.bold : FontWeight.normal,
        ),
      );

  // ── Livrable escrow (freelancer → client → admin) ──────────────────────
  Widget _buildEscrowClientDeliverableSection() {
    final sub = _submissionMap();
    final st = _submissionStatus();

    if (st == 'client_approved' || st == 'approved') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEscrowSubmissionCard(sub),
          const SizedBox(height: 16),
          _buildWaitingAdminCard(),
        ],
      );
    }

    if (st == 'pending_client' || st == 'pending_review') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEscrowSubmissionCard(sub),
          const SizedBox(height: 20),
          _buildEscrowApproveRejectActions(),
        ],
      );
    }

    return _buildWaitingFreelancerEscrowCard();
  }

  Widget _buildWaitingFreelancerEscrowCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          children: [
            Icon(Icons.hourglass_top_rounded,
                size: 44, color: Colors.blue.shade400),
            const SizedBox(height: 12),
            Text(
              'En attente du livrable',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800),
            ),
            const SizedBox(height: 8),
            Text(
              'Le freelancer doit envoyer fichiers, lien et message depuis le chat mission. Vous pourrez alors valider ou demander des corrections.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.blue.shade700, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      );

  Widget _buildWaitingAdminCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.shade100),
        ),
        child: Column(
          children: [
            Icon(Icons.verified_outlined,
                size: 48, color: Colors.teal.shade600),
            const SizedBox(height: 12),
            Text(
              'Validation enregistrée',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous avez validé le livrable. L’administration libérera l’escrow vers le wallet du freelancer ; vous recevrez une notification.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.teal.shade700, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      );

  Widget _buildEscrowApproveRejectActions() {
    return Column(
      children: [
        _actionButton(
          label: _isLoading ? 'Traitement...' : 'Valider le livrable',
          icon: Icons.check_circle_rounded,
          gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600]),
          onTap: _isLoading ? null : _approveClientSubmission,
        ),
        const SizedBox(height: 10),
        _actionButton(
          label: 'Refuser & demander une correction',
          icon: Icons.reply_rounded,
          gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade600]),
          onTap: _isLoading ? null : _showRejectDialog,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isLoading ? null : _showDisputeDialog,
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: Text(
              'Ouvrir un litige',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEscrowSubmissionCard(Map<String, dynamic>? sub) {
    final msg = sub?['message']?.toString().trim() ?? '';
    final link = sub?['demoLink']?.toString().trim() ?? '';
    final files = sub?['files'];
    final fileList = <Map<String, dynamic>>[];
    if (files is List) {
      for (final f in files) {
        if (f is Map) fileList.add(Map<String, dynamic>.from(f));
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: lancyPurple, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Livrable du freelancer',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: darkText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vérifiez le contenu puis validez ou demandez des corrections.',
            style: GoogleFonts.inter(
                fontSize: 12.5, color: Colors.grey.shade600, height: 1.35),
          ),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Message',
                style: GoogleFonts.inter(
                    color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 4),
            Text(msg,
                style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
          ],
          if (link.isNotEmpty) ...[
            const SizedBox(height: 12),
            _linkButton(
              icon: Icons.link_rounded,
              label: 'Ouvrir le lien',
              color: Colors.blue,
              onTap: () async {
                final uri = Uri.parse(link);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
          ],
          if (fileList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Fichiers',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ...fileList.map((f) {
              final fn = f['filename']?.toString() ?? '';
              final on =
                  f['originalName']?.toString() ?? fn;
              if (fn.isEmpty) return const SizedBox.shrink();
              final url = Uri.parse(
                  '${ApiConfig.origin}/uploads/${Uri.encodeComponent(fn)}');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _linkButton(
                  icon: Icons.insert_drive_file_rounded,
                  label: on,
                  color: Colors.purple,
                  onTap: () async {
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Delivery section ──────────────────────────────────
  Widget _buildDeliverySection() {
    final delivery = widget.project['delivery'];
    final link    = delivery is Map ? delivery['link']    : null;
    final message = delivery is Map ? delivery['message'] : null;
    final file    = delivery is Map ? delivery['file']    : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text("Travail livré 📦",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: darkText)),
            ],
          ),
          const SizedBox(height: 14),

          if (message != null &&
              message.toString().isNotEmpty) ...[
            Text("Message du freelancer :",
                style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 12)),
            const SizedBox(height: 4),
            Text(message.toString(),
                style: GoogleFonts.inter(
                    fontSize: 14, height: 1.5)),
            const SizedBox(height: 12),
          ],

          if (link != null && link.toString().isNotEmpty)
            _linkButton(
              icon: Icons.link_rounded,
              label: "Ouvrir le lien",
              color: Colors.blue,
              onTap: () async {
                final uri = Uri.parse(link.toString());
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),

          if (file != null && file.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _linkButton(
              icon: Icons.insert_drive_file_rounded,
              label: "Télécharger le fichier",
              color: Colors.purple,
              onTap: () async {
                final url = Uri.parse(
                    "${ApiConfig.origin}/uploads/${file.toString()}");
                if (await canLaunchUrl(url)) launchUrl(url);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _linkButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Client actions ────────────────────────────────────
  Widget _buildClientActions() {
    return Column(
      children: [
        // ✅ Valider
        _actionButton(
          label: _isLoading
              ? "Traitement..."
              : "Valider & libérer le paiement",
          icon: Icons.check_circle_rounded,
          gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600]),
          onTap: _isLoading ? null : _releasePayment,
        ),
        const SizedBox(height: 10),

        // ✅ Refuser
        _actionButton(
          label: "Refuser & demander correction",
          icon: Icons.reply_rounded,
          gradient: LinearGradient(
              colors: [Colors.orange.shade400,
                       Colors.orange.shade600]),
          onTap: _isLoading ? null : _showRejectDialog,
        ),
        const SizedBox(height: 10),

        // ✅ Litige
 SizedBox(

  width: double.infinity,

  child: OutlinedButton.icon(

    style: OutlinedButton.styleFrom(

      foregroundColor: Colors.red,

      side: const BorderSide(
        color: Colors.red
      ),

      padding: const EdgeInsets.symmetric(
        vertical: 14
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14)
      ),
    ),

    onPressed: _isLoading
        ? null
        : _showDisputeDialog,

    icon: const Icon(
      Icons.gavel_rounded,
      size: 18
    ),

    label: Text(

      "Ouvrir un litige",

      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600
      ),
    ),
  ),
)
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required LinearGradient gradient,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: onTap != null ? gradient : null,
          color: onTap == null ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading && label.contains("Traitement")
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Waiting card ──────────────────────────────────────
  Widget _buildWaitingCard() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.hourglass_top_rounded,
                size: 48, color: Colors.orange.shade400),
            const SizedBox(height: 12),
            Text("En attente de livraison",
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700)),
            const SizedBox(height: 8),
            Text(
              "Le freelancer n'a pas encore livré le travail.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.orange.shade600, fontSize: 13),
            ),
          ],
        ),
      );

  // ── Completed card ────────────────────────────────────
  Widget _buildCompletedCard() => Container(
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
              "Le paiement a été libéré au freelancer.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.green.shade600, fontSize: 13),
            ),
          ],
        ),
      );

  // ── Helpers ───────────────────────────────────────────
  String _statusLabel(String? status) {
    switch (status) {
      case 'in_progress': return '🔄 En cours';
      case 'delivered':   return '📦 Livré — en attente de validation';
      case 'completed':   return '✅ Terminé';
      default:            return '📋 Ouvert';
    }
  }
}