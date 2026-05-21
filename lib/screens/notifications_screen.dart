import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pfe/config/api_config.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();

  /// Align with [HomeScreen]: light surfaces + blue accent.
  static const Color _accentBlue = Color(0xFF2196F3);
  static const Color _surface = Color(0xFFF8F9FA);
  static const Color _dark = Color(0xFF1A1A2E);

  static const Color _blue = Color(0xFF00D2FF);
  static const Color _purple = Color(0xFF9249FD);
  static const LinearGradient _grad = LinearGradient(
    colors: [_blue, _purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _errorMessage;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadNotifications();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final token = await AuthService.getToken();
    if (token == null) return;
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseURL}/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {/* ignore */}
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final token = await AuthService.getToken();
    if (token == null) {
      setState(() {
        _loading = false;
        _notifications = [];
        _errorMessage =
            'Session introuvable. Connectez-vous pour voir vos notifications.';
      });
      return;
    }

    final result = await _service.getNotifications(token);

    setState(() {
      _loading = false;
      if (!result.isSuccess) {
        _errorMessage = result.error;
        _notifications = [];
      } else {
        _notifications = result.items;
        _errorMessage = null;
      }
    });

    if (_errorMessage == null) {
      _animCtrl.forward(from: 0);
      _markAllRead();
    }
  }

  String _notifType(String? title) {
    final t = (title ?? '').toLowerCase();
    if (t.contains('acceptée') || t.contains('accepté')) return 'accepted';
    if (t.contains('refusée') || t.contains('refusé')) return 'rejected';
    if (t.contains('livré')) return 'delivered';
    if (t.contains('payé') || t.contains('paiement')) return 'payment';
    return 'new';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _loading ? null : _markAllRead,
            child: Text(
              'Tout lire',
              style: GoogleFonts.plusJakartaSans(
                color: _accentBlue.withValues(alpha: _loading ? 0.4 : 1),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _accentBlue,
        onRefresh: _loadNotifications,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (!_loading && _errorMessage == null && _notifications.isNotEmpty)
              SliverToBoxAdapter(child: _buildCountBanner(theme)),
            if (_loading)
              const SliverFillRemaining(child: _LancyLoader())
            else if (_errorMessage != null)
              SliverFillRemaining(child: _buildError())
            else if (_notifications.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildItemWithHeader(i),
                    childCount: _notifications.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBanner(ThemeData theme) {
    final n = _notifications.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        '$n notification${n != 1 ? 's' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ) ??
            GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildItemWithHeader(int index) {
    final notif = _notifications[index];
    final dateStr = notif['createdAt']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final now = DateTime.now();

    bool showHeader = false;
    String headerLabel = '';

    if (index == 0) {
      showHeader = true;
    } else {
      final prev = DateTime.tryParse(
        _notifications[index - 1]['createdAt'].toString(),
      );
      if (prev != null && date.day != prev.day) showHeader = true;
    }

    if (showHeader) {
      if (date.day == now.day && date.month == now.month) {
        headerLabel = "Aujourd'hui";
      } else if (date.day == now.subtract(const Duration(days: 1)).day) {
        headerLabel = 'Hier';
      } else {
        headerLabel = DateFormat('dd MMM yyyy', 'fr_FR').format(date);
      }
    }

    final animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(
          (index / _notifications.length).clamp(0.0, 1.0),
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) _buildDateHeader(headerLabel),
            _buildNotifCard(notif),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              gradient: _grad,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _accentBlue.withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    final type = _notifType(notif['title']);
    final isRead = notif['read'] ?? notif['isRead'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isRead
                ? Colors.black.withValues(alpha: 0.04)
                : _accentBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isRead
            ? Border.all(color: Colors.grey.shade200)
            : Border.all(color: _accentBlue.withValues(alpha: 0.25)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (!isRead)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentBlue, _purple],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isRead ? 14 : 18,
                14,
                14,
                14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(type, notif),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notif['title'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: _dark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notif['time'] ??
                                  _timeAgo(notif['createdAt']),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notif['message'] ?? '',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String type, Map<String, dynamic> notif) {
    if (type == 'accepted') {
      return _avatarContainer(
        Colors.green.shade50,
        const Text('🎉', style: TextStyle(fontSize: 20)),
      );
    }
    if (type == 'rejected') {
      return _avatarContainer(
        Colors.red.shade50,
        Icon(Icons.close_rounded, color: Colors.red.shade400, size: 20),
      );
    }
    if (type == 'payment') {
      return _avatarContainer(
        Colors.amber.shade50,
        Icon(Icons.payments_rounded,
            color: Colors.amber.shade600, size: 20),
      );
    }
    if (type == 'delivered') {
      return _avatarContainer(
        Colors.blue.shade50,
        Icon(Icons.inventory_2_outlined,
            color: Colors.blue.shade400, size: 20),
      );
    }
    final msg = notif['message']?.toString() ?? '';
    final initials =
        msg.trim().isNotEmpty ? msg.trim()[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _accentBlue.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.plusJakartaSans(
            color: _accentBlue,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _avatarContainer(Color bg, Widget child) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: child),
    );
  }

  String _timeAgo(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    return 'Il y a ${diff.inDays} j';
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 52,
                color: _accentBlue.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tout est calme ici',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous recevrez une notification dès\nqu\'il y a du nouveau.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Une erreur est survenue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LancyLoader extends StatelessWidget {
  const _LancyLoader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF2196F3),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement...',
            style: GoogleFonts.inter(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
