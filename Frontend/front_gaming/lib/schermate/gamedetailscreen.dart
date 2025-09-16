import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/models/game.dart';
import 'package:front_gaming/services/image_services.dart'; // per NetworkSvgWidget
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GameDetailScreen extends StatefulWidget {
  final Game game;
  final bool readOnly;

  // Base URL e prefisso API (se il backend è montato su /api)
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

  // progress locali
  int _minutes = 0; // salviamo minuti; la UI mostra ore
  String _status =
      'playing'; // playing | completed | dropped | backlog | onhold | waiting
  bool _savingProgress = false;

  // ---------- Helper URL ----------
  Uri _apiUri(String path) => Uri.parse(
      '${GameDetailScreen._apiBaseUrl}${GameDetailScreen._apiPrefix}$path');

  // ---------- Helpers ----------
  int get _hoursRounded => (_minutes / 60).floor();
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
    if (userId.isNotEmpty) h['X-USER-ID'] = userId; // <-- chiave per il backend
    return h;
  }

  // ---------- STATUS ----------
  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) return;

      final uri = _apiUri('/users/$userId/game/${widget.game.gameId}/status');
      // _loadStatus
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
      final uri = _apiUri('/users/me/game/${widget.game.gameId}/status');
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

      final uri = _apiUri('/users/$userId/game/${widget.game.gameId}/playtime');
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
    final deltaMinutes = deltaHours * 60; // può essere anche negativo
    final prev = _minutes;

    setState(() {
      _minutes = (_minutes + deltaMinutes).clamp(0, 100000000);
      _savingProgress = true;
    });

    try {
      final uri = _apiUri('/users/me/game/${widget.game.gameId}/playtime');
      // _incHours
      final res = await http.patch(
        _apiUri('/users/me/game/${widget.game.gameId}/playtime'),
        headers: await _authHeaders(),
        body: jsonEncode({'minutes': deltaMinutes, 'mode': 'inc'}),
      );
      if (res.statusCode != 200) {
        setState(() => _minutes = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio playtime: ${res.body}')),
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

  Future<void> _setHours(int newHours) async {
    if (widget.readOnly) return;
    final newMinutes = (newHours * 60).clamp(0, 100000000);
    final prev = _minutes;

    setState(() {
      _minutes = newMinutes;
      _savingProgress = true;
    });
    try {
      // _setHours
      final res = await http.patch(
        _apiUri('/users/me/game/${widget.game.gameId}/playtime'),
        headers: await _authHeaders(),
        body: jsonEncode({'minutes': newMinutes, 'mode': 'set'}),
      );
      if (res.statusCode != 200) {
        setState(() => _minutes = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio playtime: ${res.body}')),
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

  // ---------- Achievements ----------
  void showAchievementDialog(Map<String, dynamic> achievement) {
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
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> toggleAchievement(int index) async {
    if (widget.readOnly) return;

    // Ottimistico: aggiorno subito la UI
    final prev = achievements[index]['achieved'] == true;
    setState(() {
      achievements[index]['achieved'] = !prev;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) throw Exception('Utente non loggato');

      // rotta legacy lato tuo backend (rimane su /user, non /users)
      final uri = _apiUri(
          '/user/$userId/game/${widget.game.gameId}/achievement/$index/toggle_achieved');

      final response = await http.put(
        _apiUri(
            '/user/$userId/game/${widget.game.gameId}/achievement/$index/toggle_achieved'),
        headers:
            await _authHeaders(), // aggiungilo anche qui, alcuni backend lo richiedono
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          achievements[index]['achieved'] = prev;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${response.body}')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        achievements[index]['achieved'] = prev;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di rete')),
      );
    }
  }

  // ---------- Dettagli: helper ----------
  Future<String?> fetchSviluppatoreLogo(String? name) async {
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
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
            ),
          ),
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

  // ---------- UI pezzetti ----------
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
          child: Text(
            p,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
  }

  Widget _hoursControl(BuildContext context) {
    final canEdit = !widget.readOnly;

    Widget miniBtn(IconData icon, VoidCallback? onTap) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.45),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Center(child: Icon(icon, size: 18)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timer ore',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // si può togliere un'ora solo se abbiamo almeno 60 minuti
            miniBtn(Icons.remove,
                canEdit && _minutes >= 60 ? () => _incHours(-1) : null),
            const SizedBox(width: 12),
            Text(
              _hoursLabel,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            miniBtn(Icons.add, canEdit ? () => _incHours(1) : null),
            if (_savingProgress) const SizedBox(width: 12),
            if (_savingProgress)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusSelector(BuildContext context) {
    final canEdit = !widget.readOnly;
    final items = [
      ('playing', 'In corso', Icons.play_arrow),
      ('completed', 'Completato', Icons.check_circle),
      ('dropped', 'Droppato', Icons.cancel),
      ('backlog', 'In attesa', Icons.hourglass_bottom),
      ('onhold', 'In pausa', Icons.pause_circle_outline),
      ('waiting', 'In coda', Icons.schedule),
    ];

    Widget chip(String value, String label, IconData icon) {
      final selected = _status == value;
      final selColor = Theme.of(context).colorScheme.primary.withOpacity(0.18);
      return Material(
        color: selected ? selColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: canEdit ? () => _setStatus(value) : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(label),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stato',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final it in items) chip(it.$1, it.$2, it.$3)],
        ),
      ],
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final imgHeight = (h / 6).clamp(100, 220).toDouble(); // ~1/6, con limiti

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.label, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _removeGameFromLibrary,
              label: const Text("Rimuovi dalla libreria"),
              icon: const Icon(Icons.delete),
              backgroundColor: Colors.redAccent,
            ),
      body: FutureBuilder<String?>(
        future: fetchSviluppatoreLogo(widget.game.sviluppatore),
        builder: (context, snapshot) {
          final sviluppatoreLogo = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: immagine 1/6 + titolo centrato
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: imgHeight,
                      child: widget.game.logoImage != null
                          ? Image.network(
                              widget.game.logoImage!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              width: imgHeight * 16 / 9,
                              child:
                                  const Icon(Icons.videogame_asset, size: 64),
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
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),

                // Piattaforme in evidenza
                _platformChips(context),
                const SizedBox(height: 18),

                // Timer ore
                _hoursControl(context),
                const SizedBox(height: 18),

                // Stato (distanziato)
                _statusSelector(context),
                const SizedBox(height: 22),

                // Dettagli ordinati
                Text(
                  'Dettagli',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...[
                  _buildRow('Genere', widget.game.genere, context),
                  sviluppatoreLogo != null
                      ? _buildLogoRow('Sviluppatore', sviluppatoreLogo)
                      : _buildRow(
                          'Sviluppatore', widget.game.sviluppatore, context),
                  _buildRow('Serie', widget.game.serie, context),
                  _buildRow('Piattaforme', widget.game.piattaforma, context),
                  _buildRow('Modalità di gioco', widget.game.modalitaDiGioco,
                      context),
                  _buildRow('Dispositivo di ingresso',
                      widget.game.dispositivoIngresso, context),
                  _buildRow('Data di pubblicazione',
                      widget.game.dataPubblicazione, context),
                  _buildRow('Editore', widget.game.editore, context),
                  _buildRow('Distributore', widget.game.distributore, context),
                  _buildRow('Sito web ufficiale', widget.game.sitoWebUfficiale,
                      context),
                  _buildRow('Classificazione USK',
                      widget.game.classificazioneUSK, context),
                  _buildRow('Steam ID', widget.game.idSteam, context),
                  _buildRow('GOG ID', widget.game.idGOG, context),
                ].whereType<Widget>(),

                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 10),

                // Obiettivi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Obiettivi',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${achievements.where((a) => a['achieved'] == true).length} / ${achievements.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (achievements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nessun obiettivo disponibile.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: achievements.length,
                      itemBuilder: (context, index) {
                        final a = achievements[index];
                        final name = a['name'] ?? 'Senza nome';
                        final achieved = a['achieved'] == true;
                        final imageUrl = achieved
                            ? (a['icon'] ?? '')
                            : (a['icongray'] ?? '');

                        return Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => showAchievementDialog(a),
                                  onDoubleTap: widget.readOnly
                                      ? null
                                      : () => toggleAchievement(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOut,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: achieved
                                            ? Colors.green
                                            : Colors.grey,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                key: ValueKey<bool>(achieved),
                                                fit: BoxFit.contain,
                                              )
                                            : Icon(
                                                achieved
                                                    ? Icons.check_circle
                                                    : Icons.star_border,
                                                key: ValueKey<bool>(achieved),
                                                size: 60,
                                                color: achieved
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              if (!widget.readOnly)
                                Text(
                                  'Doppio tap per ${achieved ? 'annullare' : 'completare'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.grey),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- Rimozione gioco ----------
  Future<void> _removeGameFromLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utente non loggato")),
      );
      return;
    }

    // rotta legacy esistente (rimane su /user, non /users)
    final url = _apiUri('/user/$userId/remove_game/${widget.game.gameId}');

    try {
      final response = await http.delete(
        _apiUri('/user/$userId/remove_game/${widget.game.gameId}'),
        headers: await _authHeaders(),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gioco rimosso dalla libreria")),
        );
        Navigator.of(context).pop();
      } else {
        final msg = jsonDecode(response.body)['detail'] ?? 'Errore sconosciuto';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $msg")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore di rete")),
      );
    }
  }
}
