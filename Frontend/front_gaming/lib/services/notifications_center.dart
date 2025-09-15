import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsCenter {
  NotificationsCenter._();
  static final NotificationsCenter instance = NotificationsCenter._();

  // Contatore globale osservabile
  final ValueNotifier<int> notifCount = ValueNotifier<int>(0);

  Timer? _timer;
  bool _started = false;

  // Config API
  final String _apiBase = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token') ??
        prefs.getString('access_token') ??
        prefs.getString('jwt') ??
        prefs.getString('id_token');

    token ??= prefs.getString('user_id'); // fallback dev

    if (token != null && token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7);
    }

    final userId = prefs.getString('user_id');

    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'ProgettogamingApp/1.0',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    if (userId != null && userId.isNotEmpty) {
      h['X-USER-ID'] = userId;
    }
    return h;
  }

  /// Legge quante richieste d'amicizia in arrivo ci sono.
  Future<int> _fetchIncomingFriendRequestsCount() async {
    try {
      final uri = Uri.parse('$_apiBase/api/friends/requests');
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final incoming = (body['incoming'] as List?) ?? const [];
        return incoming.length;
      }
    } catch (_) {}
    return 0;
  }

  /// (Opzionale) Legge un contatore di notifiche generiche.
  Future<int> _fetchOtherUnreadCount() async {
    try {
      final uri = Uri.parse('$_apiBase/api/notifications/unread_count');
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final v = body['count'];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Ricomputa il badge e notifica i listener.
  Future<void> refreshNow() async {
    final friends = await _fetchIncomingFriendRequestsCount();
    final other = await _fetchOtherUnreadCount(); // se l'endpoint non esiste -> 0
    final total = friends + other;
    if (notifCount.value != total) {
      notifCount.value = total;
    }
  }

  /// Avvia il polling periodico (idempotente).
  void start({Duration interval = const Duration(seconds: 30)}) {
    if (_started) return;
    _started = true;

    // primo refresh immediato
    // ignore: discarded_futures
    refreshNow();

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      // ignore: discarded_futures
      refreshNow();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
