import 'dart:convert';
import 'package:front_gaming/main.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/services/auth_service.dart';
import 'package:front_gaming/services/drag.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ClassicalLogin.dart';
import 'MyLibrary.dart';
import 'search_page.dart';

const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

class MainScreenState extends State<MainScreen> {
  late Future<String> futureName;

  List<Map<String, dynamic>> raccomandati = [];
  List<Map<String, dynamic>> nuoviSimili = [];
  bool _loadingRecs = false;

  int _currentIndex = 0;

  String? _selectedImageName;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    futureName = loadName();
    _loadProfileImage();
    _loadRecommendations();
    _checkFirstAccessAndShowPopup();
  }

  Future<void> _loadRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    setState(() => _loadingRecs = true);
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/users/get-raccomandazioni?user_id=$userId'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rec = (data['raccomandazione'] ?? {})['recommendations'] ?? {};
        setState(() {
          raccomandati =
              List<Map<String, dynamic>>.from(rec['raccomandati'] ?? []);
          nuoviSimili =
              List<Map<String, dynamic>>.from(rec['nuovi_simili'] ?? []);
        });
      }
    } catch (_) {
      // ignora: mostro solo empty state
    } finally {
      if (mounted) setState(() => _loadingRecs = false);
    }
  }

  Future<void> _checkFirstAccessAndShowPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final isFirst = data['isfirst'] == 0;
        final userId = data['_id']?.toString();
        if (isFirst && userId != null) {
          _showClassicGamePopup(userId);
        }
      }
    } catch (_) {}
  }

  void _showClassicGamePopup(String userId) {
    final capturedContext = context;
    http.get(Uri.parse('$apiBaseUrl/api/users/get-game-guide')).then((res) {
      if (res.statusCode != 200) return;
      final guide = jsonDecode(res.body);
      final map = (guide['classic_games'] as Map<String, dynamic>);
      final classic = map.values
          .expand((x) => x as List)
          .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
          .toList();

      List<String> selectedIds = [];

      showDialog(
        context: capturedContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: Scaffold(
                    appBar: AppBar(
                      automaticallyImplyLeading: false,
                      title: const Text('Benvenuto! Aggiungi giochi classici'),
                      centerTitle: true,
                    ),
                    body: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                              'Scegli i giochi da aggiungere alla tua libreria iniziale:'),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              int cross = c.maxWidth < 700
                                  ? 3
                                  : (c.maxWidth < 1100 ? 4 : 6);
                              return GridView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: classic.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.8,
                                ),
                                itemBuilder: (context, index) {
                                  final game = classic[index];
                                  final gameId = game['wikidata_id'];
                                  final isSel = selectedIds.contains(gameId);

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isSel
                                            ? selectedIds.remove(gameId)
                                            : selectedIds.add(gameId);
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? Colors.blueAccent
                                                .withOpacity(0.20)
                                            : Colors.white12,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSel
                                              ? Colors.blue
                                              : Colors.white24,
                                          width: 2,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: (game['image_url'] != null &&
                                                    game['image_url']
                                                        .toString()
                                                        .isNotEmpty)
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    child: Image.network(
                                                      game['image_url'],
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __,
                                                              ___) =>
                                                          const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 48,
                                                              color: Colors
                                                                  .white30),
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.videogame_asset,
                                                    size: 48,
                                                    color: Colors.white30),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            (game['title'] ?? gameId)
                                                .toString(),
                                            style:
                                                const TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: selectedIds.length >= 4
                                ? () async {
                                    try {
                                      for (final id in selectedIds) {
                                        final addRes = await http.post(
                                          Uri.parse(
                                              '$apiBaseUrl/user/$userId/add_game/$id'),
                                        );
                                        if (addRes.statusCode != 200) {
                                          throw Exception(
                                              'Errore aggiunta gioco $id');
                                        }
                                      }
                                      final isFirstRes = await http.post(
                                        Uri.parse(
                                            '$apiBaseUrl/user/$userId/set-isfirst'),
                                        headers: {
                                          'Content-Type': 'application/json'
                                        },
                                        body: jsonEncode({'isfirst': 1}),
                                      );
                                      if (isFirstRes.statusCode == 200) {
                                        Navigator.of(dialogContext).pop();
                                        Navigator.of(capturedContext)
                                            .pushReplacementNamed('/main');
                                      } else {
                                        throw Exception(
                                            'Errore aggiornamento isfirst');
                                      }
                                    } catch (_) {}
                                  }
                                : null,
                            child: const Text('Aggiungi alla libreria'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    });
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? imageName = prefs.getString('profile_image');
    final userId = prefs.getString('user_id');

    if (imageName != null && imageName.isNotEmpty) {
      setState(() => _selectedImageName = imageName);
      return;
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse('$apiBaseUrl/api/users/get-propic?user_id=$userId'));
        if (response.statusCode == 200) {
          final index = int.tryParse(response.body);
          if (index != null && index >= 0) {
            imageName = '$index';
            await prefs.setString('profile_image', imageName);
            setState(() => _selectedImageName = imageName);
            return;
          }
        }
      } catch (_) {}
    }
    setState(() => _selectedImageName = '1');
  }

  Future<String> loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    final token = prefs.getString('jwt_token');

    try {
      final name = await getUserName(token: token, uid: uid);
      return name.isNotEmpty ? name : 'Nickname non trovato';
    } catch (e) {
      return 'Errore nel caricamento: ${e.toString()}';
    }
  }

  // ---------- UI HOME (brand + hero + sezioni) ----------
  Widget _buildHomeContent() {
    const primary = Color(0xFF0E91DD);
    const accent = Color(0xFFEE3FD0);

    return Stack(
      children: [
        // BG gradient + glow diagonale
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
                    primary.withOpacity(0.25),
                    Colors.transparent,
                    accent.withOpacity(0.25)
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),

        // Contenuto
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header “Bentornato”
              FutureBuilder<String>(
                future: futureName,
                builder: (context, snap) {
                  final name = (snap.data ?? '').trim();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? 'Bentornato, $name ' : 'Bentornato',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .3,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ecco i giochi consigliati e le novità per te.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Sezione Raccomandati
              _SectionHeader(
                icon: Icons.auto_awesome,
                title: 'Raccomandati per te',
                trailing: _loadingRecs ? const _PulseDot() : null,
              ),
              const SizedBox(height: 12),
              if (_loadingRecs && raccomandati.isEmpty)
                const _HorizontalSkeletonList()
              else if (raccomandati.isEmpty)
                const _EmptyRow(label: 'Nessun suggerimento al momento')
              else
                DraggableGameList(title: "", games: raccomandati),

              const SizedBox(height: 28),

              // Sezione Nuovi simili
              _SectionHeader(
                icon: Icons.new_releases_outlined,
                title: 'Nuovi simili ai tuoi gusti',
                trailing: _loadingRecs ? const _PulseDot() : null,
              ),
              const SizedBox(height: 12),
              if (_loadingRecs && nuoviSimili.isEmpty)
                const _HorizontalSkeletonList()
              else if (nuoviSimili.isEmpty)
                const _EmptyRow(label: 'Nessuna novità trovata')
              else
                DraggableGameList(title: "", games: nuoviSimili),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  void _openSearch() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SearchPage()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHomeContent(),
      const MyLibraryScreen(),
    ];

    return Scaffold(
      appBar: CustomAppBar(selectedImageName: _selectedImageName),
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
              label: const Text('Cerca'),
            )
          : null,
    );
  }
}

// ----------------- WIDGET DI SUPPORTO GRAFICO -----------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader(
      {required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final pri = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: pri.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pri.withOpacity(.25)),
          ),
          child: Icon(icon, size: 20, color: pri),
        ),
        const SizedBox(width: 10),
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
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String label;
  const _EmptyRow({required this.label});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white60)),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({Key? key}) : super(key: key);
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: c.drive(CurveTween(curve: Curves.easeInOut)),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _HorizontalSkeletonList extends StatelessWidget {
  const _HorizontalSkeletonList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withOpacity(0.06);
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (_, __) => _ShimmerCard(bg: bg),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 8,
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  final Color bg;
  const _ShimmerCard({required this.bg, Key? key}) : super(key: key);
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment(-1 + c.value * 2, -1),
                    end: Alignment(1 + c.value * 2, 1),
                    colors: [widget.bg, widget.bg.withOpacity(0.2), widget.bg],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 110,
            color: widget.bg,
          ),
        ],
      ),
    );
  }
}
