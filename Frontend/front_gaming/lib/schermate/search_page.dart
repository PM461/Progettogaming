import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/services/image_services.dart';
import 'package:front_gaming/services/profile_service.dart';

class SearchPage extends StatefulWidget {
  final String? query;
  const SearchPage({super.key, this.query});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // --- brand colors (coerenti con il resto) ---
  static const primary = Color(0xFF0E91DD);
  static const accent = Color(0xFFEE3FD0);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _annoController = TextEditingController();
  final TextEditingController _sviluppatoreController = TextEditingController();

  static const String _genereTutti = 'Tutti';

  List<dynamic> _searchResults = [];
  List<dynamic> _filteredResults = [];
  bool _isSearching = false;
  String _searchError = '';
  String? _profileImageName;

  Set<String> availableGeneri = {_genereTutti};
  Set<String> availableAnni = {};
  Set<String> availableSviluppatori = {};
  String? _selectedGenere = _genereTutti;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadGeneri();

    if (widget.query != null && widget.query!.trim().isNotEmpty) {
      _searchController.text = widget.query!;
      searchGame(widget.query!);
    }
  }

  Future<void> _loadGeneri() async {
    try {
      const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
      final response = await http.get(Uri.parse('$apiBaseUrl/genres'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> genresList = data['genres'] ?? [];
        setState(() {
          availableGeneri = {_genereTutti};
          for (var g in genresList) {
            final lbl = (g['label'] ?? '').toString().trim();
            if (lbl.isNotEmpty) availableGeneri.add(lbl);
          }
          _selectedGenere = _genereTutti;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProfileImage() async {
    final imageName = await ProfileService.getProfileImageName();
    if (!mounted) return;
    setState(() => _profileImageName = imageName);
  }

  String cleanGenere(dynamic g) {
    if (g == null) return '';
    if (g is String) {
      return g.trim().toLowerCase().replaceAll(RegExp(r'[^a-zàèéìòù\s]'), '');
    }
    if (g is List) {
      return g
          .map((e) => e
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-zàèéìòù\s]'), ''))
          .join(',');
    }
    return '';
  }

  Future<void> searchGame(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _filteredResults = [];
        _searchError = '';
        availableGeneri = {_genereTutti};
        availableAnni.clear();
        availableSviluppatori.clear();
        _selectedGenere = _genereTutti;
        _annoController.clear();
        _sviluppatoreController.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/find_game?query=$query'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List<dynamic>? ?? []);
        final generiSet = <String>{};

        // Estrai metadati rapidi per i filtri
        for (final game in results) {
          final rawGenere =
              game['details']?['genere'] ?? game['details']?['genre'];
          if (rawGenere is String) {
            final gClean = cleanGenere(rawGenere);
            if (gClean.isNotEmpty) generiSet.addAll(gClean.split(','));
          } else if (rawGenere is List) {
            for (final g in rawGenere) {
              final gClean = cleanGenere(g);
              if (gClean.isNotEmpty) generiSet.add(gClean);
            }
          }
        }

        setState(() {
          _searchResults = results;
          availableGeneri = {_genereTutti, ...generiSet};
          // reset filtri non coerenti
          if (!availableGeneri.contains(_selectedGenere)) {
            _selectedGenere = _genereTutti;
          }
          _applyFilters();
        });
      } else {
        setState(() {
          _searchResults = [];
          _filteredResults = [];
          _searchError = 'Nessun gioco trovato';
          availableGeneri = {_genereTutti};
        });
      }
    } catch (e) {
      setState(() {
        _searchError = 'Errore durante la ricerca';
        _searchResults = [];
        _filteredResults = [];
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_searchResults);

    // Genere
    final sel = (_selectedGenere ?? _genereTutti).toLowerCase();
    if (sel.isNotEmpty && sel != _genereTutti.toLowerCase()) {
      filtered = filtered.where((game) {
        final rawGenere =
            game['details']?['genere'] ?? game['details']?['genre'] ?? '';
        if (rawGenere is String) {
          final gs = cleanGenere(rawGenere).split(',');
          return gs.contains(sel);
        } else if (rawGenere is List) {
          return rawGenere.any((e) => cleanGenere(e) == sel);
        }
        return false;
      }).toList();
    }

    // Anno
    final annoFiltro = _annoController.text.trim();
    if (annoFiltro.isNotEmpty) {
      filtered = filtered.where((game) {
        final dp = game['details']?['data di pubblicazione'] ??
            game['details']?['publication date'] ??
            '';
        final s = dp.toString();
        String year = '';
        if (s.startsWith('['))
          year = s.substring(1, 5);
        else
          year = s.substring(0, 4);

        return year == annoFiltro;
      }).toList();
    }

    // Sviluppatore
    final devFiltro = _sviluppatoreController.text.trim().toLowerCase();
    if (devFiltro.isNotEmpty) {
      filtered = filtered.where((game) {
        final raw = game['sviluppatore'] ??
            game['details']?['sviluppatore'] ??
            game['details']?['developer'];
        if (raw == null) return false;
        if (raw is String) return raw.toLowerCase().contains(devFiltro);
        if (raw is List)
          return raw.any((d) => d.toString().toLowerCase().contains(devFiltro));
        return false;
      }).toList();
    }

    setState(() => _filteredResults = filtered);
  }

  void _onFilterChanged() => _applyFilters();

  String _titleOf(dynamic item) => (item['label'] ?? '').toString();

  String _yearOf(dynamic item) {
    final dp = item['details']?['data di pubblicazione'] ??
        item['details']?['publication date'] ??
        '';
    String s = dp.toString();
    if (s.startsWith('[')) return (s.length >= 4) ? s.substring(1, 5) : '';
    return (s.length >= 4) ? s.substring(0, 4) : '';
  }

  String? _logoOf(dynamic item) {
    return item['details']?['logo image'] as String? ??
        item['details']?['logo'] as String? ??
        item['details']?['image']?['logo'] as String?;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _annoController.dispose();
    _sviluppatoreController.dispose();
    super.dispose();
  }

  // ----------------------------- UI -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(selectedImageName: _profileImageName),
      body: Stack(
        children: [
          // BG gradient + glow
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
                      primary.withOpacity(.22),
                      Colors.transparent,
                      accent.withOpacity(.22)
                    ],
                    stops: const [0, .5, 1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          Column(
            children: [
              // --- Barra di ricerca ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: _SearchBar(
                  controller: _searchController,
                  hint: 'Cerca un gioco…',
                  onChanged: (v) => searchGame(v),
                  onClear: () {
                    _searchController.clear();
                    searchGame('');
                  },
                ),
              ),

              // --- Filtri (responsive con Wrap) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // GENERE
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 180, maxWidth: 260),
                      child: DropdownButtonFormField<String>(
                        value: _selectedGenere,
                        decoration: _inputDeco('Genere'),
                        items: availableGeneri.map((g) {
                          final display = g.isNotEmpty
                              ? g[0].toUpperCase() + g.substring(1)
                              : g;
                          return DropdownMenuItem(
                              value: g, child: Text(display));
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedGenere = v ?? _genereTutti);
                          _applyFilters();
                        },
                        isDense: true,
                      ),
                    ),

                    // ANNO
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _annoController,
                        decoration:
                            _inputDeco('Anno').copyWith(counterText: ''),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        onChanged: (_) => _onFilterChanged(),
                      ),
                    ),

                    // SVILUPPATORE
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 180, maxWidth: 340),
                      child: TextField(
                        controller: _sviluppatoreController,
                        decoration: _inputDeco('Sviluppatore'),
                        onChanged: (_) => _onFilterChanged(),
                      ),
                    ),

                    // RESET
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedGenere = _genereTutti;
                          _annoController.clear();
                          _sviluppatoreController.clear();
                        });
                        _applyFilters();
                      },
                      icon: const Icon(Icons.filter_alt_off, size: 18),
                      label: const Text('Reset filtri'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(),
                ),

              if (_searchError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_searchError,
                      style: const TextStyle(color: Colors.red)),
                ),

              // --- Risultati ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      int cross;
                      if (w < 420)
                        cross = 2;
                      else if (w < 800)
                        cross = 4;
                      else if (w < 1200)
                        cross = 6;
                      else
                        cross = 8;

                      if (_filteredResults.isEmpty &&
                          !_isSearching &&
                          _searchController.text.trim().isEmpty) {
                        return const _EmptySearchState();
                      }

                      if (_filteredResults.isEmpty && !_isSearching) {
                        return const _EmptyList(
                            label: 'Nessun risultato con questi filtri');
                      }

                      return GridView.builder(
                        itemCount: _filteredResults.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (_, i) {
                          final item = _filteredResults[i];
                          final logo = _logoOf(item);
                          final title = _titleOf(item);
                          final year = _yearOf(item);

                          return _GameResultCard(
                            title: title,
                            year: year,
                            logoUrl: logo,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Gamedatascreen(game: item),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ----------------------- WIDGETS DECORATIVI -----------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const _SearchBar({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final pri = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pri.withOpacity(.25)),
        color: const Color(0xFF1C1C1C),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 6),
          const Icon(Icons.search),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Pulisci',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _GameResultCard extends StatefulWidget {
  final String title;
  final String year;
  final String? logoUrl;
  final VoidCallback? onTap;

  const _GameResultCard({
    required this.title,
    required this.year,
    required this.logoUrl,
    this.onTap,
  });

  @override
  State<_GameResultCard> createState() => _GameResultCardState();
}

class _GameResultCardState extends State<_GameResultCard>
    with SingleTickerProviderStateMixin {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _hover ? 1.03 : 1.0,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Card(
          elevation: _hover ? 10 : 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // immagine
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.logoUrl != null)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: widget.logoUrl!.toLowerCase().endsWith('.svg')
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: NetworkSvgWidget(url: widget.logoUrl!),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  widget.logoUrl!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      )
                    else
                      Container(
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.videogame_asset,
                            size: 52, color: Colors.white30),
                      ),
                    // badge anno
                    if (widget.year.isNotEmpty)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(136, 27, 22, 22),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(widget.year,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
              // titolo
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: card,
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String label;
  const _EmptyList({required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70)),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: .9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 48),
            const SizedBox(height: 10),
            Text(
              'Cerca tra migliaia di giochi',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Scrivi almeno 3 caratteri per iniziare',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
