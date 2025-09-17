import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:front_gaming/models/game.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/schermate/gamedetailscreen.dart';
import 'package:front_gaming/services/profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

enum LibrarySection { games, consoles, stats }

enum SubSection { owned, wishlist, lists }

enum SortMode { added, addedReverse, alpha }

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  SortMode _sortMode = SortMode.added;
  String _genreFilter = 'Tutti';

  late Future<Map<String, List<Game>>> futureListsWithGames;
  String? _profileImageName;

  LibrarySection _section = LibrarySection.games;
  SubSection _gamesSub = SubSection.owned;
  SubSection _consoleSub = SubSection.owned;

  // cache
  List<Game> _allGamesCache = const [];
  List<Game> _wishlistCache = const [];

  // selezione lista utente nella sottosezione "Liste"
  String? _selectedUserListName;

  @override
  void initState() {
    super.initState();
    futureListsWithGames = fetchListsAndGames();
    _loadProfileImage();
  }

// --- API base come in GameDetailScreen ---
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _apiPrefix = '/api';
  Uri _apiUri(String path) => Uri.parse('$_apiBaseUrl$_apiPrefix$path');

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final h = <String, String>{'Content-Type': 'application/json'};
    if (userId.isNotEmpty) h['X-USER-ID'] = userId;
    return h;
  }

// --- cache meta per card e stats ---
  final Map<String, String> _statusByGameId = {}; // gameId -> status
  final Map<String, int> _minutesByGameId = {}; // gameId -> minutes

  String _formatHours(int? minutes) {
    final m = minutes ?? 0;
    final h = m / 60.0;
    return h.toStringAsFixed(h.truncateToDouble() == h ? 0 : 1) + ' h';
  }

// carica status+playtime per un singolo gioco, con cache
  Future<void> _ensureMetaLoaded(String gameId) async {
    final needStatus = !_statusByGameId.containsKey(gameId);
    final needMinutes = !_minutesByGameId.containsKey(gameId);
    if (!needStatus && !needMinutes) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) return;
      final headers = await _authHeaders();

      final futures = <Future<http.Response>>[];
      if (needStatus) {
        futures.add(http.get(_apiUri('/users/$userId/game/$gameId/status'),
            headers: headers));
      }
      if (needMinutes) {
        futures.add(http.get(_apiUri('/users/$userId/game/$gameId/playtime'),
            headers: headers));
      }

      final resps = await Future.wait(futures);

      // mappa in ordine: se hai chiesto entrambi, la prima è status, la seconda playtime
      int idx = 0;
      if (needStatus) {
        final r = resps[idx++];
        if (r.statusCode == 200) {
          final s = (jsonDecode(r.body)['status'] ?? 'playing').toString();
          _statusByGameId[gameId] = s;
        }
      }
      if (needMinutes) {
        final r = resps[idx++];
        if (r.statusCode == 200) {
          final raw = jsonDecode(r.body)['minutes'];
          final m = (raw is int) ? raw : int.tryParse('$raw') ?? 0;
          _minutesByGameId[gameId] = m;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // silenzio: lasciamo '—' se fallisce
    }
  }

  Widget _buildFiltersBar(List<String> genres) {
    // genero la lista opzioni (incluso "Tutti")
    final List<String> genreOptions = ['Tutti', ...genres];
    // se il valore non è più valido (cambia la lista), riposiziona su "Tutti"
    if (!genreOptions.contains(_genreFilter)) _genreFilter = 'Tutti';

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // GENERE
        _DropdownShell(
          label: 'Genere',
          child: DropdownButton<String>(
            value: _genreFilter,
            isDense: true,
            onChanged: (v) => setState(() => _genreFilter = v ?? 'Tutti'),
            items: genreOptions
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
          ),
        ),
        // ORDINA
        _DropdownShell(
          label: 'Ordina',
          child: DropdownButton<SortMode>(
            value: _sortMode,
            isDense: true,
            onChanged: (v) => setState(() => _sortMode = v ?? SortMode.added),
            items: const [
              DropdownMenuItem(
                value: SortMode.added,
                child: Text('Aggiunta'),
              ),
              DropdownMenuItem(
                value: SortMode.addedReverse,
                child: Text('Aggiunta (inverso)'),
              ),
              DropdownMenuItem(
                value: SortMode.alpha,
                child: Text('Alfabetico (A→Z)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _cycleSort() {
    setState(() {
      _sortMode = _sortMode == SortMode.added
          ? SortMode.alpha
          : _sortMode == SortMode.alpha
              ? SortMode.addedReverse
              : SortMode.added;
    });
  }

  Widget _sortButton() {
    final label = _sortLabel(_sortMode);
    return TextButton.icon(
      onPressed: _cycleSort,
      icon: Icon(_sortIcon(_sortMode), size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _genreMenuButton(List<String> genres) {
    final options = <String>{
      'Tutti',
      ...genres.where((g) => g.trim().isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return PopupMenuButton<String>(
      tooltip: 'Filtro genere',
      initialValue: _genreFilter,
      onSelected: (val) => setState(() => _genreFilter = val),
      itemBuilder: (context) => [
        for (final g in options)
          PopupMenuItem<String>(
            value: g,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_genreFilter == g) const Icon(Icons.check, size: 18),
                if (_genreFilter == g) const SizedBox(width: 6),
                Flexible(child: Text(g)),
              ],
            ),
          ),
      ],
      // Child personalizzato con lo stesso "look" del TextButton.icon
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const ShapeDecoration(
          shape: StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 18),
            const SizedBox(width: 6),
            Text(_genreFilter == 'Tutti' ? 'Genere' : _genreFilter),
          ],
        ),
      ),
    );
  }

  String _sortLabel(SortMode m) {
    switch (m) {
      case SortMode.added:
        return 'Aggiunta';
      case SortMode.alpha:
        return 'A→Z';
      case SortMode.addedReverse:
        return 'Aggiunta (inv)';
    }
  }

  IconData _sortIcon(SortMode m) {
    switch (m) {
      case SortMode.added:
        return Icons.schedule;
      case SortMode.alpha:
        return Icons.sort_by_alpha;
      case SortMode.addedReverse:
        return Icons.swap_vert;
    }
  }

  Future<void> _pickGenre(List<String> genres) async {
    final options = [
      'Tutti',
      ...genres.toSet().where((g) => g.trim().isNotEmpty).toList()..sort()
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView.separated(
          itemCount: options.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final g = options[i];
            final active = g == _genreFilter;
            return ListTile(
              title: Text(g),
              trailing: active ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, g),
            );
          },
        ),
      ),
    );
    if (selected != null) {
      setState(() => _genreFilter = selected);
    }
  }

  Widget _miniFilterButton(List<String> genres) {
    final label = _sortLabel(_sortMode) +
        (_genreFilter != 'Tutti' ? ' • $_genreFilter' : '');
    return TextButton.icon(
      onPressed: _cycleSort,
      onLongPress: () => _pickGenre(genres),
      icon: Icon(_sortIcon(_sortMode), size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(),
      ),
    );
  }

  Future<void> _loadProfileImage() async {
    final imageName = await ProfileService.getProfileImageName();
    if (!mounted) return;
    setState(() => _profileImageName = imageName);
  }

  // 👉 aggiunto {int? cb} per cache-busting
  Future<Map<String, List<Game>>> fetchListsAndGames({int? cb}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      throw Exception("ID utente non trovato");
    }
    const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

    final cacheBust = cb ?? DateTime.now().millisecondsSinceEpoch;
    final headers = {
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };

    // 1) Giochi in libreria (owned)
    final libUrl = Uri.parse('$apiBaseUrl/user/$userId/games?cb=$cacheBust');
    final libRes = await http.get(libUrl, headers: headers);
    if (libRes.statusCode != 200) {
      throw Exception("Errore nel recupero dei giochi");
    }
    final libJson = jsonDecode(libRes.body);
    final List<Game> libraryGames =
        (libJson['games'] as List).map((j) => Game.fromJson(j)).toList();

    // Mappa per accesso rapido per id
    final Map<String, Game> byId = {for (final g in libraryGames) g.gameId: g};

    // 2) Wishlist (solo ID)
    final wlUrl = Uri.parse('$apiBaseUrl/user/$userId/wishlist?cb=$cacheBust');
    final wlRes = await http.get(wlUrl, headers: headers);
    if (wlRes.statusCode != 200) {
      throw Exception("Errore nel recupero della wishlist");
    }
    final wlJson = jsonDecode(wlRes.body);
    final List<String> wishlistIds =
        (wlJson['game_ids'] as List? ?? []).map((e) => e.toString()).toList();

    // 3) Recupera dettagli per gli ID wishlist non presenti in libreria
    final List<String> missingIds =
        wishlistIds.where((id) => !byId.containsKey(id)).toList();

    if (missingIds.isNotEmpty) {
      // NB: gli ID sono tipo "Q170410" quindi sicuri; se preferisci, usa Uri.encodeComponent per ciascuno.
      final idsParam = missingIds.join(',');
      final byIdsUrl =
          Uri.parse('$apiBaseUrl/games/by_ids?ids=$idsParam&cb=$cacheBust');
      final byIdsRes = await http.get(byIdsUrl, headers: headers);
      if (byIdsRes.statusCode == 200) {
        final byIdsJson = jsonDecode(byIdsRes.body);
        final fetched =
            (byIdsJson['games'] as List).map((j) => Game.fromJson(j)).toList();
        for (final g in fetched) {
          byId[g.gameId] = g;
        }
      } else {
        // Se fallisce, continuiamo comunque (la wishlist avrà solo i giochi presenti in libreria)
      }
    }

    // 4) Liste personalizzate (diverse dalla Wishlist)
    final listsUrl = Uri.parse('$apiBaseUrl/user/$userId/lists?cb=$cacheBust');
    final listsRes = await http.get(listsUrl, headers: headers);
    if (listsRes.statusCode != 200) {
      throw Exception("Errore nel recupero delle liste");
    }
    final listsData = jsonDecode(listsRes.body);
    final List<dynamic> lists = (listsData['lists'] as List?) ?? const [];

    // Costruisco la mappa nome-lista -> giochi (usando byId per risolvere)
    final Map<String, List<Game>> listsWithGames = {};
    for (final lst in lists) {
      final String listName = (lst['name'] ?? 'Senza nome').toString();
      final List<dynamic> ids = (lst['game_ids'] ?? []) as List<dynamic>;
      final games =
          ids.map((id) => byId[id.toString()]).whereType<Game>().toList();
      listsWithGames[listName] = games;
    }

    // 5) Costruisco la lista "Wishlist" completa (anche giochi non in libreria)
    final List<Game> wishlistGames =
        wishlistIds.map((id) => byId[id]).whereType<Game>().toList();

    // Cache locali usate in Stats e altrove
    _allGamesCache = libraryGames;
    _wishlistCache = wishlistGames;

    // 6) Ritorno struttura finale (Tutti i giochi + Wishlist + Liste personalizzate)
    return {
      "Tutti i giochi": libraryGames,
      "Wishlist": wishlistGames,
      ...listsWithGames,
    };
  }

  Future<void> _reloadGameMetaFor(String gameId) async {
    // invalida la cache per questo gioco
    _statusByGameId.remove(gameId);
    _minutesByGameId.remove(gameId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) return;

      final cb = DateTime.now().millisecondsSinceEpoch;
      final headers = await _authHeaders()
        ..addAll({'Cache-Control': 'no-cache', 'Pragma': 'no-cache'});

      // STATUS (fresh)
      final stRes = await http.get(
        _apiUri('/users/$userId/game/$gameId/status?cb=$cb'),
        headers: headers,
      );
      if (stRes.statusCode == 200) {
        final b = jsonDecode(stRes.body);
        _statusByGameId[gameId] = (b['status'] ?? '').toString();
      }

      // PLAYTIME (fresh)
      final ptRes = await http.get(
        _apiUri('/users/$userId/game/$gameId/playtime?cb=$cb'),
        headers: headers,
      );
      if (ptRes.statusCode == 200) {
        final b = jsonDecode(ptRes.body);
        final raw = b['minutes'];
        _minutesByGameId[gameId] =
            (raw is int) ? raw : int.tryParse('$raw') ?? 0;
      }

      if (mounted) setState(() {});
    } catch (_) {/* ignora */}
  }

  // 👉 comodo helper per ricaricare davvero la lista
  void _refreshLibrary() {
    setState(() {
      futureListsWithGames =
          fetchListsAndGames(cb: DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(selectedImageName: _profileImageName),
      body: FutureBuilder<Map<String, List<Game>>>(
        future: futureListsWithGames,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final hasErr = snapshot.hasError;
          final data = snapshot.data;

          Widget content;
          if (loading) {
            content = Center(
              child: Image.asset('images/logow.gif', width: 60, height: 60),
            );
          } else if (hasErr) {
            content = Center(child: Text('Errore: ${snapshot.error}'));
          } else if (data == null || data.isEmpty) {
            content = const Center(child: Text('Nessun dato disponibile'));
          } else {
            content = _buildBody(context, data);
          }

          return Column(
            children: [
              const SizedBox(height: 8),
              _UnderlineNav(
                items: const [
                  _NavItem(
                      label: 'Giochi', icon: Icons.videogame_asset_outlined),
                  _NavItem(label: 'Console', icon: Icons.vrpano_outlined),
                  _NavItem(label: 'Statistiche', icon: Icons.bar_chart),
                ],
                selectedIndex: _section.index,
                onTap: (i) =>
                    setState(() => _section = LibrarySection.values[i]),
                alignLeft: true,
                showUnderline: true,
                highlightSelected: false,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  layoutBuilder: (currentChild, _) =>
                      currentChild ?? const SizedBox(),
                  // 👉 aggiunto RefreshIndicator per pull-to-refresh
                  child: RefreshIndicator(
                    onRefresh: () async => _refreshLibrary(),
                    child: content,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, Map<String, List<Game>> listsWithGames) {
    switch (_section) {
      case LibrarySection.games:
        return _buildGamesSection(context, listsWithGames);
      case LibrarySection.consoles:
        return _buildConsolesSection(context);
      case LibrarySection.stats:
        return _buildStatsSection(context, _allGamesCache, _wishlistCache);
    }
  }

  Map<String, dynamic> _toGamedataMap(Game g) {
    String? pubDate;
    final dp = g.dataPubblicazione;
    if (dp is DateTime) {
      pubDate = dp.toIso8601String();
    } else if (dp != null) {
      pubDate = dp.toString();
    }

    return {
      '_id': g.gameId,
      'label': g.label,
      'details': {
        'logo image': g.logoImage,
        'image': {'logo': g.logoImage},
        'sviluppatore': g.sviluppatore,
        'developer': g.sviluppatore,
        'editore': g.editore,
        'publisher': g.editore,
        'genere': g.genere,
        'serie': g.serie,
        'piattaforma':
            g.piattaforma, // List<String>? ok, Gamedatascreen fa join
        'platform': g.piattaforma,
        'modalità di gioco': g.modalitaDiGioco,
        'game mode': g.modalitaDiGioco,
        'distributore': g.distributore,
        'publication date': pubDate,
      },
    };
  }

  // ----------------- GIOCHI (con "Liste") -----------------
// ----------------- GIOCHI (con "Liste") -----------------
  Widget _buildGamesSection(
    BuildContext context,
    Map<String, List<Game>> listsWithGames,
  ) {
    final isDesktopLike = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    // dataset base
    final allGames = listsWithGames['Tutti i giochi'] ?? const <Game>[];
    final wishlist = listsWithGames['Wishlist'] ?? const <Game>[];

    // Owned = tutti i giochi che NON sono in wishlist
    final wlIds = wishlist.map((g) => g.gameId).toSet();
    final owned = allGames.where((g) => !wlIds.contains(g.gameId)).toList();

    // Liste personalizzate (tutte meno "Tutti i giochi" e "Wishlist")
    final customListsMap = Map<String, List<Game>>.fromEntries(
      listsWithGames.entries.where((e) {
        final k = e.key.trim().toLowerCase();
        return k != 'tutti i giochi' && k != 'wishlist';
      }),
    );
    final listNames = customListsMap.keys.toList();

    // calcolo il set attuale (prima dei filtri)
    List<Game> current;
    if (_gamesSub == SubSection.owned) {
      current = owned;
    } else if (_gamesSub == SubSection.wishlist) {
      current = wishlist;
    } else {
      final selectedName = (listNames.contains(_selectedUserListName))
          ? _selectedUserListName!
          : (listNames.isNotEmpty ? listNames.first : '');
      current = selectedName.isNotEmpty
          ? (customListsMap[selectedName] ?? const <Game>[])
          : const <Game>[];
    }

    // mostro filtri solo per Posseduti/Wishlist
    final showFilters =
        _gamesSub == SubSection.owned || _gamesSub == SubSection.wishlist;

    // generi disponibili (dal dataset corrente)
    List<String> availableGenres = [];
    if (showFilters) {
      final s = <String>{};
      for (final g in current) {
        final gen = g.genere?.trim();
        if (gen != null && gen.isNotEmpty) s.add(gen);
      }
      availableGenres = s.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    // applico filtro GENERE + ordinamento
    List<Game> toShow = List<Game>.from(current);
    if (showFilters) {
      if (_genreFilter != 'Tutti') {
        toShow = toShow.where((g) => (g.genere ?? '') == _genreFilter).toList();
      }
      switch (_sortMode) {
        case SortMode.added: // ordine naturale (aggiunta)
          break;
        case SortMode.addedReverse:
          toShow = toShow.reversed.toList();
          break;
        case SortMode.alpha:
          toShow.sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NAV a sinistra + FILTRI a destra
          Row(
            children: [
              Expanded(
                child: _UnderlineNav(
                  items: const [
                    _NavItem(label: 'Posseduti'),
                    _NavItem(label: 'Wishlist'),
                    _NavItem(label: 'Liste'),
                  ],
                  selectedIndex: _gamesSub.index,
                  onTap: (i) => setState(() {
                    _gamesSub = SubSection.values[i];
                    // opzionale: resetta il genere quando cambi tab non-liste
                    if (_gamesSub != SubSection.lists) _genreFilter = 'Tutti';
                  }),
                  alignLeft: true,
                  compact: true,
                  showUnderline: false,
                  highlightSelected: true,
                ),
              ),
              if (showFilters)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sortButton(),
                    const SizedBox(width: 6),
                    _genreMenuButton(availableGenres),
                  ],
                ),
            ],
          ),

          // Sezione sotto-nav per "Liste"
          if (_gamesSub == SubSection.lists) ...[
            const SizedBox(height: 6),
            if (listNames.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                child: Text(
                  'Non hai ancora creato liste personalizzate.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              _UnderlineNav(
                items: [for (final name in listNames) _NavItem(label: name)],
                selectedIndex: listNames.indexOf(
                  listNames.contains(_selectedUserListName)
                      ? _selectedUserListName!
                      : (listNames.isNotEmpty ? listNames.first : ''),
                ),
                onTap: (i) => setState(() {
                  _selectedUserListName = listNames[i];
                }),
                alignLeft: true,
                compact: true,
                showUnderline: false,
                highlightSelected: true,
              ),
          ],

          const SizedBox(height: 8),

          // griglia con la lista filtrata/ordinata
          Expanded(
            child: toShow.isEmpty
                ? Center(
                    child: Text(
                      _gamesSub == SubSection.owned
                          ? 'Nessun gioco posseduto'
                          : _gamesSub == SubSection.wishlist
                              ? 'Nessun gioco in wishlist'
                              : (listNames.isEmpty
                                  ? 'Crea la tua prima lista dal backend/altre sezioni'
                                  : 'Questa lista è vuota'),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      int cross;
                      if (w < 420) {
                        cross = 2;
                      } else if (w < 900) {
                        cross = 4;
                      } else if (w < 1400) {
                        cross = 5;
                      } else {
                        cross = 8;
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          // PRIMA: 3/4 (=0.75). ADESSO: 0.70 per farle un po' più alte.
                          childAspectRatio: 0.60,
                        ),
                        itemCount: toShow.length,
                        itemBuilder: (_, i) {
                          final game = toShow[i];
                          return _GameHoverCard(
                            game: game,
                            isWishlist: _gamesSub == SubSection.wishlist, // 👈
                            status: _statusByGameId[game.gameId], // 👈
                            minutes: _minutesByGameId[game.gameId], // 👈
                            onNeedMeta: () => _ensureMetaLoaded(game.gameId),
                            onTap: () async {
                              if (_gamesSub == SubSection.wishlist) {
                                final dataMap = _toGamedataMap(game);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          Gamedatascreen(game: dataMap)),
                                );
                                if (!mounted) return;
                                _refreshLibrary(); // forza refetch API al rientro
                              } else {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          GameDetailScreen(game: game)),
                                );
                              }
                              if (!mounted) return;
                              await _reloadGameMetaFor(game.gameId);
                              _refreshLibrary();
                            },
                            enableHoverEffects: isDesktopLike,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ----------------- CONSOLE (placeholder pronto) -----------------
  Widget _buildConsolesSection(BuildContext context) {
    final List<String> ownedConsoles = const [];
    final List<String> wishlistConsoles = const [];

    final current =
        _consoleSub == SubSection.owned ? ownedConsoles : wishlistConsoles;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UnderlineNav(
            items: const [
              _NavItem(label: 'Possedute'),
              _NavItem(label: 'Wishlist'),
            ],
            selectedIndex: _consoleSub == SubSection.owned ? 0 : 1,
            onTap: (i) => setState(() =>
                _consoleSub = i == 0 ? SubSection.owned : SubSection.wishlist),
            alignLeft: true,
            compact: true,
            showUnderline: false,
            highlightSelected: true,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: current.isEmpty
                ? const Center(child: Text('Nessuna console in questa sezione'))
                : ListView.separated(
                    itemCount: current.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.sports_esports_outlined),
                      title: Text(current[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ----------------- STATISTICHE -----------------
  Widget _buildStatsSection(
      BuildContext context, List<Game> all, List<Game> wishlist) {
    final total = all.length;
    final wl = wishlist.length;

    int totalAch = 0;
    int totalDone = 0;
    for (final g in all) {
      final ach = g.achievements;
      totalAch += ach.length;
      totalDone += ach.where((a) => (a['achieved'] == true)).length;
    }
    final completion = totalAch == 0 ? 0.0 : (totalDone / totalAch);

    for (final g in all) {
      _ensureMetaLoaded(g.gameId);
    }

// somma i minuti già disponibili in cache
    int totalMinutes = 0;
    for (final g in all) {
      totalMinutes += _minutesByGameId[g.gameId] ?? 0;
    }
    final totalHoursStr = _formatHours(totalMinutes);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(
                  icon: Icons.apps, label: 'Totale giochi', value: '$total'),
              _StatTile(
                  icon: Icons.bookmark_border, label: 'Wishlist', value: '$wl'),
              _StatTile(
                icon: Icons.emoji_events_outlined,
                label: 'Obiettivi completati',
                value: '$totalDone / $totalAch',
              ),
              _StatTile(
                icon: Icons.percent,
                label: 'Completion rate',
                value: '${(completion * 100).toStringAsFixed(1)}%',
              ),
              _StatTile(
                icon: Icons.schedule,
                label: 'Ore totali giocate',
                value: totalHoursStr,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Prossimamente: grafici per genere, piattaforma, ore di gioco…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        ],
      ),
    );
  }
}

/// ---------- NAV MINIMAL (sinistra) ----------
class _NavItem {
  final String label;
  final IconData? icon;
  const _NavItem({required this.label, this.icon});
}

class _UnderlineNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool compact;
  final bool alignLeft;
  final bool showUnderline;
  final bool highlightSelected;

  const _UnderlineNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.compact = false,
    this.alignLeft = false,
    this.showUnderline = true,
    this.highlightSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final sel = Theme.of(context).colorScheme.primary;
    final base = Theme.of(context).textTheme.titleMedium!;
    final textStyle = compact
        ? base.copyWith(fontSize: 14, fontWeight: FontWeight.w600)
        : base.copyWith(fontSize: 16, fontWeight: FontWeight.w700);

    final lightBg = Theme.of(context).colorScheme.primary.withOpacity(0.12);

    final children = <Widget>[
      for (int i = 0; i < items.length; i++)
        InkWell(
          onTap: () => onTap(i),
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(10),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 4 : 6,
              horizontal: compact ? 4 : 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 6 : 8,
                    horizontal: compact ? 10 : 12,
                  ),
                  decoration: highlightSelected && selectedIndex == i
                      ? BoxDecoration(
                          color: lightBg,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (items[i].icon != null) ...[
                        Icon(
                          items[i].icon,
                          size: compact ? 18 : 20,
                          color: selectedIndex == i ? sel : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        items[i].label,
                        style: textStyle.copyWith(
                          color: selectedIndex == i ? sel : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (showUnderline) ...[
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    height: 2.5,
                    width: selectedIndex == i ? 36 : 0,
                    decoration: BoxDecoration(
                      color: sel,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
    ];

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 44 : 52),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment:
              alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: _withSpacing(children, spacing: 12),
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets, {double spacing = 8}) {
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      out.add(widgets[i]);
      if (i != widgets.length - 1) out.add(SizedBox(width: spacing));
    }
    return out;
  }
}

/// ---------- STAT TILE ----------
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- GAME CARD con hover (desktop) ----------
class _GameHoverCard extends StatefulWidget {
  final Game game;
  final VoidCallback? onTap;
  final bool enableHoverEffects;
  final bool isWishlist;
  final String? status; // e.g., playing/completed/...
  final int? minutes; // playtime in minuti
  final VoidCallback? onNeedMeta; // per triggerare il fetch lazy
  const _GameHoverCard({
    required this.game,
    this.onTap,
    this.enableHoverEffects = true,
    this.isWishlist = false,
    this.status,
    this.minutes,
    this.onNeedMeta,
  });

  @override
  State<_GameHoverCard> createState() => _GameHoverCardState();
}

class _GameHoverCardState extends State<_GameHoverCard> {
  bool _hovered = false;
  bool _requestedMeta = false; // evita richieste ripetute

  // --- helpers/calcoli ---
  int get _achTotal => widget.game.achievements.length;
  int get _achDone =>
      widget.game.achievements.where((a) => (a['achieved'] == true)).length;
  bool get _showAchievements =>
      !widget.isWishlist && _achTotal > 0; // niente 0/0 & niente in wishlist

  String get _platformsText {
    final p = widget.game.piattaforma;
    return (p != null && p.isNotEmpty) ? p.join(', ') : '—';
  }

  // rating interno: prova più campi comuni
  String get _ratingText {
    try {
      final d = widget.game as dynamic;
      final r =
          d.rating ?? d.internalRating ?? d.valutazione ?? d.valutazioneInterna;
      if (r is num) return r.toStringAsFixed(1);
      if (r is String && r.trim().isNotEmpty) return r;
    } catch (_) {}
    return '—';
  }

  String get _statusText => widget.status ?? '—';

  String get _hoursHoverText {
    final m = widget.minutes;
    if (m == null) return '—';
    final h = m / 60.0;
    return h.toStringAsFixed(h.truncateToDouble() == h ? 0 : 1) + ' h';
  }

  Color _statusColor(String? value) {
    switch (value) {
      case 'playing':
        return const Color(0xFF1E88E5); // blu
      case 'completed':
        return const Color(0xFF2E7D32); // verde
      case 'dropped':
        return const Color(0xFFD32F2F); // rosso
      case 'backlog':
        return const Color(0xFF6A1B9A); // viola
      case 'onhold':
        return const Color(0xFFF9A825); // giallo
      case 'waiting':
        return const Color(0xFF00BFA5); // verde acqua
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabelIt(String? value) {
    switch (value) {
      case 'playing':
        return 'In corso';
      case 'completed':
        return 'Completato';
      case 'dropped':
        return 'Droppato';
      case 'backlog':
        return 'In attesa';
      case 'onhold':
        return 'In pausa';
      case 'waiting':
        return 'In coda';
      default:
        return '—';
    }
  }

  IconData _statusIcon(String? value) {
    switch (value) {
      case 'playing':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check_circle;
      case 'dropped':
        return Icons.cancel;
      case 'backlog':
        return Icons.hourglass_bottom;
      case 'onhold':
        return Icons.pause_circle_outline;
      case 'waiting':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  /// Badge pill rotondo (solo per posseduti quando lo status è disponibile)
  Widget _statusBadge() {
    if (widget.isWishlist || widget.status == null) {
      return const SizedBox.shrink();
    }
    final bg = _statusColor(widget.status);
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(widget.status), size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            _statusLabelIt(widget.status),
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paddingSmall() => const SizedBox(height: 4);

  @override
  Widget build(BuildContext context) {
    // Lazy load meta (status + playtime) se serve
    if (!_requestedMeta &&
        !widget.isWishlist &&
        (widget.status == null || widget.minutes == null)) {
      _requestedMeta = true;
      widget.onNeedMeta?.call();
    }

    final card = AnimatedScale(
      duration: const Duration(milliseconds: 140),
      scale: (_hovered && widget.enableHoverEffects) ? 1.04 : 1.0,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Card(
          elevation: _hovered ? 6 : 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ----- immagine + overlay hover -----
              Expanded(
                flex: 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.game.logoImage != null)
                      Image.network(widget.game.logoImage!, fit: BoxFit.cover)
                    else
                      Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.videogame_asset, size: 60),
                      ),
                    if (widget.enableHoverEffects)
                      AnimatedOpacity(
                        opacity: _hovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 140),
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(10),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: DefaultTextStyle(
                              style: const TextStyle(color: Colors.white),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.game.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (!widget.isWishlist) ...[
                                    Text('Ore di gioco: $_hoursHoverText'),
                                    Text('Valutazione: $_ratingText'),
                                    Text(
                                      'Piattaforme: $_platformsText',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else ...[
                                    // wishlist: solo piattaforme
                                    Text(
                                      'Piattaforme: $_platformsText',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ----- quick info -----
              Expanded(
                flex: 1,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.game.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      if (!widget.isWishlist) ...[
                        if (_showAchievements)
                          Row(
                            children: [
                              const Icon(Icons.emoji_events_outlined, size: 16),
                              const SizedBox(width: 4),
                              Text('$_achDone/$_achTotal'),
                            ],
                          ),
                        if (_showAchievements) const SizedBox(height: 4),
                        _paddingSmall(),
                        _statusBadge(),
                      ] else ...[
                        // WISHLIST: nessun obiettivo né ore; mostra Genere (se presente) + Piattaforme
                        if ((widget.game.genere ?? '').isNotEmpty) ...[
                          Text(
                            widget.game.genere!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          'Piattaforme: $_platformsText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.enableHoverEffects) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: card,
    );
  }
}

class _DropdownShell extends StatelessWidget {
  final String label;
  final Widget child;
  const _DropdownShell({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return ConstrainedBox(
      // PRIMA: const BoxConstraints(minWidth: 160)
      // DOPO: dai anche un maxWidth per evitare overflow/∞
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          border: border,
          enabledBorder: border,
        ),
        child: DropdownButtonHideUnderline(child: child),
      ),
    );
  }
}
