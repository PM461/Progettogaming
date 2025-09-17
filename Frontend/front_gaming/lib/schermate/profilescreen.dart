import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:front_gaming/services/profile_service.dart';
import 'package:front_gaming/controllers/profile_controller.dart';
import 'package:front_gaming/schermate/FriendLibraryScreen.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ---------- Helpers robusti per ID/Nome/Avatar ----------
  String _extractFriendId(Map<String, dynamic> f) {
    final nested =
        (f['friend'] ?? f['friend_user'] ?? f['user']) as Map<String, dynamic>?;
    if (nested != null) {
      final id = (nested['id'] ?? nested['_id'])?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    final id =
        (f['friend_id'] ?? f['user_id'] ?? f['id'] ?? f['_id'])?.toString();
    return id ?? '';
  }

  Widget _avatarFrom(Map<String, dynamic> u, {double radius = 20}) {
    // prova vari campi comuni: picture / avatar / profile_image / profileImageUrl
    final pic = (u['picture'] ??
                u['avatar'] ??
                u['profile_image'] ??
                u['profileImageUrl'] ??
                '')
            ?.toString() ??
        '';

    return CircleAvatar(
      radius: radius,
      backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
      child: pic.isEmpty ? const Icon(Icons.person) : null,
    );
  }

  int _notifCount = 0;
  Timer? _notifTimer;

  int get _friendRequestsCount => _incoming.length;

// endpoint opzionale; va bene anche se non esiste (fallback a 0)
  Future<int> _getUnreadNotifCountSafe() async {
    try {
      final uri = Uri.parse('$_apiBase/api/notifications/unread_count');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final v = body['count'];
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? 0;
        if (v is num) return v.toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _recomputeBadge() async {
    // somma richieste amici + eventuali notifiche generiche
    final other = await _getUnreadNotifCountSafe();
    final total = _friendRequestsCount + other;
    if (!mounted) return;
    setState(() => _notifCount = total);
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 'on';
    }
    return false;
  }

  Future<bool> _fetchIsPrivate(String fid) async {
    // 1) prova endpoint dedicato
    try {
      final uri = Uri.parse('$_apiBase/api/users/$fid/privacy');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return _asBool(body['is_private']);
      }
      // se 404 o altro → passa al fallback
    } catch (_) {
      // ignora, prova fallback
    }

    // 2) fallback su /user/{id}/games
    try {
      final gUri = Uri.parse('$_apiBase/user/$fid/games');
      final gRes = await http.get(gUri, headers: _headers);

      if (gRes.statusCode >= 200 && gRes.statusCode < 300) {
        return false; // pubblico: riesco a leggere i giochi
      }
      if (gRes.statusCode == 401 || gRes.statusCode == 403) {
        return true; // privato/bloccato
      }
      // altri errori di rete → trattiamo come privato per sicurezza
      return true;
    } catch (_) {
      return true; // errore rete → non apriamo
    }
  }

  Map<String, dynamic>? _extractOutgoingRecipient(dynamic r) {
    if (r is Map<String, dynamic>) {
      // cerca utente annidato
      final nested =
          r['recipient'] ?? r['recipient_user'] ?? r['user'] ?? r['friend'];
      if (nested is Map<String, dynamic>) return nested;

      // a volte l'oggetto stesso è già l'utente
      if (r.containsKey('username') ||
          r.containsKey('nickname') ||
          r.containsKey('name') ||
          r.containsKey('display_name')) {
        return r;
      }

      // fallback se abbiamo solo un id
      final rid = (r['recipient_id'] ?? r['user_id'] ?? r['id'] ?? r['_id']);
      if (rid != null) return {'id': rid.toString()};
    }

    // se è una stringa, trattala come id
    if (r is String && r.isNotEmpty) {
      return {'id': r};
    }
    return null;
  }

  String _displayNameFromUserMap(Map<String, dynamic> u) {
    final s =
        (u['username'] ?? u['nickname'] ?? u['name'] ?? u['display_name']);
    if (s is String && s.trim().isNotEmpty) return s.trim();
    final id = (u['id'] ?? u['_id'])?.toString() ?? '';
    if (id.length >= 4) return 'Utente#${id.substring(id.length - 4)}';
    return 'Utente';
  }

  Future<void> _loadPrivacy() async {
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/api/users/me/privacy'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (mounted) setState(() => _isPrivate = (body['is_private'] == true));
      } else {
        if (mounted) setState(() => _isPrivate = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isPrivate = false);
    }
  }

  Future<void> _setPrivacy(bool value) async {
    try {
      final uri = Uri.parse('$_apiBase/api/users/me/privacy');

      final headers = {
        ..._headers,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'ProgettogamingApp/1.0',
      };

      final res = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode({'is_private': value}),
      );

      if (res.statusCode == 200) {
        if (mounted) setState(() => _isPrivate = value);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(value
                  ? 'Profilo impostato su privato'
                  : 'Profilo impostato su pubblico')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore privacy: ${res.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore rete nel cambio privacy')),
      );
    }
  }

  String _extractFriendName(Map<String, dynamic> f) {
    final nested =
        (f['friend'] ?? f['friend_user'] ?? f['user']) as Map<String, dynamic>?;

    String? pick(Map<String, dynamic> m) {
      final name =
          (m['username'] ?? m['nickname'] ?? m['name'] ?? m['display_name'])
              ?.toString();
      if (name != null && name.trim().isNotEmpty) return name.trim();
      // Niente fallback su email: non vogliamo mostrarla.
      return null;
    }

    if (nested != null) {
      final n = pick(nested);
      if (n != null) return n;
    }
    final n2 = pick(f);
    if (n2 != null) return n2;

    final id = _extractFriendId(f);
    if (id.isNotEmpty && id.length >= 4)
      return 'Utente#${id.substring(id.length - 4)}';
    return 'Utente';
  }

  Widget _avatarFromAny(Map<String, dynamic> f) {
    final nested =
        (f['friend'] ?? f['friend_user'] ?? f['user']) as Map<String, dynamic>?;
    final pic = (nested?['picture'] ??
        nested?['avatar'] ??
        f['picture'] ??
        f['avatar'] ??
        '') as String;
    return CircleAvatar(
      backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
      child: pic.isEmpty ? const Icon(Icons.person) : null,
    );
  }

  // ----------- Variabili per amici/ricerca/agenda ----------
  final String _apiBase = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  String? _token;
  final Map<String, bool> _friendIsPrivate = {}; // friendId -> true/false
  final Set<String> _privacyLoadingIds = {};
  List<dynamic> _friends = [];
  List<dynamic> _incoming = [];
  List<dynamic> _outgoing = [];
  List<dynamic> _searchResults = [];
  final TextEditingController _friendSearch = TextEditingController();
  bool _loadingFriends = false;
  bool? _isPrivate;

  // ----------- Variabili profilo correntemente loggato ----------
  String? _selectedImageName;
  String? _nickname;
  String? _email;
  String? _creationDate;
  String? _steamId;
  final ProfileController _controller = ProfileController(ProfileService());
  final List<String> availableImages = List.generate(6, (i) => '$i');
  String? userId;

  @override
  void initState() {
    super.initState();
    _boot();
    // piccolo polling per aggiornare il badge ogni 30s
    _notifTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _recomputeBadge());
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _friendSearch.dispose();
    super.dispose();
  }

  // ---------- Privacy amici ----------
  Future<void> _prefetchPrivacyForFriends() async {
    for (final f in _friends) {
      final fid = _extractFriendId(f);
      if (fid.isEmpty) continue;
      // non bloccare la UI
      // ignore: unawaited_futures
      _isFriendPrivate(fid);
    }
  }

  /// Ritorna true se il profilo è privato.
  Future<bool> _isFriendPrivate(String fid, {bool force = false}) async {
    // usa la cache salvo forzatura
    if (!force && _friendIsPrivate.containsKey(fid)) {
      return _friendIsPrivate[fid]!;
    }

    // segna che stai caricando per questo fid (opzionale se già lo fai altrove)
    _privacyLoadingIds.add(fid);
    try {
      final uri = Uri.parse('$_apiBase/api/users/$fid/privacy');
      final res = await http.get(uri, headers: _headers);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final isPriv = (body['is_private'] == true);
        if (mounted) setState(() => _friendIsPrivate[fid] = isPriv);
        return isPriv;
      }

      // in caso di errore, per sicurezza trattiamo come privato
      if (mounted) setState(() => _friendIsPrivate[fid] = true);
      return true;
    } catch (_) {
      if (mounted) setState(() => _friendIsPrivate[fid] = true);
      return true;
    } finally {
      _privacyLoadingIds.remove(fid);
    }
  }

  // ---------- Boot ----------
  Future<void> _boot() async {
    await _loadUserId();
    await _loadToken();
    await _loadPrivacy();

    await Future.wait([
      _loadNickname(),
      _loadProfileImage(),
      _loadEmail(),
      _loadCreationDate(),
      _loadSteamId(),
    ]);

    await _loadAllFriendsData();
  }

  // ---------- Auth/Prefs ----------
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? t = prefs.getString('token') ??
        prefs.getString('access_token') ??
        prefs.getString('jwt') ??
        prefs.getString('id_token');

    t ??= prefs.getString('user_id'); // fallback DEV: ObjectId come token
    if (t != null && t.toLowerCase().startsWith('bearer ')) {
      t = t.substring(7);
    }
    if (mounted) setState(() => _token = t);
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    if (userId != null && userId!.isNotEmpty) {
      h['X-USER-ID'] = userId!; // fallback DEV
    }
    return h;
  }

  // ---------- Amici: API ----------
  Future<void> _loadAllFriendsData() async {
    if (_token == null) return;
    setState(() => _loadingFriends = true);
    await Future.wait([_loadFriends(), _loadRequests()]);
    if (mounted) setState(() => _loadingFriends = false);
  }

  Future<void> _loadFriends() async {
    try {
      final res = await http.get(Uri.parse('$_apiBase/api/friends/list'),
          headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => _friends = data is List ? data : []);
        if (mounted) setState(() => _friends = data is List ? data : []);

// Prefetch privacy (non blocca la UI)
        for (final f in _friends) {
          if (f is! Map<String, dynamic>) continue;
          final fid = _extractFriendId(f);
          if (fid.isEmpty) continue;
          // ignora l'await per farlo in background
          _isFriendPrivate(fid);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRequests() async {
    try {
      final res = await http.get(Uri.parse('$_apiBase/api/friends/requests'),
          headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _incoming = (data['incoming'] ?? []) as List<dynamic>;
            _outgoing = (data['outgoing'] ?? []) as List<dynamic>;
          });
          await _recomputeBadge();
        }
      }
    } catch (_) {}
  }

  Future<void> _searchUsers(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse(
            '$_apiBase/api/users/search?q=${Uri.encodeQueryComponent(query)}'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => _searchResults = data is List ? data : []);
      } else {
        if (mounted) {
          setState(() => _searchResults = []);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore ricerca: ${res.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchResults = []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore di rete nella ricerca')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/api/friends/request'),
        headers: _headers,
        body: jsonEncode({'user_id': targetUserId}),
      );
      final ok = res.statusCode == 201 || res.statusCode == 200;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ok ? 'Richiesta inviata' : 'Errore: ${res.body}')),
        );
      }
      await _loadAllFriendsData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Errore di rete durante l’invio richiesta')),
        );
      }
    }
  }

  Future<void> _acceptFriend(String requesterUserId) async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/api/friends/accept'),
        headers: _headers,
        body: jsonEncode({'user_id': requesterUserId}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.statusCode == 200
                  ? 'Amicizia confermata'
                  : 'Errore: ${res.body}')),
        );
      }
      await _loadAllFriendsData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Errore di rete durante l’accettazione')),
        );
      }
    }
  }

  Future<void> _rejectFriend(String requesterUserId) async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/api/friends/reject'),
        headers: _headers,
        body: jsonEncode({'user_id': requesterUserId}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.statusCode == 200
                  ? 'Richiesta rifiutata'
                  : 'Errore: ${res.body}')),
        );
      }
      await _loadAllFriendsData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore di rete durante il rifiuto')),
        );
      }
    }
  }

  Future<void> _removeFriend(String otherUserId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_apiBase/api/friends/$otherUserId'),
        headers: _headers,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.statusCode == 200
                  ? 'Amico rimosso'
                  : 'Errore: ${res.body}')),
        );
      }
      await _loadAllFriendsData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore di rete durante la rimozione')),
        );
      }
    }
  }

  // ---------- Profilo correntemente loggato ----------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('profile_image');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _loadSteamId() async {
    if (userId == null) return;
    final steamId = await _controller.loadSteamId(userId!);
    setState(() => _steamId = steamId);
  }

  Future<void> _loadCreationDate() async {
    if (userId == null) return;
    final date = await _controller.loadCreationDate(userId!);
    if (date != null) {
      setState(() => _creationDate = date);
    }
  }

  Future<void> _loadEmail() async {
    if (userId == null) return;
    final email = await _controller.loadEmail(userId!);
    if (email != null) {
      setState(() => _email = email);
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
  }

  Future<void> _loadNickname() async {
    if (userId == null) return;
    final nickname = await _controller.loadNickname(userId!);
    if (nickname != null) {
      setState(() => _nickname = nickname);
    }
  }

  Future<void> _loadProfileImage() async {
    if (userId == null) return;
    final imageName = await _controller.loadProfileImage(userId!);
    if (imageName != null) {
      setState(() => _selectedImageName = imageName);
    }
  }

  Future<void> _setProfileImage(String imageName) async {
    if (userId == null) return;

    final success = await _controller.setProfileImage(userId!, imageName);
    if (!mounted) return;

    if (success) {
      setState(() => _selectedImageName = imageName);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel salvataggio della foto')),
      );
    }
  }

  void _showImagePickerPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('profile_image');
    if (saved != null && mounted) {
      setState(() => _selectedImageName = saved);
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seleziona immagine profilo'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: availableImages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (ctx, index) {
              final imageName = availableImages[index];
              return GestureDetector(
                onTap: () => _setProfileImage(imageName),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundImage:
                          AssetImage('images/propic/$imageName.png'),
                    ),
                    if (imageName == _selectedImageName)
                      const Positioned(
                        child: Icon(Icons.check_circle, color: Colors.green),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(value)),
          ],
        ),
      );

  // ----------------- UI AMICI -----------------
  Widget _friendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text('Amici',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _friendSearch,
          onSubmitted: _searchUsers,
          decoration: InputDecoration(
            hintText: 'Cerca utente...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _searchUsers(_friendSearch.text),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_searchResults.isNotEmpty) _searchResultsList(),
        if (_searchResults.isNotEmpty) const SizedBox(height: 24),
        _incomingList(),
        const SizedBox(height: 16),
        _friendsList(),
        const SizedBox(height: 16),
        _outgoingList(),
        if (_loadingFriends) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _searchResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Risultati ricerca',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ListView.separated(
          itemCount: _searchResults.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final u = _searchResults[i] as Map<String, dynamic>;
            final uid = (u['id'] ?? '') as String;
            return ListTile(
              leading: _avatarFromAny(u),
              title:
                  Text(u['name'] ?? u['nickname'] ?? u['username'] ?? 'Utente'),
              trailing: IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () => _sendFriendRequest(uid),
                tooltip: 'Invia richiesta',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _incomingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Richieste in arrivo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (_incoming.isEmpty) const Text('Nessuna richiesta in arrivo'),
        if (_incoming.isNotEmpty)
          ListView.separated(
            itemCount: _incoming.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = _incoming[i] as Map<String, dynamic>;
              final requester = (r['requester'] ?? {}) as Map<String, dynamic>;
              final requesterId = (requester['id'] ?? '') as String;
              return ListTile(
                leading: _avatarFromAny(r),
                title: Text(
                  requester['name'] ??
                      requester['nickname'] ??
                      requester['username'] ??
                      'Utente',
                ),
                subtitle: const Text('Ti ha inviato una richiesta d’amicizia'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _acceptFriend(requesterId),
                      tooltip: 'Accetta',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => _rejectFriend(requesterId),
                      tooltip: 'Rifiuta',
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _friendsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('I miei amici',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (_friends.isEmpty) const Text('Non hai ancora amici'),
        if (_friends.isNotEmpty)
          ListView.separated(
              itemCount: _friends.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final f = _friends[i] as Map<String, dynamic>;
                final fid = _extractFriendId(f);
                final friendName = _extractFriendName(f);

                return ListTile(
                  leading: _avatarFromAny(f),
                  title: Text(friendName),
                  onTap: () async {
                    final isPriv = await _fetchIsPrivate(fid);
                    if (!mounted) return;
                    if (isPriv) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profilo privato')),
                      );
                      return; // non aprire
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FriendLibraryScreen(
                          friendId: fid,
                          friendName: friendName,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove),
                    onPressed: () => _removeFriend(fid),
                    tooltip: 'Rimuovi amico',
                  ),
                );
              }),
      ],
    );
  }

  Widget _outgoingList() {
    final items = List<Map<String, dynamic>>.from(
      _outgoing.whereType<Map<String, dynamic>>(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Richieste inviate',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Text('Nessuna richiesta inviata')
        else
          ListView.separated(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = items[i];
              final recipient = (r['recipient'] ?? {}) as Map<String, dynamic>;
              final name = (recipient['username'] ??
                      recipient['nickname'] ??
                      recipient['name'] ??
                      'Utente')
                  .toString();
              return ListTile(
                leading: _avatarFrom(recipient),
                title: Text(name),
                subtitle: const Text('In attesa di conferma'),
              );
            },
          ),
      ],
    );
  }

  void _openNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications),
                    const SizedBox(width: 8),
                    Text('Notifiche',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (_notifCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$_notifCount',
                            style: const TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_friendRequestsCount > 0)
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1),
                    title: Text('Richieste d’amicizia: $_friendRequestsCount'),
                    subtitle:
                        const Text('Apri la sezione richieste per gestirle'),
                    onTap: () {
                      Navigator.pop(ctx);
                      // qui puoi fare scroll alla sezione richieste, oppure niente
                    },
                  ),
                if (_friendRequestsCount == 0)
                  const Text('Nessuna richiesta d’amicizia'),
                const SizedBox(height: 8),
                // puoi aggiungere eventuali altre categorie...
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final accent = cs.secondary;
    final imagePath = _selectedImageName != null
        ? 'images/propic/${_selectedImageName!}.png'
        : 'images/propic/1.png';

    return Scaffold(
      appBar: CustomAppBar(
        selectedImageName: _selectedImageName,
        onBellTap: _openNotificationsSheet,
      ),
      body: Stack(
        children: [
          // Glow/gradient di sfondo
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF141414), Color(0xFF0B0B0B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withOpacity(0.22),
                      Colors.transparent,
                      accent.withOpacity(0.22),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0, .5, 1],
                  ),
                ),
              ),
            ),
          ),

          // Contenuto
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- HEADER / HERO ----------
                    _SectionCard(
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (ctx, cons) {
                          final isNarrow = cons.maxWidth < 640;
                          return Flex(
                            direction:
                                isNarrow ? Axis.vertical : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar + edit overlay
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _showImagePickerPopup,
                                    child: CircleAvatar(
                                      radius: 54,
                                      backgroundImage: AssetImage(imagePath),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(.4),
                                            blurRadius: 6,
                                          )
                                        ],
                                      ),
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.edit, size: 18),
                                        color: Colors.white,
                                        onPressed: _showImagePickerPopup,
                                        tooltip: 'Cambia immagine profilo',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 18, height: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: isNarrow
                                      ? CrossAxisAlignment.center
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nickname ?? 'Nickname',
                                      textAlign: isNarrow
                                          ? TextAlign.center
                                          : TextAlign.left,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: isNarrow
                                          ? WrapAlignment.center
                                          : WrapAlignment.start,
                                      children: [
                                        _Badge.icon(
                                          icon: Icons.mail_outline,
                                          label: _email ?? 'Email',
                                        ),
                                        _Badge.icon(
                                          icon: Icons.calendar_month_outlined,
                                          label: _creationDate ?? '—',
                                        ),
                                        if (_steamId != null &&
                                            _steamId!.isNotEmpty)
                                          _Badge.icon(
                                            icon: Icons.link,
                                            label: 'Steam collegato',
                                            color: Colors.green.shade600,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12, height: 12),

                              // Azioni rapide
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: isNarrow
                                    ? WrapAlignment.center
                                    : WrapAlignment.end,
                                children: [
                                  // Notifiche
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _openNotificationsSheet,
                                        icon: const Icon(
                                            Icons.notifications_none),
                                        label: const Text('Notifiche'),
                                      ),
                                      if (_notifCount > 0)
                                        Positioned(
                                          right: -6,
                                          top: -6,
                                          child: _Badge.counter(_notifCount),
                                        ),
                                    ],
                                  ),
                                  // Steam connect/connected
                                  _GradientButton(
                                    label:
                                        (_steamId == null || _steamId!.isEmpty)
                                            ? 'Collega Steam'
                                            : 'Steam collegato',
                                    icon: Icons.videogame_asset,
                                    onTap: (_steamId == null ||
                                            _steamId!.isEmpty)
                                        ? () async {
                                            final account = userId ?? '';
                                            if (account.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'User ID non disponibile')),
                                              );
                                              return;
                                            }
                                            final String apiBaseUrl = _apiBase;
                                            final url =
                                                '$apiBaseUrl/auth/steam/login?account=$account';
                                            final uri = Uri.parse(url);
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode:
                                                    LaunchMode.platformDefault,
                                                webOnlyWindowName: '_blank',
                                              );
                                            }
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---------- PRIVACY ----------
                    _SectionCard(
                      child: Row(
                        children: [
                          Icon(
                            (_isPrivate ?? false)
                                ? Icons.lock_outline
                                : Icons.public_outlined,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Privacy profilo',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  'Se attivo, solo i tuoi amici possono vedere la tua libreria.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPrivate ?? false,
                            onChanged: _setPrivacy,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---------- SEZIONE AMICI ----------
                    _ListSectionHeader(
                      icon: Icons.group_outlined,
                      title: 'Amici',
                      trailing: (_friendRequestsCount > 0)
                          ? _Badge.counter(_friendRequestsCount)
                          : null,
                    ),

                    // Ricerca utenti
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Cerca utenti',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _friendSearch,
                                  onSubmitted: _searchUsers,
                                  decoration: InputDecoration(
                                    hintText: 'Cerca utente per nome…',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () =>
                                    _searchUsers(_friendSearch.text),
                                child: const Text('Cerca'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_searchResults.isEmpty)
                            const _EmptyState(
                              icon: Icons.person_search,
                              title: 'Nessun risultato',
                              subtitle:
                                  'Prova a cercare amici per nickname o username.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final u =
                                    _searchResults[i] as Map<String, dynamic>;
                                final uid = (u['id'] ?? '').toString();
                                final name = (u['name'] ??
                                        u['nickname'] ??
                                        u['username'] ??
                                        'Utente')
                                    .toString();
                                return ListTile(
                                  leading: _avatarFromAny(u),
                                  title: Text(name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.person_add),
                                    tooltip: 'Invia richiesta',
                                    onPressed: () => _sendFriendRequest(uid),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Richieste in arrivo
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Richieste in arrivo',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (_incoming.isEmpty)
                            const _EmptyState(
                              icon: Icons.inbox_outlined,
                              title: 'Nessuna richiesta',
                              subtitle:
                                  'Quando qualcuno ti invierà una richiesta d’amicizia, apparirà qui.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _incoming.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final r = _incoming[i] as Map<String, dynamic>;
                                final requester = (r['requester'] ?? {})
                                    as Map<String, dynamic>;
                                final requesterId =
                                    (requester['id'] ?? '').toString();
                                final name = (requester['name'] ??
                                        requester['nickname'] ??
                                        requester['username'] ??
                                        'Utente')
                                    .toString();
                                return ListTile(
                                  leading: _avatarFromAny(r),
                                  title: Text(name),
                                  subtitle:
                                      const Text('Ti ha inviato una richiesta'),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check,
                                            color: Colors.green),
                                        tooltip: 'Accetta',
                                        onPressed: () =>
                                            _acceptFriend(requesterId),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.redAccent),
                                        tooltip: 'Rifiuta',
                                        onPressed: () =>
                                            _rejectFriend(requesterId),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // I miei amici
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('I miei amici',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (_friends.isEmpty)
                            const _EmptyState(
                              icon: Icons.sentiment_dissatisfied_outlined,
                              title: 'Ancora nessun amico',
                              subtitle:
                                  'Invia richieste dalla ricerca utenti qui sopra.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _friends.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final f = _friends[i] as Map<String, dynamic>;
                                final fid = _extractFriendId(f);
                                final friendName = _extractFriendName(f);
                                return ListTile(
                                  leading: _avatarFromAny(f),
                                  title: Text(friendName),
                                  onTap: () async {
                                    final isPriv = await _fetchIsPrivate(fid);
                                    if (!mounted) return;
                                    if (isPriv) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Profilo privato'),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FriendLibraryScreen(
                                          friendId: fid,
                                          friendName: friendName,
                                        ),
                                      ),
                                    );
                                  },
                                  trailing: IconButton(
                                    icon: const Icon(Icons.person_remove),
                                    tooltip: 'Rimuovi amico',
                                    onPressed: () => _removeFriend(fid),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Richieste inviate
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Richieste inviate',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (_outgoing.isEmpty)
                            const _EmptyState(
                              icon: Icons.outbox_outlined,
                              title: 'Nessuna richiesta inviata',
                              subtitle:
                                  'Le richieste che invii saranno mostrate qui.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _outgoing.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final r =
                                    _outgoing[i] as Map<String, dynamic>? ?? {};
                                final recipient = (r['recipient'] ?? {})
                                    as Map<String, dynamic>;
                                final name = (recipient['username'] ??
                                        recipient['nickname'] ??
                                        recipient['name'] ??
                                        'Utente')
                                    .toString();
                                return ListTile(
                                  leading: _avatarFrom(recipient),
                                  title: Text(name),
                                  subtitle: const Text('In attesa di conferma'),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Azioni account
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {/* elimina profilo */},
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Elimina profilo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ],
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

// === AGGIUNGI QUESTI HELPER (in fondo al file) ===

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Badge({required this.child, this.color});

  factory _Badge.counter(int count) => _Badge(
        child: Text(
          '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      );

  factory _Badge.icon(
      {required IconData icon, required String label, Color? color}) {
    return _Badge(
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: bg.withOpacity(.4), blurRadius: 10, spreadRadius: 0)
        ],
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _EmptyState({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _ListSectionHeader(
      {required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
