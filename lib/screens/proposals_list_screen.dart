import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/config/api_config.dart';
import 'package:pfe/screens/profilescreen.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/project_service.dart';
import 'package:pfe/service/proposal_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProposalsListScreen extends StatefulWidget {
  final String projectId;

  const ProposalsListScreen({super.key, required this.projectId});

  @override
  State<ProposalsListScreen> createState() => _ProposalsListScreenState();
}

class _ProposalsListScreenState extends State<ProposalsListScreen> {
  final ProposalService service = ProposalService();
  List proposals = [];
  bool loading = true;
  Map<String, dynamic>? _projectMeta;
  bool _deliverableBusy = false;

  final Color lancyPurple = const Color(0xFF8E2DE2);

  @override
  void initState() {
    super.initState();
    load();
  }

  String _paymentSt() => _projectMeta?['paymentStatus']?.toString() ?? '';

  bool get _escrowLocked => _paymentSt() == 'escrow_locked';

  Map<String, dynamic>? _submissionMap() {
    final raw = _projectMeta?['adminWorkSubmission'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _submissionStatus() =>
      _submissionMap()?['status']?.toString() ?? 'none';

  Future<void> load() async {
    final token = await AuthService.getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() => loading = false);
      return;
    }
    try {
      final data = await service.getProposals(token, widget.projectId);
      final meta =
          await ProjectService.fetchParticipantMeta(widget.projectId);
      if (!mounted) return;
      setState(() {
        proposals = data;
        _projectMeta = meta;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _proposalId(dynamic p) => p['_id']?.toString() ?? '';

  String _freelancerName(dynamic p) {
    final f = p['freelancer'];
    if (f is Map) return f['name']?.toString() ?? 'Freelance';
    return 'Freelance';
  }

  String? _freelancerAvatarUrl(Map<dynamic, dynamic> freelancer) {
    final raw = freelancer['avatar'] ?? freelancer['profilePicture'];
    if (raw == null) return null;
    final t = raw.toString().trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return '${ApiConfig.origin}/$t';
  }

  Widget _freelancerAvatar(Map<dynamic, dynamic> freelancer, String initial) {
    final url = _freelancerAvatarUrl(freelancer);
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.blue.shade100,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Future<void> handleAction(String id, bool isAccept) async {
    if (id.isEmpty) return;

    final token = await AuthService.getToken();
    if (token == null) return;

    if (isAccept) {
      final confirm = await _showConfirmDialog();
      if (confirm != true) return;
    }

    final (bool ok, String message) = isAccept
        ? await service.acceptProposal(token, id)
        : await service.rejectProposal(token, id);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Confirmer",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content:
            const Text("Voulez-vous confier cette mission à ce freelance ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, shape: const StadiumBorder()),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Accepter", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _uploadUrl(String filename) {
    return '${ApiConfig.origin}/uploads/${Uri.encodeComponent(filename)}';
  }

  Future<void> _approveDeliverable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Valider le livrable',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'En validant, vous confirmez que le travail vous convient. '
          'L’administration pourra alors libérer le paiement escrow vers le freelancer.',
          style: GoogleFonts.inter(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deliverableBusy = true);
    final err =
        await ProjectService.approveClientSubmission(widget.projectId);
    if (!mounted) return;
    setState(() => _deliverableBusy = false);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Merci. L’administration va libérer le paiement.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _rejectDeliverable() async {
    final ctrl = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Demander une correction',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expliquez ce qui doit être amélioré. Le freelancer sera notifié et pourra envoyer un nouveau livrable.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ex. : ajouter les maquettes manquantes…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Envoyer le retour'),
          ),
        ],
      ),
    );
    final note = ctrl.text.trim();
    ctrl.dispose();
    if (send != true || !mounted) return;
    setState(() => _deliverableBusy = true);
    final err = await ProjectService.rejectClientSubmission(
      widget.projectId,
      note: note,
    );
    if (!mounted) return;
    setState(() => _deliverableBusy = false);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Retour envoyé au freelancer.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red.shade700),
      );
    }
  }

  /// Livrable : affiché sur la carte « Acceptée » (même flux que le suivi mission).
  Widget _buildDeliverableBlock() {
    if (!_escrowLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              'Le paiement escrow sera actif une fois le budget de la mission confirmé. '
              'Ensuite, le livrable du freelancer s’affichera ici pour validation.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      );
    }

    final sub = _submissionMap();
    final st = _submissionStatus();
    final msg = sub?['message']?.toString().trim() ?? '';
    final link = sub?['demoLink']?.toString().trim() ?? '';
    final files = sub?['files'];
    final fileList = <Map<String, dynamic>>[];
    if (files is List) {
      for (final f in files) {
        if (f is Map) fileList.add(Map<String, dynamic>.from(f));
      }
    }

    if (st == 'client_approved' || st == 'approved') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _infoBanner(
            color: Colors.teal.shade50,
            border: Colors.teal.shade200,
            textColor: Colors.teal.shade900,
            icon: Icons.verified_outlined,
            text:
                'Vous avez validé ce livrable. L’administration libérera l’escrow vers le freelancer.',
          ),
        ],
      );
    }

    if (st == 'client_rejected' || st == 'rejected') {
      final note = sub?['reviewNote']?.toString().trim() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _infoBanner(
            color: Colors.orange.shade50,
            border: Colors.orange.shade200,
            textColor: Colors.orange.shade900,
            icon: Icons.edit_note_outlined,
            text: note.isEmpty
                ? 'Vous avez demandé des corrections. Le freelancer peut renvoyer un livrable.'
                : 'Votre retour : $note',
          ),
          const SizedBox(height: 8),
          Text(
            'Dès réception d’un nouveau livrable, vous pourrez de nouveau valider ou refuser ici.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      );
    }

    if (st == 'pending_client' || st == 'pending_review') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Livrable reçu',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (msg.isNotEmpty)
            Text(msg, style: GoogleFonts.inter(height: 1.45, fontSize: 13)),
          if (link.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _launchUrl(link),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Ouvrir le lien'),
            ),
          ],
          if (fileList.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Fichiers',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            ...fileList.map((f) {
              final fn = f['filename']?.toString() ?? '';
              final on = f['originalName']?.toString() ?? fn;
              // Use Cloudinary URL if available, fall back to legacy local path
              final rawUrl = f['url']?.toString().trim() ?? '';
              final fileUrl = rawUrl.isNotEmpty ? rawUrl : _uploadUrl(fn);
              if (fn.isEmpty && rawUrl.isEmpty) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.attach_file_rounded, size: 20),
                title: Text(
                  on.isNotEmpty ? on : fn,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.open_in_new_rounded,
                      color: lancyPurple, size: 20),
                  onPressed: () => _launchUrl(fileUrl),
                ),
                onTap: () => _launchUrl(fileUrl),
              );
            }),
          ],
          const SizedBox(height: 16),
          if (_deliverableBusy)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _rejectDeliverable,
                    child: Text(
                      'Refuser / correction',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: lancyPurple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _approveDeliverable,
                    child: Text(
                      'Valider le livrable',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _infoBanner(
          color: Colors.blue.shade50,
          border: Colors.blue.shade100,
          textColor: Colors.blue.shade900,
          icon: Icons.hourglass_empty_rounded,
          text:
              'En attente du livrable du freelancer (fichiers / lien depuis le chat mission). '
              'Vous pourrez valider ou demander une correction ici.',
        ),
      ],
    );
  }

  Widget _infoBanner({
    required Color color,
    required Color border,
    required Color textColor,
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Propositions reçues",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: lancyPurple))
          : proposals.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: lancyPurple,
                  onRefresh: load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: proposals.length,
                    itemBuilder: (context, index) =>
                        _buildProposalCard(proposals[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Aucune proposition pour le moment",
              style: GoogleFonts.inter(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProposalCard(dynamic p) {
    String status = p["status"] ?? "pending";
    final String freelancerName = _freelancerName(p);
    final String pid = _proposalId(p);
    final String initial =
        freelancerName.isNotEmpty ? freelancerName[0].toUpperCase() : '?';
    final freelancer = p['freelancer'] is Map ? p['freelancer'] as Map : {};
    final nameStr = freelancer['name']?.toString() ?? '';
    final initialSafe =
        nameStr.isNotEmpty ? nameStr[0].toUpperCase() : initial;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final email = freelancer['email']?.toString();
                    if (email != null && email.isNotEmpty) {
                      Get.to(() => ProfileScreen(email: email));
                    }
                  },
                  child: _freelancerAvatar(freelancer, initialSafe),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(freelancerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Freelance vérifié",
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const Divider(height: 30),
            Text(
              "Lettre de motivation",
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800]),
            ),
            const SizedBox(height: 4),
            _ExpandableCoverLetter(
              text: p["coverLetter"]?.toString() ?? '',
              accentColor: lancyPurple,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailTile(Icons.payments_outlined,
                    "${p["price"] ?? 0} DT", "Budget proposé"),
                _buildDetailTile(Icons.timer_outlined,
                    "${p["deliveryTime"] ?? 0} jours", "Délai"),
              ],
            ),
            if (status == "pending") ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => handleAction(pid, false),
                      child:
                          const Text("Refuser", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81E38F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => handleAction(pid, true),
                      child: const Text("Accepter",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ] else if (status == "accepted") ...[
              _buildDeliverableBlock(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case "accepted":
        color = Colors.green;
        label = "Acceptée";
        break;
      case "rejected":
        color = Colors.red;
        label = "Refusée";
        break;
      default:
        color = Colors.orange;
        label = "En attente";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailTile(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: lancyPurple),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

/// Cover letter with measured overflow → « Voir plus » / « Voir moins ».
class _ExpandableCoverLetter extends StatefulWidget {
  final String text;
  final Color accentColor;

  const _ExpandableCoverLetter({
    required this.text,
    required this.accentColor,
  });

  @override
  State<_ExpandableCoverLetter> createState() => _ExpandableCoverLetterState();
}

class _ExpandableCoverLetterState extends State<_ExpandableCoverLetter> {
  bool _expanded = false;
  static const int _maxCollapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final letter = widget.text.trim().isEmpty
        ? 'Aucun détail fourni.'
        : widget.text.trim();

    final style = GoogleFonts.inter(height: 1.5, color: Colors.black87);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: letter, style: style),
          maxLines: _maxCollapsedLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        final needsToggle = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              letter,
              maxLines: _expanded ? null : _maxCollapsedLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: style,
            ),
            if (needsToggle)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: widget.accentColor,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Voir moins' : 'Voir plus',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
