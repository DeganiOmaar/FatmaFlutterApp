import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';

/// Une seule connexion Socket.io pour toute l’app (persistante tant que session active).
class AppSocketController extends GetxController {
  static AppSocketController get to => Get.find();

  io.Socket? _socket;

  String? _userId;
  String? _emailFallback;

  /// Projet ouvert dans [ChatScreen] — pas de toast entrant tant qu’on lit ce chat.
  String? _focusedChatProjectId;

  final RxBool socketConnectedObs = false.obs;

  bool get socketConnected =>
      socketConnectedObs.value && (_socket?.connected ?? false);

  /// Home : mise à jour compteur / historique (notifs métier hors chat).
  void Function(Map<String, dynamic> payload)? onProposalPushHome;

  final List<void Function(Map<String, dynamic>)> _messageSubscribers = [];
  final List<void Function(dynamic)> _messageErrorSubscribers = [];

  void addMessageSubscriber(void Function(Map<String, dynamic>) fn) {
    if (!_messageSubscribers.contains(fn)) {
      _messageSubscribers.add(fn);
    }
  }

  void removeMessageSubscriber(void Function(Map<String, dynamic>) fn) {
    _messageSubscribers.remove(fn);
  }

  void addMessageErrorSubscriber(void Function(dynamic data) fn) {
    if (!_messageErrorSubscribers.contains(fn)) {
      _messageErrorSubscribers.add(fn);
    }
  }

  void removeMessageErrorSubscriber(void Function(dynamic data) fn) {
    _messageErrorSubscribers.remove(fn);
  }

  void setFocusedChatProject(String? projectId) {
    final v = projectId?.trim();
    _focusedChatProjectId = (v == null || v.isEmpty) ? null : v;
  }

  void joinProjectRooms(String projectId) {
    final pid = projectId.trim();
    if (pid.isEmpty || _socket == null || !_socket!.connected) return;
    final uid = _userId ?? '';
    if (uid.isNotEmpty) {
      _socket!.emit('join_project_chat', {
        'userId': uid,
        'projectId': pid,
      });
    }
  }

  void leaveProjectRooms(String projectId) {
    final pid = projectId.trim();
    if (pid.isEmpty || _socket == null) return;
    _socket!.emit('leave_project_chat', {'projectId': pid});
  }

  Future<void> ensureConnected({
    required String userId,
    String? emailFallback,
  }) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;

    final emailNorm = emailFallback?.trim().toLowerCase();

    final prev = _userId;
    if (prev != null && prev.isNotEmpty && prev != trimmed) {
      disconnectLogout();
    }

    _userId = trimmed;
    if (emailNorm != null && emailNorm.isNotEmpty) {
      _emailFallback = emailNorm;
    }

    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      Future<void>.delayed(Duration.zero, _emitJoin);
      socketConnectedObs.value = _socket!.connected;
      return;
    }

    _socket = io.io(ApiConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'forceNew': false,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionAttempts': 120,
    });

    _socket!.onConnect((_) {
      _emitJoin();
      socketConnectedObs.value = true;
      if (kDebugMode) debugPrint('✅ Socket app connecté');
    });

    _socket!.onReconnect((_) {
      _emitJoin();
      socketConnectedObs.value = true;
      if (kDebugMode) debugPrint('🔁 Socket app reconnect');
    });

    _socket!.onConnectError((_) {
      socketConnectedObs.value = false;
    });

    _socket!.onDisconnect((_) {
      socketConnectedObs.value = false;
    });

    _socket!.on('notification', _onProposalNotificationRaw);
    _socket!.on('receive_message', _onReceiveMessageRaw);
    _socket!.on('message_error', _onMessageErrorRaw);

    if (!_socket!.connected) {
      _socket!.connect();
    }
  }

  /// Ferme le socket mais garde l’identité (pour ne pas perdre les abonnés des écrans).
  void _closeSocketTransportOnly() {
    try {
      _socket?.off('notification');
      _socket?.off('receive_message');
      _socket?.off('message_error');
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    socketConnectedObs.value = false;
  }

  void _emitJoin() {
    final s = _socket;
    if (s == null || !s.connected) return;
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      s.emit('join', uid);
      return;
    }
    final em = _emailFallback;
    if (em != null && em.isNotEmpty) {
      s.emit('join', em);
    }
  }

  void _onProposalNotificationRaw(dynamic data) {
    if (data == null || data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    onProposalPushHome?.call(m);
    if (kDebugMode) debugPrint('🔔 Notification: ${m["title"]}');
    Get.snackbar(
      (m["title"] ?? "Notification").toString(),
      (m["message"] ?? "").toString(),
      backgroundColor: Colors.white,
      colorText: const Color(0xFF1E293B),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
    );
  }

  Map<String, dynamic>? _coerceMessageMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      final first = data.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  String _idPart(dynamic v) {
    if (v == null) return '';
    if (v is Map && v[r'$oid'] != null) {
      return v[r'$oid'].toString().trim();
    }
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    return s;
  }

  void _onReceiveMessageRaw(dynamic data) {
    final normalized = _coerceMessageMap(data);
    if (normalized == null) return;

    for (final fn in List<
        void Function(Map<String, dynamic>)>.from(_messageSubscribers)) {
      try {
        fn(Map<String, dynamic>.from(normalized));
      } catch (e, st) {
        if (kDebugMode) debugPrint('message subscriber error: $e\n$st');
      }
    }

    final myId = _userId ?? '';
    if (myId.isEmpty) return;
    final sender = _idPart(normalized['senderId']);
    final receiver = _idPart(normalized['receiverId']);
    if (sender == myId) return;
    if (receiver != myId) return;

    final pid = normalized['projectId']?.toString().trim() ?? '';
    if (pid.isNotEmpty && pid == _focusedChatProjectId) return;

    final text = normalized['text']?.toString() ?? '';
    final preview = text.length > 140 ? '${text.substring(0, 140)}…' : text;
    Get.snackbar(
      'Nouveau message',
      preview.isEmpty ? '(message)' : preview,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      backgroundColor: Colors.white,
      colorText: const Color(0xFF0F172A),
    );
  }

  void _onMessageErrorRaw(dynamic data) {
    for (final fn
        in List<void Function(dynamic)>.from(_messageErrorSubscribers)) {
      try {
        fn(data);
      } catch (e, st) {
        if (kDebugMode) debugPrint('message_error subscriber error: $e\n$st');
      }
    }
    final msg = data is Map ? data['message']?.toString() : null;
    Get.snackbar(
      'Message',
      msg ?? 'Impossible d’envoyer le message',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
    );
  }

  void disconnectLogout() {
    _closeSocketTransportOnly();
    _userId = null;
    _emailFallback = null;
    _focusedChatProjectId = null;
    onProposalPushHome = null;
    _messageSubscribers.clear();
    _messageErrorSubscribers.clear();
  }

  @override
  void onClose() {
    disconnectLogout();
    super.onClose();
  }
}
