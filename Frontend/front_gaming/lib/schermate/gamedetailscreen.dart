import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/models/game.dart';
import 'package:front_gaming/services/image_services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GameDetailScreen extends StatefulWidget {
  final Game game;
  final bool readOnly;

  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _apiPrefix = '/api';

  const GameDetailScreen({
    required this.game,
    super.key,
    this.readOnly = false,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late List<Map<String, dynamic>> achievements;

  int _minutes = 0;
  String _status =
      'playing'; // playing | completed | dropped | backlog | onhold | waiting
  bool _savingProgress = false;

  Uri _apiUri(String path) => Uri.parse(
      '${GameDetailScreen._apiBaseUrl}${GameDetailScreen._apiPrefix}$path');
  Uri _uri(String path) => Uri.parse('${GameDetailScreen._apiBaseUrl}$path');

  String get _hoursLabel {
    final h = _minutes / 60.0;
    return '${h.toStringAsFixed(h.truncateToDouble() == h ? 0 : 1)} h';
  }

  @override
  void initState() {
    super.initState();
    achievements = List<Map<String, dynamic>>.from(widget.game.achievements);
    _loadHours();
    _loadStatus();
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final h = <String, String>{'Content-Type': 'application/json'};
    if (userId.isNotEmpty) h['X-USER-ID'] = userId;
    return h;
  }

  // ---------- STATUS ----------
  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) return;

      final res = await http.get(
        _apiUri('/users/$userId/game/${widget.game.gameId}/status'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body);
        setState(() {
          _status = (b['status'] ?? 'playing').toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _setStatus(String value) async {
    if (widget.readOnly) return;
    final old = _status;
    setState(() => _status = value);

    try {
      final res = await http.patch(
        _apiUri('/users/me/game/${widget.game.gameId}/status'),
        headers: await _authHeaders(),
        body: jsonEncode({'status': value}),
      );
      if (res.statusCode != 200) {
        setState(() => _status = old);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio stato: ${res.body}')),
        );
      }
    } catch (_) {
      setState(() => _status = old);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di rete nel salvataggio stato')),
      );
    }
  }

  // ---------- PLAYTIME ----------
  Future<void> _loadHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) return;

      final res = await http.get(
        _apiUri('/users/$userId/game/${widget.game.gameId}/playtime'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body);
        setState(() {
          _minutes = (b['minutes'] ?? 0) is int
              ? b['minutes']
              : int.tryParse('${b['minutes']}') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _incHours(int deltaHours) async {
    if (widget.readOnly) return;
    final deltaMinutes = deltaHours * 60;
    final prev = _minutes;

    setState(() {
      _minutes = (_minutes + deltaMinutes).clamp(0, 100000000);
      _savingProgress = true;
    });

    try {
      final res = await http.patch(
        _apiUri('/users/me/game/${widget.game.gameId}/playtime'),
        headers: await _authHeaders(),
        body: jsonEncode({'minutes': deltaMinutes, 'mode': 'inc'}),
      );
      if (res.statusCode != 200) {
        setState(() => _minutes = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore salvataggio ore di gioco: ${res.body}')),
        );
      }
    } catch (_) {
      setState(() => _minutes = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di rete nel salvataggio ore')),
      );
    } finally {
      if (mounted) setState(() => _savingProgress = false);
    }
  }

  // ---------- ACHIEVEMENTS ----------
  void _showAchievementDialog(Map<String, dynamic> achievement) {
    final achieved = achievement['achieved'] == true;
    final imageUrl = achieved
        ? (achievement['icon'] ?? '')
        : (achievement['icongray'] ?? '');
    final description =
        achievement['description'] ?? 'Nessuna descrizione disponibile';
    final name = achievement['name'] ?? 'Obiettivo';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty) Image.network(imageUrl, height: 100),
            const SizedBox(height: 12),
            Text(description),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi')),
        ],
      ),
    );
  }

  Future<void> _toggleAchievement(int index) async {
    if (widget.readOnly) return;

    final prev = achievements[index]['achieved'] == true;
    setState(() {
      achievements[index]['achieved'] = !prev;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) throw Exception('Utente non loggato');

      final uri = _uri(
          '/user/$userId/game/${widget.game.gameId}/achievement/$index/toggle_achieved');
      final response = await http.put(uri);
      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() => achievements[index]['achieved'] = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${response.body}')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => achievements[index]['achieved'] = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di rete')),
      );
    }
  }

  // ---------- HELPERS DETTAGLI ----------
  Future<String?> _fetchSviluppatoreLogo(String? name) async {
    if (name == null || name.isEmpty) return null;
    try {
      final response = await http
          .get(_apiUri('/company_logo?name=${Uri.encodeComponent(name)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['logo'];
      }
    } catch (_) {}
    return null;
  }

  Widget? _buildRow(String label, dynamic value, BuildContext context) {
    if (value == null || value.toString().toLowerCase() == 'n/a') return null;

    String text;
    if (value is List<String>) {
      text = value.join(', ');
    } else if (value is DateTime) {
      text = "${value.day}/${value.month}/${value.year}";
    } else {
      text = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, textAlign: TextAlign.left)),
        ],
      ),
    );
  }

  Widget _buildLogoRow(String label, String logoUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 50,
            height: 50,
            child: logoUrl.toLowerCase().endsWith('.svg')
                ? NetworkSvgWidget(url: logoUrl)
                : Image.network(logoUrl, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  Widget _platformChips(BuildContext context) {
    final plats = widget.game.piattaforma ?? const [];
    if (plats.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 8,
      runSpacing: 8,
      children: plats.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.28),
            ),
          ),
          child: Text(p, style: const TextStyle(fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }

  // ---------- STATUS UI HELPERS ----------
  Color _statusSelectedColor(String value) {
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

  Widget _roundIconButton(BuildContext context,
      {required IconData icon, VoidCallback? onTap}) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        child: Icon(icon, size: 28),
      ),
    );
  }

  Widget _bigStatusChip(
      BuildContext context, String value, String label, IconData icon) {
    final selected = _status == value;
    final scheme = Theme.of(context).colorScheme;
    final Color bg = selected
        ? _statusSelectedColor(value)
        : scheme.surfaceVariant.withOpacity(0.6);
    final Color fg = selected
        ? (ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black)
        : Theme.of(context).textTheme.bodyLarge!.color!;

    return InkWell(
      onTap: widget.readOnly ? null : () => _setStatus(value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- RIMOZIONE GIOCO ----------
  Future<void> _removeGameFromLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utente non loggato")),
      );
      return;
    }

    final url = _uri('/users/me/remove_game/${widget.game.gameId}');
    try {
      final resp = await http.delete(url, headers: {'X-USER-ID': userId});
      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gioco rimosso dalla libreria")),
        );
        Navigator.of(context).pop(true); // notifica MyLibrary di ricaricare
      } else {
        String msg = 'Errore sconosciuto';
        try {
          msg = (jsonDecode(resp.body)['detail'] ?? msg).toString();
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Errore: $msg")));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore di rete")),
      );
    }
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    // immagine più grande (~ 1/3 dello schermo)
    final imgHeight = (h / 3).clamp(160.0, 480.0);

    return Scaffold(
      // niente AppBar
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Dettagli'),
                    Tab(text: 'Progressi'),
                    Tab(text: 'Obiettivi'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // -------------------- DETTAGLI --------------------
                    FutureBuilder<String?>(
                      future: _fetchSviluppatoreLogo(widget.game.sviluppatore),
                      builder: (context, snap) {
                        final sviluppatoreLogo = snap.data;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    height: imgHeight,
                                    child: widget.game.logoImage != null
                                        ? Image.network(widget.game.logoImage!,
                                            fit: BoxFit.cover)
                                        : Container(
                                            color: Colors.grey.shade300,
                                            width: imgHeight * 16 / 9,
                                            child: const Icon(
                                                Icons.videogame_asset,
                                                size: 64),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.game.label,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),

                              const SizedBox(height: 18),
                              _platformChips(context),

                              const SizedBox(height: 18),
                              Text(
                                'Dettagli',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),

                              // niente riga "Piattaforme" nei dettagli
                              ...[
                                _buildRow(
                                    'Genere', widget.game.genere, context),
                                sviluppatoreLogo != null
                                    ? _buildLogoRow(
                                        'Sviluppatore', sviluppatoreLogo)
                                    : _buildRow('Sviluppatore',
                                        widget.game.sviluppatore, context),
                                _buildRow('Serie', widget.game.serie, context),
                                _buildRow('Modalità di gioco',
                                    widget.game.modalitaDiGioco, context),
                                _buildRow('Dispositivo di ingresso',
                                    widget.game.dispositivoIngresso, context),
                                _buildRow('Data di pubblicazione',
                                    widget.game.dataPubblicazione, context),
                                _buildRow(
                                    'Editore', widget.game.editore, context),
                                _buildRow('Distributore',
                                    widget.game.distributore, context),
                                _buildRow('Sito web ufficiale',
                                    widget.game.sitoWebUfficiale, context),
                                _buildRow('Classificazione USK',
                                    widget.game.classificazioneUSK, context),
                                _buildRow(
                                    'Steam ID', widget.game.idSteam, context),
                                _buildRow('GOG ID', widget.game.idGOG, context),
                              ].whereType<Widget>(),
                            ],
                          ),
                        );
                      },
                    ),

                    // -------------------- PROGRESSI --------------------
                    // usiamo CustomScrollView + SliverFillRemaining per fissare il pulsante in basso
                    LayoutBuilder(
                      builder: (context, cons) {
                        return CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  const SizedBox(height: 12),
                                  Text(
                                    'Ore di gioco',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _roundIconButton(
                                        context,
                                        icon: Icons.remove,
                                        onTap:
                                            (!widget.readOnly && _minutes >= 60)
                                                ? () => _incHours(-1)
                                                : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        _hoursLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: 16),
                                      _roundIconButton(
                                        context,
                                        icon: Icons.add,
                                        onTap: !widget.readOnly
                                            ? () => _incHours(1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  // sempre un po’ di aria tra i controlli e lo spinner
                                  const SizedBox(height: 12),
// riserva sempre spazio fisso: niente reflow della sezione "Stato"
                                  SizedBox(
                                    height:
                                        26, // fissa l’altezza (22 + margine)
                                    child: Center(
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        child: _savingProgress
                                            ? const SizedBox(
                                                key: ValueKey('spinner'),
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : const SizedBox(
                                                key: ValueKey('empty')),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 48),
                                  Text(
                                    'Stato',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _bigStatusChip(context, 'playing',
                                          'In corso', Icons.play_arrow),
                                      _bigStatusChip(context, 'completed',
                                          'Completato', Icons.check_circle),
                                      _bigStatusChip(context, 'dropped',
                                          'Droppato', Icons.cancel),
                                      _bigStatusChip(context, 'backlog',
                                          'In attesa', Icons.hourglass_bottom),
                                      _bigStatusChip(
                                          context,
                                          'onhold',
                                          'In pausa',
                                          Icons.pause_circle_outline),
                                      _bigStatusChip(context, 'waiting',
                                          'In coda', Icons.schedule),
                                    ],
                                  ),
                                ]),
                              ),
                            ),
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 24, 16, 24),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: !widget.readOnly
                                      ? SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _removeGameFromLibrary,
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            label: const Text('Rimuovi gioco'),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: const StadiumBorder(),
                                              backgroundColor: Colors.redAccent,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // -------------------- OBIETTIVI --------------------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Obiettivi  •  ${achievements.where((a) => a['achieved'] == true).length} / ${achievements.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: achievements.isEmpty
                                ? Center(
                                    child: Text(
                                      'Nessun obiettivo disponibile.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6, // 6 per riga
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio:
                                          1.0, // quadrati perfetti
                                    ),
                                    itemCount: achievements.length,
                                    itemBuilder: (context, index) {
                                      final a = achievements[index];
                                      final achieved = a['achieved'] == true;
                                      final imageUrl = achieved
                                          ? (a['icon'] ?? '')
                                          : (a['icongray'] ?? '');
                                      final name = a['name'] ?? 'Senza nome';

                                      return GestureDetector(
                                        onTap: () => _showAchievementDialog(a),
                                        onDoubleTap: widget.readOnly
                                            ? null
                                            : () => _toggleAchievement(index),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: achieved
                                                  ? Colors.green
                                                  : Colors.grey,
                                              width: 3,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                // immagine centrata, fit: contain
                                                if (imageUrl.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            10),
                                                    child: Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  )
                                                else
                                                  Center(
                                                    child: Icon(
                                                      achieved
                                                          ? Icons.check_circle
                                                          : Icons.star_border,
                                                      size: 48,
                                                      color: achieved
                                                          ? Colors.green
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                // overlay nome in basso, senza alterare il quadrato
                                                Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 4),
                                                    color: Colors.black45,
                                                    child: Text(
                                                      name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12),
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
