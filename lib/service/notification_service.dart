import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pfe/config/api_config.dart';

/// Result of fetching notifications so the UI can show errors instead of a false empty state.
class NotificationsFetchResult {
  final List<Map<String, dynamic>> items;
  final String? error;

  const NotificationsFetchResult._({required this.items, this.error});

  factory NotificationsFetchResult.success(List<Map<String, dynamic>> items) =>
      NotificationsFetchResult._(items: items);

  factory NotificationsFetchResult.failure(String message) =>
      NotificationsFetchResult._(items: [], error: message);

  bool get isSuccess => error == null;
}

class NotificationService {
  final String baseUrl = "${ApiConfig.origin}/api/notifications";

  Future<NotificationsFetchResult> getNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          return NotificationsFetchResult.failure(
              'Réponse invalide du serveur.');
        }
        final list = <Map<String, dynamic>>[];
        for (final raw in decoded) {
          if (raw is! Map) continue;
          final e = Map<String, dynamic>.from(raw);
          list.add({
            'title': e['title'] ?? '',
            'message': e['message'] ?? '',
            'createdAt': e['createdAt'],
            'time': _formatTime(e['createdAt']),
            'isRead': e['isRead'] ?? false,
            'read': e['read'],
            'isToday': _isToday(e['createdAt']),
          });
        }
        return NotificationsFetchResult.success(list);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return NotificationsFetchResult.failure(
            'Session expirée. Reconnectez-vous.');
      }
      return NotificationsFetchResult.failure(
          'Impossible de charger les notifications (${response.statusCode}).');
    } catch (e) {
      return NotificationsFetchResult.failure(
          'Pas de connexion. Vérifiez votre réseau.');
    }
  }

  bool _isToday(dynamic isoDate) {
    if (isoDate == null) return false;

    final dt = DateTime.tryParse(isoDate.toString());
    if (dt == null) return false;

    final local = dt.toLocal();
    final now = DateTime.now();

    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  Future<void> markAllRead(String token) async {
    try {
      await http.put(
        Uri.parse("$baseUrl/read-all"),
        headers: {"Authorization": "Bearer $token"},
      );
    } catch (_) {}
  }

  String _formatTime(dynamic isoDate) {
    if (isoDate == null) return '';

    final dt = DateTime.tryParse(isoDate.toString());
    if (dt == null) return '';

    final local = dt.toLocal();
    return "${local.hour}:${local.minute.toString().padLeft(2, '0')}";
  }
 

}
