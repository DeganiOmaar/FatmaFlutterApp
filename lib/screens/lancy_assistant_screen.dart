import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pfe/service/assistant_service.dart';

/// Lancy Assistant — Groq-powered coach (LANCY scope only).
class LancyAssistantScreen extends StatefulWidget {
  final String token;
  /// `client` or `freelancer` — adapts prompts and suggestions.
  final String role;
  final String? userName;

  const LancyAssistantScreen({
    super.key,
    required this.token,
    this.role = 'freelancer',
    this.userName,
  });

  @override
  State<LancyAssistantScreen> createState() => _LancyAssistantScreenState();
}

class _LancyAssistantScreenState extends State<LancyAssistantScreen> {
  static const Color _skyBlue = Color(0xFF74C0FC);
  static const Color _mintCrystal = Color(0xFF81E38F);
  static const Color _lancyPurple = Color(0xFF8E2DE2);
  static const Color _background = Color(0xFFF9FBFF);
  static const Color _darkText = Color(0xFF1A1C1E);

  late final AssistantService _service;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<AssistantSessionSummary> _sessions = [];
  List<AssistantChatMessage> _messages = [];
  String? _sessionId;
  String _sessionTitle = 'Nouvelle conversation';
  bool _loadingSessions = true;
  bool _loadingChat = false;
  bool _sending = false;
  String? _error;

  bool get _isClient => widget.role.toLowerCase() == 'client';

  List<String> get _suggestions => _isClient
      ? const [
          'Comment rédiger une bonne description de mission ?',
          'Quel budget et délai prévoir pour mon projet ?',
          'Comment choisir la meilleure proposition ?',
          'Comment fonctionne le paiement escrow sur LANCY ?',
        ]
      : const [
          'Comment rédiger une proposition convaincante ?',
          'Idées pour me démarquer sur une mission',
          'Comment améliorer mon profil freelancer ?',
          'Comment fonctionne le paiement escrow sur LANCY ?',
        ];

  String get _emptyIntro => _isClient
      ? 'Je suis Lancy Assistant. Je vous aide sur LANCY : publier des missions, recevoir des propositions, suivi des livrables et bonnes pratiques client.'
      : 'Je suis Lancy Assistant. Je vous aide sur LANCY : propositions, missions, profil et bonnes pratiques freelancer.';

  @override
  void initState() {
    super.initState();
    _service = AssistantService(widget.token);
    _bootstrap();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingSessions = true;
      _error = null;
    });
    final sessions = await _service.listSessions();
    if (!mounted) return;

    if (sessions.isNotEmpty) {
      setState(() {
        _sessions = sessions;
        _loadingSessions = false;
      });
      await _openSession(sessions.first.id, fromBootstrap: true);
      return;
    }

    final created = await _service.createSession();
    if (!mounted) return;
    setState(() {
      _sessions = created != null ? [created] : [];
      _sessionId = created?.id;
      _sessionTitle = created?.title ?? 'Nouvelle conversation';
      _messages = [];
      _loadingSessions = false;
    });
  }

  Future<void> _openSession(String id, {bool fromBootstrap = false}) async {
    setState(() {
      _sessionId = id;
      _loadingChat = true;
      _error = null;
      if (!fromBootstrap) _messages = [];
    });

    final data = await _service.loadSession(id);
    if (!mounted) return;

    if (data == null) {
      setState(() {
        _loadingChat = false;
        _error = 'Impossible de charger la conversation';
      });
      return;
    }

    setState(() {
      _messages = data.messages;
      _sessionTitle = data.sessionTitle ?? _sessionTitle;
      _loadingChat = false;
    });
    _scrollToBottom();
  }

  Future<void> _newConversation() async {
    final created = await _service.createSession();
    if (!mounted || created == null) return;

    setState(() {
      _sessions = [created, ..._sessions.where((s) => s.id != created.id)];
      _sessionId = created.id;
      _sessionTitle = created.title;
      _messages = [];
      _error = null;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteSession(String id) async {
    final ok = await _service.deleteSession(id);
    if (!mounted || !ok) return;

    setState(() {
      _sessions = _sessions.where((s) => s.id != id).toList();
    });

    if (_sessionId == id) {
      if (_sessions.isNotEmpty) {
        await _openSession(_sessions.first.id);
      } else {
        await _newConversation();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending || _sessionId == null) return;

    _input.clear();
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AssistantChatMessage(content: text, isUser: true));
    });
    _scrollToBottom();

    final result = await _service.sendMessage(
      sessionId: _sessionId!,
      message: text,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _sending = false;
        _error = result.error ?? 'Erreur';
        if (_messages.isNotEmpty && _messages.last.isUser) {
          _messages.removeLast();
        }
      });
      return;
    }

    setState(() {
      _sending = false;
      if (result.assistant != null) {
        _messages.add(result.assistant!);
      }
      if (result.sessionTitle != null && result.sessionTitle!.isNotEmpty) {
        _sessionTitle = result.sessionTitle!;
      }
    });

    final refreshed = await _service.listSessions();
    if (mounted && refreshed.isNotEmpty) {
      setState(() => _sessions = refreshed);
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim().split(' ').first
        : (_isClient ? 'Client' : 'Freelancer');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: _buildHistoryDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _darkText,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_skyBlue, _mintCrystal],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lancy Assistant',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _sessionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Historique',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Material(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loadingSessions || _loadingChat
                ? Center(
                    child: CircularProgressIndicator(color: _lancyPurple),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState(greeting)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _sending) {
                            return _buildTypingIndicator();
                          }
                          return _buildBubble(_messages[index]);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.88,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      backgroundColor: _background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: _darkText),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Historique',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _darkText,
                          ),
                        ),
                        Text(
                          'Lancy Assistant',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _newConversation,
                      customBorder: const CircleBorder(),
                      child: Ink(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_skyBlue, _mintCrystal],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _lancyPurple.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_comment_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Conversations',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _skyBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_sessions.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _lancyPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        _skyBlue.withValues(alpha: 0.12),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.forum_outlined,
                                size: 40,
                                color: _skyBlue.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune conversation',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Appuyez sur + pour démarrer',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = _sessions[i];
                        final selected = s.id == _sessionId;
                        final date = s.updatedAt != null
                            ? DateFormat('dd MMM · HH:mm', 'fr_FR')
                                .format(s.updatedAt!.toLocal())
                            : '';
                        return Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(left: 8),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Text('Supprimer ?',
                                        style: GoogleFonts.poppins()),
                                    content: Text(
                                      'Cette conversation sera définitivement supprimée.',
                                      style: GoogleFonts.inter(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text('Supprimer',
                                            style: TextStyle(
                                                color: Colors.red.shade700)),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (_) => _deleteSession(s.id),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                Navigator.pop(context);
                                await _openSession(s.id);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Ink(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? _lancyPurple.withValues(alpha: 0.45)
                                        : Colors.grey.shade200,
                                    width: selected ? 1.5 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: _skyBlue
                                                .withValues(alpha: 0.18),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: selected
                                            ? const LinearGradient(
                                                colors: [
                                                  _skyBlue,
                                                  _mintCrystal,
                                                ],
                                              )
                                            : null,
                                        color: selected
                                            ? null
                                            : _skyBlue
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.chat_rounded,
                                        size: 22,
                                        color: selected
                                            ? Colors.white
                                            : _lancyPurple,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              fontSize: 14,
                                              color: _darkText,
                                            ),
                                          ),
                                          if (date.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              date,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: _mintCrystal,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String greeting) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _skyBlue.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 48, color: _mintCrystal),
                const SizedBox(height: 16),
                Text(
                  'Bonjour $greeting 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _emptyIntro,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Suggestions',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _darkText,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map(
                  (s) => ActionChip(
                    label: Text(s, style: GoogleFonts.inter(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: _skyBlue.withValues(alpha: 0.4)),
                    onPressed: _sending ? null : () => _send(s),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(AssistantChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(colors: [_skyBlue, _mintCrystal])
              : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(color: _mintCrystal.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.content,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: isUser ? Colors.white : _darkText,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _skyBlue.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _lancyPurple,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Lancy réfléchit…',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Posez votre question sur LANCY…',
                hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                filled: true,
                fillColor: _background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _sending ? null : () => _send(),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _sending
                        ? [Colors.grey, Colors.grey]
                        : [_skyBlue, _mintCrystal],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
