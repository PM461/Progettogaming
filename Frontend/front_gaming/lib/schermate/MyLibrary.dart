import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:front_gaming/models/game.dart';
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

class _MyLibraryScreenState extends State<MyLibraryScreen> {
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

    // Giochi
    final gamesUrl = Uri.parse('$apiBaseUrl/user/$userId/games?cb=$cacheBust');
    final gamesResponse = await http.get(gamesUrl, headers: headers);
    if (gamesResponse.statusCode != 200) {
      throw Exception("Errore nel recupero dei giochi");
    }
    final gamesData = jsonDecode(gamesResponse.body);
    final List<Game> allGames =
        (gamesData['games'] as List).map((json) => Game.fromJson(json)).toList();

    // Liste
    final listsUrl = Uri.parse('$apiBaseUrl/user/$userId/lists?cb=$cacheBust');
    final listsResponse = await http.get(listsUrl, headers: headers);
    if (listsResponse.statusCode != 200) {
      throw Exception("Errore nel recupero delle liste");
    }
    final listsData = jsonDecode(listsResponse.body);
    final List<dynamic> lists = listsData['lists'];

    final Map<String, Game> gamesById = {for (var g in allGames) g.gameId: g};

    Map<String, List<Game>> listsWithGames = {};
    for (var list in lists) {
      final String listName = (list['name'] ?? 'Senza nome').toString();
      final List<dynamic> gameIds = (list['game_ids'] ?? []) as List<dynamic>;
      listsWithGames[listName] = gameIds
          .map((id) => gamesById[id.toString()])
          .whereType<Game>()
          .toList();
    }

    _allGamesCache = allGames;
    _wishlistCache = listsWithGames['Wishlist'] ?? const [];

    return {
      "Tutti i giochi": allGames,
      ...listsWithGames,
    };
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
                  _NavItem(label: 'Giochi', icon: Icons.videogame_asset_outlined),
                  _NavItem(label: 'Console', icon: Icons.vrpano_outlined),
                  _NavItem(label: 'Statistiche', icon: Icons.bar_chart),
                ],
                selectedIndex: _section.index,
                onTap: (i) => setState(() => _section = LibrarySection.values[i]),
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

  // ----------------- GIOCHI (con "Liste") -----------------
  Widget _buildGamesSection(
    BuildContext context,
    Map<String, List<Game>> listsWithGames,
  ) {
    final isDesktopLike = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

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

    // calcolo il set attuale da mostrare
    List<Game> current;
    if (_gamesSub == SubSection.owned) {
      current = owned;
    } else if (_gamesSub == SubSection.wishlist) {
      current = wishlist;
    } else {
      // Sottosezione "Liste"
      final selectedName = (listNames.contains(_selectedUserListName))
          ? _selectedUserListName!
          : (listNames.isNotEmpty ? listNames.first : '');
      current = selectedName.isNotEmpty
          ? (customListsMap[selectedName] ?? const <Game>[])
          : const <Game>[];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UnderlineNav(
            items: const [
              _NavItem(label: 'Posseduti'),
              _NavItem(label: 'Wishlist'),
              _NavItem(label: 'Liste'),
            ],
            selectedIndex: _gamesSub.index,
            onTap: (i) => setState(() => _gamesSub = SubSection.values[i]),
            alignLeft: true,
            compact: true,
            showUnderline: false,
            highlightSelected: true,
          ),

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

          Expanded(
            child: current.isEmpty
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
                        cross = 6;
                      } else {
                        cross = 8;
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: current.length,
                        itemBuilder: (_, i) {
                          final game = current[i];
                          return _GameHoverCard(
                            game: game,
                            onTap: () async {
                              // 👉 al ritorno ricarico SEMPRE
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameDetailScreen(game: game),
                                ),
                              );
                              if (!mounted) return;
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
            onTap: (i) => setState(
                () => _consoleSub = i == 0 ? SubSection.owned : SubSection.wishlist),
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(icon: Icons.apps, label: 'Totale giochi', value: '$total'),
              _StatTile(icon: Icons.bookmark_border, label: 'Wishlist', value: '$wl'),
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

  const _GameHoverCard({
    required this.game,
    this.onTap,
    this.enableHoverEffects = true,
  });

  @override
  State<_GameHoverCard> createState() => _GameHoverCardState();
}

class _GameHoverCardState extends State<_GameHoverCard> {
  bool _hovered = false;

  int get _achTotal => widget.game.achievements.length;
  int get _achDone =>
      widget.game.achievements.where((a) => (a['achieved'] == true)).length;

  String get _hoursPlayedText => '—'; // placeholder

  @override
  Widget build(BuildContext context) {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 2/3 immagine
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
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Obiettivi: $_achDone / $_achTotal'),
                                  if (widget.game.piattaforma != null &&
                                      widget.game.piattaforma!.isNotEmpty)
                                    Text(
                                      'Piattaforme: ${widget.game.piattaforma!.join(', ')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text('Ore di gioco: $_hoursPlayedText'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 1/3 info
              Expanded(
                flex: 1,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text('$_achDone/$_achTotal'),
                          const SizedBox(width: 12),
                          if (widget.game.genere != null)
                            Flexible(
                              child: Text(
                                widget.game.genere!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
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
