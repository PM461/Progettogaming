import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:front_gaming/services/profile_service.dart';
import 'package:front_gaming/controllers/profile_controller.dart';
import 'package:front_gaming/schermate/FriendLibraryScreen.dart';

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

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final imagePath = _selectedImageName != null
        ? 'images/propic/${_selectedImageName!}.png'
        : 'images/propic/1.png';

    return Scaffold(
      appBar: CustomAppBar(selectedImageName: _selectedImageName),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _showImagePickerPopup,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: AssetImage(imagePath),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _nickname ?? 'Nickname',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildInfoRow('Email', _email ?? 'Caricamento...'),
              _buildInfoRow(
                  'Data creazione', _creationDate ?? 'Caricamento...'),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Profilo privato'),
                value: _isPrivate ?? false,
                onChanged: (v) => _setPrivacy(v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: (_steamId == null || _steamId!.isEmpty)
                        ? () async {
                            final account = userId ?? '';
                            if (account.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('User ID non disponibile')),
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
                                mode: LaunchMode.platformDefault,
                                webOnlyWindowName: '_blank',
                              );
                            }
                          }
                        : null,
                    child: Image.asset(
                      _steamId != null && _steamId!.isNotEmpty
                          ? 'images/steam.png'
                          : 'images/steam_gray.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Informazioni su Steam'),
                      content: const Text(
                        '⚠️ Attenzione: gli obiettivi nella libreria verranno sovrascritti.\n\n'
                        'Se non dovesse funzionare, ricordati di rendere il tuo profilo Steam pubblico.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Chiudi'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Informazioni Steam'),
              ),
              const SizedBox(height: 24),

              // ----------- SEZIONE AMICI + RICERCA -----------
              _friendsSection(),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {/* elimina profilo */},
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Elimina profilo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
