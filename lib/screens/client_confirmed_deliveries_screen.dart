import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/config/api_config.dart';
import 'package:pfe/screens/SuiviProjectScreen.dart';
import 'package:pfe/service/project_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran client : livrables en attente de validation + livrables déjà validés.
class ClientConfirmedDeliveriesScreen extends StatefulWidget {
  const ClientConfirmedDeliveriesScreen({super.key});

  @override
  State<ClientConfirmedDeliveriesScreen> createState() =>
      _ClientConfirmedDeliveriesScreenState();
}

class _ClientConfirmedDeliveriesScreenState
    extends State<ClientConfirmedDeliveriesScreen> {
  static const Color _pageBg = Color(0xFFF4F6FF);
  static const Color _brandPurple = Color(0xFF8E2DE2);
  static const Color _accentCyan = Color(0xFF00D2FF);
  static const Color _titleDark = Color(0xFF1A1C1E);
  static const Color _slate = Color(0xFF475569);
  static const Color _cardBorder = Color(0xFFE8ECF2);

  // Confirmed (client_approved / approved)
  List<dynamic> _items = [];
  // Pending client validation
  List<dynamic> _pendingItems = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch both in parallel
      final results = await Future.wait([
        ProjectService.fetchClientConfirmedDeliveries(),
        ProjectService.fetchClientPendingDeliveries(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _pendingItems = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // kept for backward compat with _DeliveryCard signature
  static String _uploadUrl(String filename) {
    return '${ApiConfig.origin}/uploads/${Uri.encodeComponent(filename)}';
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL invalide')),
      );
      return;
    }
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le lien')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Map<String, dynamic>? _submission(dynamic p) {
    final s = p is Map ? p['adminWorkSubmission'] : null;
    if (s is Map) return Map<String, dynamic>.from(s);
    return null;
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z')) {
      return Icons.folder_zip_rounded;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
      return Icons.movie_rounded;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _fileIconTint(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFDC2626);
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return _brandPurple;
    }
    return _slate;
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _pendingItems.isNotEmpty;
    final hasConfirmed = _items.isNotEmpty;
    final isEmpty = !hasPending && !hasConfirmed;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Livrables',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: _titleDark,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: _loading ? Colors.grey.shade400 : _slate,
            ),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _brandPurple,
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.45,
                    child: Center(
                      child: CircularProgressIndicator(color: _brandPurple),
                    ),
                  ),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      _ErrorPanel(
                        message: _error!,
                        onRetry: _load,
                        brandPurple: _brandPurple,
                      ),
                    ],
                  )
                : isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [_buildEmptyState(context)],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          // ── À VALIDER ──────────────────────────────────
                          if (hasPending) ...[
                            _sectionHeader(
                              icon: Icons.pending_actions_rounded,
                              label: 'À valider',
                              count: _pendingItems.length,
                              color: Colors.orange.shade700,
                              bg: Colors.orange.shade50,
                            ),
                            const SizedBox(height: 8),
                            ..._pendingItems.map((raw) {
                              if (raw is! Map) return const SizedBox.shrink();
                              final p = Map<String, dynamic>.from(raw);
                              return _PendingCard(
                                project: p,
                                brandPurple: _brandPurple,
                                titleDark: _titleDark,
                                slate: _slate,
                                cardBorder: _cardBorder,
                                onValidate: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SuiviProjectScreen(project: p),
                                    ),
                                  );
                                  // Refresh after returning from SuiviProjectScreen
                                  _load();
                                },
                              );
                            }),
                            const SizedBox(height: 20),
                          ],
                          // ── VALIDÉS ────────────────────────────────────
                          if (hasConfirmed) ...[
                            _sectionHeader(
                              icon: Icons.verified_rounded,
                              label: 'Validés',
                              count: _items.length,
                              color: _brandPurple,
                              bg: _brandPurple.withValues(alpha: 0.07),
                            ),
                            const SizedBox(height: 8),
                            ..._items.map((raw) {
                              if (raw is! Map) return const SizedBox.shrink();
                              final p = Map<String, dynamic>.from(raw);
                              return _DeliveryCard(
                                project: p,
                                submission: _submission(p),
                                brandPurple: _brandPurple,
                                accentCyan: _accentCyan,
                                titleDark: _titleDark,
                                slate: _slate,
                                cardBorder: _cardBorder,
                                fileIcon: _fileIcon,
                                fileIconTint: _fileIconTint,
                                uploadUrl: _uploadUrl,
                                onLaunch: _launch,
                              );
                            }),
                          ],
                        ],
                      ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.55,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _brandPurple.withValues(alpha: 0.08),
                  border: Border.all(color: _cardBorder),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: _brandPurple.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Aucun livrable pour l’instant',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _titleDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Dès que le freelancer livrera son travail, vous verrez ici un bouton pour valider. Les livrables validés apparaissent aussi dans cette page.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _slate,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Card shown for a livrable that is pending client validation.
class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final Color brandPurple;
  final Color titleDark;
  final Color slate;
  final Color cardBorder;
  final VoidCallback onValidate;

  const _PendingCard({
    required this.project,
    required this.brandPurple,
    required this.titleDark,
    required this.slate,
    required this.cardBorder,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    final title = project['title']?.toString() ?? 'Mission';
    final freelancer = project['acceptedFreelancer'];
    var flName = 'Freelancer';
    if (freelancer is Map && freelancer['name'] != null) {
      flName = freelancer['name'].toString();
    }
    final sub = project['adminWorkSubmission'];
    final msg = sub is Map ? (sub['message']?.toString().trim() ?? '') : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Icon(Icons.pending_actions_rounded,
                      color: Colors.orange.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: titleDark,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 14, color: slate),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              flName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: slate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (msg.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: Text(
                  msg,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le freelancer a livré son travail. Ouvrez le suivi pour valider ou demander des corrections.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onValidate,
                style: FilledButton.styleFrom(
                  backgroundColor: brandPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  'Voir & valider le livrable',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color brandPurple;

  const _ErrorPanel({
    required this.message,
    required this.onRetry,
    required this.brandPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final Map<String, dynamic>? submission;
  final Color brandPurple;
  final Color accentCyan;
  final Color titleDark;
  final Color slate;
  final Color cardBorder;
  final IconData Function(String) fileIcon;
  final Color Function(String) fileIconTint;
  final String Function(String) uploadUrl;
  final Future<void> Function(String) onLaunch;

  const _DeliveryCard({
    required this.project,
    required this.submission,
    required this.brandPurple,
    required this.accentCyan,
    required this.titleDark,
    required this.slate,
    required this.cardBorder,
    required this.fileIcon,
    required this.fileIconTint,
    required this.uploadUrl,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    final title = project['title']?.toString() ?? 'Mission';
    final freelancer = project['acceptedFreelancer'];
    var flName = 'Freelancer';
    if (freelancer is Map && freelancer['name'] != null) {
      flName = freelancer['name'].toString();
    }
    final msg = submission?['message']?.toString().trim() ?? '';
    final link = submission?['demoLink']?.toString().trim() ?? '';
    final files = submission?['files'];
    final fileList = <Map<String, dynamic>>[];
    if (files is List) {
      for (final f in files) {
        if (f is Map) fileList.add(Map<String, dynamic>.from(f));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    brandPurple.withValues(alpha: 0.09),
                    accentCyan.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          brandPurple,
                          brandPurple.withValues(alpha: 0.75),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brandPurple.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: titleDark,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 15, color: slate),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                flName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: slate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final pay =
                          project['paymentStatus']?.toString() ?? '';
                      final released = pay == 'released';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: released
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF9C3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: released
                                ? const Color(0xFF6EE7B7)
                                    .withValues(alpha: 0.45)
                                : const Color(0xFFFDE047)
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              released
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              size: 18,
                              color: released
                                  ? Colors.green.shade700
                                  : const Color(0xFF854D0E),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                released
                                    ? 'Paiement libéré — le montant a été envoyé au freelancer'
                                    : 'Vous avez validé le livrable — en attente de libération par l’administration',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: released
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF854D0E),
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (msg.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Message',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: titleDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Text(
                        msg,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.45,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                  if (link.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => onLaunch(link),
                        style: FilledButton.styleFrom(
                          backgroundColor: brandPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.link_rounded, size: 20),
                        label: Text(
                          'Ouvrir le lien',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (fileList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Pièces jointes',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: titleDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: slate.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${fileList.length}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: slate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...fileList.map((f) {
                      final fn = f['filename']?.toString() ?? '';
                      final on = f['originalName']?.toString() ?? fn;
                      // Use Cloudinary URL if available, fall back to legacy local path
                      final rawUrl = f['url']?.toString().trim() ?? '';
                      final url = rawUrl.isNotEmpty ? rawUrl : uploadUrl(fn);
                      if (fn.isEmpty && rawUrl.isEmpty) return const SizedBox.shrink();
                      final icon = fileIcon(on.isNotEmpty ? on : fn);
                      final tint = fileIconTint(on.isNotEmpty ? on : fn);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onLaunch(url),
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorder),
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: tint.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, color: tint, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            on,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: titleDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Appuyer pour ouvrir ou télécharger',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: slate.withValues(alpha: 0.85),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => onLaunch(url),
                                      icon: Icon(
                                        Icons.download_rounded,
                                        color: brandPurple,
                                      ),
                                      tooltip: 'Télécharger / ouvrir',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
