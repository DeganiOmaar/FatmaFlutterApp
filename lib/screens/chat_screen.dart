import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../controllers/app_socket_controller.dart';
import '../service/message_service.dart';
import '../service/project_service.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String receiverId;
  final String receiverName;
  final String projectId;
  /// True when the freelancer opens the mission chat (client–freelancer après acceptation).
  final bool isFreelancerMissionChat;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
    required this.projectId,
    this.isFreelancerMissionChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<dynamic> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sendBusy = false;
  Map<String, dynamic>? _participantMeta;

  late final void Function(Map<String, dynamic>) _incomingSub;
  late final void Function(dynamic) _msgErrSub;
  static const Color _blue = Color(0xFF00AEEF);
  static const Color _purple = Color(0xFF8E2DE2);
  static const Color _bg = Color(0xFFEEF2F7);
  static const Color _incomingFill = Color(0xFFF8FAFC);
  static const Color _incomingBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _incomingSub = _handleGlobalIncomingMessage;
    _msgErrSub = _handleSocketMessageError;
    final sock = AppSocketController.to;
    sock.addMessageSubscriber(_incomingSub);
    sock.addMessageErrorSubscriber(_msgErrSub);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = AppSocketController.to;
      c.setFocusedChatProject(widget.projectId.trim());
      c.joinProjectRooms(widget.projectId.trim());
      await _loadMessages();
      if (widget.isFreelancerMissionChat) {
        await _refreshParticipantMeta();
      }
    });
  }

  Future<void> _refreshParticipantMeta() async {
    final m = await ProjectService.fetchParticipantMeta(widget.projectId.trim());
    if (!mounted) return;
    setState(() => _participantMeta = m);
  }

  void _touchProjectRooms() {
    AppSocketController.to.joinProjectRooms(widget.projectId.trim());
  }

  void _handleGlobalIncomingMessage(Map<String, dynamic> normalized) {
    if (!mounted) return;
    _addIncomingSocketMessage(normalized);
  }

  void _handleSocketMessageError(dynamic data) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) {
        if (m is! Map) return false;
        return m['_pending'] == true &&
            _sameUser(m['senderId'], widget.currentUserId);
      });
    });
  }

  bool _sameProject(dynamic rawPid, String localPid) {
    final a = rawPid?.toString().trim() ?? '';
    final b = localPid.trim();
    return a.isNotEmpty && a == b;
  }


  int _timeMs(dynamic raw) {
    if (raw == null) return 0;
    return DateTime.tryParse(raw.toString())?.millisecondsSinceEpoch ?? 0;
  }

  int _compareMessageOrder(Map a, Map b) {
    final c = _timeMs(a['createdAt']).compareTo(_timeMs(b['createdAt']));
    if (c != 0) return c;
    final pa = a['_pending'] == true ? 1 : 0;
    final pb = b['_pending'] == true ? 1 : 0;
    return pa.compareTo(pb);
  }

  void _dedupeAndSortMessages() {
    final byId = <String, Map<String, dynamic>>{};
    final pending = <Map<String, dynamic>>[];
    for (final m in _messages) {
      if (m is! Map) continue;
      final map = Map<String, dynamic>.from(m);
      if (map['_pending'] == true) {
        pending.add(map);
        continue;
      }
      final id = _idString(map['_id']);
      if (id.isNotEmpty) {
        byId[id] = map;
      }
    }
    final merged = byId.values.toList()..addAll(pending);
    merged.sort(_compareMessageOrder);
    _messages
      ..clear()
      ..addAll(merged);
  }

  Future<void> _loadMessages() async {
    final raw = await MessageService.getMessages(widget.projectId);
    if (!mounted) return;

    final fromApi = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) fromApi.add(Map<String, dynamic>.from(e));
    }
    final idsFromApi =
        fromApi.map((m) => m['_id']?.toString()).whereType<String>().toSet();

    final kept = <Map<String, dynamic>>[];
    for (final m in List<dynamic>.from(_messages)) {
      if (m is! Map) continue;
      final mm = Map<String, dynamic>.from(m);
      if (mm['_pending'] == true) {
        kept.add(mm);
        continue;
      }
      final id = mm['_id']?.toString();
      if (id != null && id.isNotEmpty && !idsFromApi.contains(id)) {
        kept.add(mm);
      }
    }

    setState(() {
      _messages.clear();
      _messages.addAll(fromApi);
      _messages.addAll(kept);
      _dropDuplicatesPendingVsReal();
      _dedupeAndSortMessages();
    });
    _scrollToBottom();
  }

  void _addIncomingSocketMessage(Map<String, dynamic> map) {
    if (!_sameProject(map['projectId'], widget.projectId)) return;

    final txt = map['text']?.toString();

    setState(() {
      if (txt != null && _sameUser(map['senderId'], widget.currentUserId)) {
        _messages.removeWhere((m) {
          if (m is! Map) return false;
          return m['_pending'] == true &&
              _sameUser(m['senderId'], widget.currentUserId) &&
              m['text']?.toString() == txt;
        });
      }

      final mid = _idString(map['_id']);
      if (mid.isNotEmpty &&
          _messages.any(
            (mm) =>
                mm is Map && _idString(mm['_id']) == mid,
          )) {
        return;
      }

      _messages.add(Map<String, dynamic>.from(map));
      _dedupeAndSortMessages();
    });
    _scrollToBottom();
  }

  /// Une bulle "Envoi…" inutile si le même message est déjà en base.
  void _dropDuplicatesPendingVsReal() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final raw = _messages[i];
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      if (m['_pending'] != true) continue;
      final sid = _idString(m['senderId']);
      final txt = m['text']?.toString();
      if (sid.isEmpty || txt == null) continue;
      final superseded = _messages.any((o) {
        if (identical(o, raw) || o is! Map) return false;
        final om = Map<String, dynamic>.from(o);
        if (om['_pending'] == true) return false;
        return _idString(om['senderId']) == sid &&
            om['text']?.toString() == txt;
      });
      if (superseded) _messages.removeAt(i);
    }
  }

  String _idString(dynamic v) {
    if (v == null) return '';
    if (v is Map && v[r'$oid'] != null) {
      return v[r'$oid'].toString().trim();
    }
    final s = v.toString().trim();
    if (s == 'null') return '';
    return s;
  }

  bool _sameUser(dynamic senderId, String userId) =>
      _idString(senderId).isNotEmpty &&
      userId.trim().isNotEmpty &&
      _idString(senderId) == userId.trim();

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sendBusy) return;

    final projectId = widget.projectId.trim();
    final sender = widget.currentUserId.trim();
    final receiver = widget.receiverId.trim();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final optimistic = {
      '_id': 'pending_$ts',
      'senderId': sender,
      'receiverId': receiver,
      'projectId': projectId,
      'text': text,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      '_pending': true,
    };

    _controller.clear();

    setState(() {
      _messages.add(optimistic);
      _dedupeAndSortMessages();
    });
    _scrollToBottom();

    _touchProjectRooms();

    _sendBusy = true;
    try {
      /** Source de vérité : API — le serveur enregistre et diffuse aussi en websocket. */
      await MessageService.sendMessage(projectId, sender, receiver, text);
      if (!mounted) return;
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) {
          if (m is! Map) return false;
          return m['_pending'] == true &&
              _sameUser(m['senderId'], sender) &&
              m['text']?.toString() == text;
        });
      });
      final err = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _sendBusy = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  Map<String, dynamic>? _adminSubmissionMap() {
    final raw = _participantMeta?['adminWorkSubmission'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<void> _showAdminDeliverySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AdminDeliverySheet(
        projectId: widget.projectId.trim(),
        hostContext: context,
        onRefreshMeta: _refreshParticipantMeta,
      ),
    );
  }

  Widget _buildFreelancerAdminBar() {
    if (!widget.isFreelancerMissionChat) return const SizedBox.shrink();

    final pay = _participantMeta?['paymentStatus']?.toString() ?? '';
    final smap = _adminSubmissionMap();
    final status = smap?['status']?.toString() ?? 'none';

    if (_participantMeta == null) {
      return Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chargement du statut livrable…',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (pay != 'escrow_locked') {
      return Material(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le paiement escrow n’est pas actif pour cette mission — envoi de livrable indisponible.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'pending_client' || status == 'pending_review') {
      return Material(
        color: const Color(0xFFEFF6FF),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Livrable envoyé au client — en attente de sa validation.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'client_approved' || status == 'approved') {
      return Material(
        color: const Color(0xFFECFDF5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le client a validé — l’administration va libérer le paiement sur votre wallet.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'client_rejected' || status == 'rejected') {
      final note = smap?['reviewNote']?.toString().trim() ?? '';
      return Material(
        color: const Color(0xFFFEF2F2),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.flag_outlined, color: Colors.red.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note.isEmpty
                          ? 'Le client demande des corrections. Renvoyez un livrable.'
                          : 'Retour client : $note',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: _showAdminDeliverySheet,
                child: const Text('Renvoyer un livrable'),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Travail terminé ? Envoyez fichiers / lien / message au client pour validation, puis l’admin libère l’escrow.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.35,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _showAdminDeliverySheet,
              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
              label: const Text('Envoyer le livrable'),
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _bubbleTime(dynamic raw) {
    if (raw == null) return '';
    final dt =
        raw is String ? DateTime.tryParse(raw) : DateTime.tryParse('$raw');
    if (dt == null) return '';
    return DateFormat.Hm('fr_FR').format(dt.toLocal());
  }

  @override
  void dispose() {
    final sock = AppSocketController.to;
    sock.removeMessageSubscriber(_incomingSub);
    sock.removeMessageErrorSubscriber(_msgErrSub);
    sock.setFocusedChatProject(null);
    sock.leaveProjectRooms(widget.projectId.trim());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _blue.withValues(alpha: 0.14),
              child: Text(
                widget.receiverName.isNotEmpty
                    ? widget.receiverName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _purple,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Conversation mission',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Obx(() {
              final live = AppSocketController.to.socketConnected;
              return Tooltip(
                message: live
                    ? 'Messagerie connectée (socket global)'
                    : 'Reconnexion… Les messages partent encore par API',
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color:
                      live ? Colors.green.shade600 : Colors.amber.shade700,
                ),
              );
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_rounded,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun message pour l’instant',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Envoyez un message pour démarrer '
                            'l’échange avec ${widget.receiverName}.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.4,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      if (msg is! Map) return const SizedBox.shrink();

                      final isMe =
                          _sameUser(msg['senderId'], widget.currentUserId);
                      final pending = msg['_pending'] == true;
                      final body = msg['text']?.toString() ?? '';
                      final time = pending
                          ? 'Envoi…'
                          : _bubbleTime(msg['createdAt']);

                      return Opacity(
                        opacity: pending && isMe ? 0.92 : 1,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    _incomingBorder.withValues(alpha: 0.8),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 0.78,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isMe
                                      ? const LinearGradient(
                                          colors: [_blue, _purple],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color:
                                      isMe ? null : _incomingFill,
                                  borderRadius: BorderRadius.only(
                                    topLeft:
                                        Radius.circular(isMe ? 18 : 6),
                                    topRight:
                                        Radius.circular(isMe ? 6 : 18),
                                    bottomLeft:
                                        const Radius.circular(18),
                                    bottomRight:
                                        const Radius.circular(18),
                                  ),
                                  border: isMe
                                      ? null
                                      : Border.all(
                                          color: _incomingBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      body,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        height: 1.42,
                                        color: isMe
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      time,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        color: isMe
                                            ? Colors.white
                                                .withValues(alpha: 0.85)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    _blue.withValues(alpha: 0.2),
                                child: Icon(
                                  pending
                                      ? Icons.schedule_rounded
                                      : Icons.check_rounded,
                                  size: 16,
                                  color: _blue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                    },
                  ),
                ),
          _buildFreelancerAdminBar(),
          Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black26,
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization:
                              TextCapitalization.sentences,
                          style: GoogleFonts.inter(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Message…',
                            hintStyle: GoogleFonts.inter(
                              color: Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_blue, _purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4000AEEF),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _send,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
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

class _AdminDeliverySheet extends StatefulWidget {
  const _AdminDeliverySheet({
    required this.projectId,
    required this.hostContext,
    required this.onRefreshMeta,
  });

  final String projectId;
  final BuildContext hostContext;
  final Future<void> Function() onRefreshMeta;

  @override
  State<_AdminDeliverySheet> createState() => _AdminDeliverySheetState();
}

class _AdminDeliverySheetState extends State<_AdminDeliverySheet> {
  late final TextEditingController _linkCtrl;
  late final TextEditingController _msgCtrl;
  final List<File> _picked = [];

  @override
  void initState() {
    super.initState();
    _linkCtrl = TextEditingController();
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final err = await ProjectService.submitAdminDelivery(
      widget.projectId,
      message: _msgCtrl.text.trim(),
      demoLink: _linkCtrl.text.trim(),
      files: List<File>.from(_picked),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!widget.hostContext.mounted) return;
    if (err == null) {
      await widget.onRefreshMeta();
      if (!widget.hostContext.mounted) return;
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        const SnackBar(
          content: Text('Livrable envoyé au client'),
        ),
      );
    } else {
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Livrable pour le client',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des fichiers, un lien et un message. Le client validera dans le suivi de mission ; ensuite l’admin libère le paiement.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _linkCtrl,
              decoration: const InputDecoration(
                labelText: 'Lien (optionnel)',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message au client',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final r = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                    type: FileType.any,
                  );
                  if (r == null || !mounted) return;
                  setState(() {
                    _picked.clear();
                    for (final f in r.files) {
                      final p = f.path;
                      if (p != null) _picked.add(File(p));
                    }
                  });
                },
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  _picked.isEmpty
                      ? 'Ajouter des fichiers'
                      : '${_picked.length} fichier(s)',
                ),
              ),
            ),
            if (_picked.isNotEmpty)
              Text(
                _picked.map((f) => f.path.split('/').last).join(', '),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Text('Envoyer au client'),
            ),
          ],
        ),
      ),
    );
  }
}
