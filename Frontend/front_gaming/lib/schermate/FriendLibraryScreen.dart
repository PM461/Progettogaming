import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/models/game.dart';
import 'package:front_gaming/schermate/gamedetailscreen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FriendLibraryScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const FriendLibraryScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<FriendLibraryScreen> createState() => _FriendLibraryScreenState();
}

class _FriendLibraryScreenState extends State<FriendLibraryScreen> {
  // ✅ inizializzata in initState
  late Future<Map<String, List<Game>>> _futureListsWithGames;

  String? _token;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _initAuth().then((_) {
      // inizializza la future DOPO aver caricato token/headers
      setState(() {
        _futureListsWithGames = _fetchListsAndGames();
      });
    });
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ??
        prefs.getString('access_token') ??
        prefs.getString('jwt') ??
        prefs.getString('id_token') ??
        prefs.getString('user_id'); // fallback DEV
    _myUserId = prefs.getString('user_id');
    if (_token != null && _token!.toLowerCase().startsWith('bearer ')) {
      _token = _token!.substring(7);
    }
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    if (_myUserId != null && _myUserId!.isNotEmpty) {
      h['X-USER-ID'] = _myUserId!;
    }
    return h;
  }

  Future<Map<String, List<Game>>> _fetchListsAndGames() async {
    const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

    // 1) Giochi dell'amico
    final gamesUrl = Uri.parse('$apiBaseUrl/user/${widget.friendId}/games');
    final gamesRes = await http.get(gamesUrl, headers: _headers);

    // Blocca se profilo privato o non accessibile
    if (gamesRes.statusCode == 401 || gamesRes.statusCode == 403) {
      throw _PrivateProfileError();
    }
    if (gamesRes.statusCode < 200 || gamesRes.statusCode >= 300) {
      throw Exception('Errore ${gamesRes.statusCode} nel recupero giochi');
    }

    final gamesData = jsonDecode(gamesRes.body);
    final allGames = (gamesData['games'] as List)
        .map<Game>((json) => Game.fromJson(json as Map<String, dynamic>))
        .toList();

    // 2) Liste dell'amico
    final listsUrl = Uri.parse('$apiBaseUrl/user/${widget.friendId}/lists');
    final listsRes = await http.get(listsUrl, headers: _headers);

    if (listsRes.statusCode == 401 || listsRes.statusCode == 403) {
      throw _PrivateProfileError();
    }
    if (listsRes.statusCode < 200 || listsRes.statusCode >= 300) {
      throw Exception('Errore ${listsRes.statusCode} nel recupero liste');
    }

    final listsData = jsonDecode(listsRes.body);
    final lists = (listsData['lists'] as List? ?? const []);

    // mappa per id -> game
    final gamesById = {for (final g in allGames) g.gameId: g};

    // Costruisci mappa: nome lista -> lista giochi
    final Map<String, List<Game>> listsWithGames = {
      'Tutti i giochi': allGames,
    };

    for (final raw in lists) {
      if (raw is! Map<String, dynamic>) continue;
      final listName = (raw['name'] ?? 'Senza nome').toString();
      final gameIds = (raw['game_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      listsWithGames[listName] =
          gameIds.map((id) => gamesById[id]).whereType<Game>().toList();
    }

    return listsWithGames;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.friendName} • Libreria')),
      body: (_futureListsWithGames == null)
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, List<Game>>>(
              future: _futureListsWithGames,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Mostra messaggio chiaro per profilo privato
                  if (snapshot.error is _PrivateProfileError) {
                    return _PrivateProfileView();
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Errore: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data == null || data.isEmpty) {
                  return const Center(child: Text('Nessun gioco disponibile'));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: data.entries.map((entry) {
                    final listName = entry.key;
                    final games = entry.value;
                    if (games.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            int crossAxisCount;
                            if (width < 400) {
                              crossAxisCount = 2;
                            } else if (width < 800) {
                              crossAxisCount = 4;
                            } else {
                              crossAxisCount = 6;
                            }

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1 / 1.3,
                              children: games.map((game) {
                                final achieved = game.achievements
                                    .where((a) =>
                                        (a is Map<String, dynamic>) &&
                                        (a['achieved'] == true))
                                    .length;
                                final total = game.achievements.length;

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GameDetailScreen(
                                          game: game,
                                          readOnly: true, // ✅ sola lettura
                                        ),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(12)),
                                            child: (game.logoImage != null &&
                                                    game.logoImage!
                                                        .trim()
                                                        .isNotEmpty)
                                                ? Image.network(
                                                    game.logoImage!,
                                                    fit: BoxFit.contain,
                                                  )
                                                : Container(
                                                    color: Colors.grey.shade300,
                                                    child: const Icon(
                                                      Icons.videogame_asset,
                                                      size: 60,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  game.label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Obiettivi: $achieved / $total',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}

class _PrivateProfileError implements Exception {}

class _PrivateProfileView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline, size: 48),
            SizedBox(height: 12),
            Text(
              'Profilo privato',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Questo utente ha reso privata la sua libreria.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
