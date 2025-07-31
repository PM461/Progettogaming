import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:front_gaming/schermate/gamedetail.dart'; // o dove hai la pagina dettaglio gioco
import 'package:front_gaming/services/image_services.dart';
import 'package:front_gaming/services/profile_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _annoController = TextEditingController();
  final TextEditingController _sviluppatoreController = TextEditingController();

  List<dynamic> _searchResults = [];
  List<dynamic> _filteredResults = [];
  bool _isSearching = false;
  String _searchError = '';
  String? _profileImageName;
  Set<String> availableGeneri = {};
  Set<String> availableAnni = {};
  Set<String> availableSviluppatori = {};
  String? _selectedGenere = 'Tutti';

  // Lista generi esempio, puoi adattarla
  final List<String> generi = [
    'Tutti',
    'Azione',
    'Avventura',
    'RPG',
    'Strategia',
    'Simulazione',
    'Sport',
    'Puzzle',
    // aggiungi i generi che ti servono
  ];
  String cleanGenere(dynamic g) {
    if (g == null) return '';
    if (g is String) {
      return g.trim().toLowerCase().replaceAll(RegExp(r'[^a-zàèéìòù\s]'), '');
    }
    if (g is List) {
      // Unisci tutti i generi puliti in una stringa separata da virgola o spazio
      return g
          .map((e) => e
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-zàèéìòù\s]'), ''))
          .join(','); // o ' ' se preferisci
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadGeneri();
  }

  Future<void> _loadGeneri() async {
    try {
      const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
      final response = await http.get(Uri.parse('$apiBaseUrl/genres'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Presumo la risposta ha la forma: { "genres": [ { "id": "...", "label": "..." }, ... ] }
        final List<dynamic> genresList = data['genres'];
        setState(() {
          availableGeneri = {
            'Tutti'
          }; // sempre aggiungi "Tutti" come prima voce
          for (var g in genresList) {
            if (g['label'] != null && g['label'].toString().isNotEmpty) {
              availableGeneri.add(g['label'].toString());
            }
          }
          _selectedGenere = 'Tutti'; // default selezionato
        });
      } else {
        print('Errore caricamento generi: ${response.statusCode}');
      }
    } catch (e) {
      print('Eccezione caricamento generi: $e');
    }
  }

  Future<void> _loadProfileImage() async {
    final imageName = await ProfileService.getProfileImageName();
    setState(() {
      _profileImageName = imageName;
    });
  }

  Future<void> searchGame(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _searchError = '';
        availableGeneri = {};
        availableAnni = {};
        availableSviluppatori = {};
        _selectedGenere = null;
        _annoController.text = '';
        _sviluppatoreController.text = '';
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
        final results = data['results'] as List<dynamic>;
        _filteredResults = results;

        final generiSet = <String>{};
        final anniSet = <String>{};
        final sviluppatoriSet = <String>{};

        for (var game in results) {
          dynamic rawGenere =
              game['details']?['genere'] ?? game['details']?['genre'];

          if (rawGenere != null) {
            if (rawGenere is String) {
              String gClean = cleanGenere(rawGenere);
              if (gClean.isNotEmpty) generiSet.addAll(gClean.split(','));
            } else if (rawGenere is List) {
              for (var g in rawGenere) {
                String gClean = cleanGenere(g);
                if (gClean.isNotEmpty) generiSet.add(gClean);
              }
            }
          }
        }

        setState(() {
          _searchResults = results;
          availableGeneri = {'tutti'};
          availableGeneri.addAll(generiSet);
          availableAnni = anniSet;
          availableSviluppatori = sviluppatoriSet;

          // Reset selezione genere se non più valida
          if (_selectedGenere == null ||
              !availableGeneri.contains(_selectedGenere!.toLowerCase())) {
            _selectedGenere = 'tutti';
          }

          if (!availableAnni.contains(_annoController.text)) {
            _annoController.text = '';
          }

          if (!availableSviluppatori.contains(_sviluppatoreController.text)) {
            _sviluppatoreController.text = '';
          }

          _applyFilters(); // Applica filtri ai nuovi risultati
        });
      } else {
        setState(() {
          _searchResults = [];
          _searchError = 'Nessun gioco trovato';
          availableGeneri = {};
          availableAnni = {};
          availableSviluppatori = {};
        });
      }
    } catch (e) {
      print('Eccezione durante la ricerca: $e');
      setState(() {
        _searchError = 'Errore durante la ricerca: $e';
        _searchResults = [];
        availableGeneri = {};
        availableAnni = {};
        availableSviluppatori = {};
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = _searchResults;

    // Genere
    if (_selectedGenere != null &&
        _selectedGenere!.isNotEmpty &&
        _selectedGenere != 'tutti') {
      filtered = filtered.where((game) {
        dynamic rawGenere =
            game['details']?['genere'] ?? game['details']?['genre'] ?? '';

        if (rawGenere is String) {
          String genere = cleanGenere(rawGenere);
          return genere.split(',').contains(
              _selectedGenere); // perché cleanGenere per lista usa virgola
        } else if (rawGenere is List) {
          // pulisci ogni elemento e verifica se uno coincide
          return rawGenere.any((e) {
            String gClean = cleanGenere(e);
            return gClean == _selectedGenere;
          });
        }
        return false;
      }).toList();
    }

    // Anno
    final annoFiltro = _annoController.text.trim();
    if (annoFiltro.isNotEmpty) {
      filtered = filtered.where((game) {
        final dataPub = game['details']['data di pubblicazione'] ??
            game['details']['publication date'] ??
            '';
        final dataPubStr = dataPub.toString();
        final anno = dataPubStr.length >= 4 ? dataPubStr.substring(0, 4) : '';
        return anno == annoFiltro;
      }).toList();
    }

    // Sviluppatore
    final sviluppatoreFiltro =
        _sviluppatoreController.text.trim().toLowerCase();

    if (sviluppatoreFiltro.isNotEmpty) {
      filtered = filtered.where((game) {
        final rawDev = game['sviluppatore'] ??
            game['details']?['sviluppatore'] ??
            game['details']?['developer'];

        if (rawDev == null) return false;

        if (rawDev is String) {
          return rawDev.toLowerCase().contains(sviluppatoreFiltro);
        } else if (rawDev is List) {
          return rawDev.any((dev) =>
              dev.toString().toLowerCase().contains(sviluppatoreFiltro));
        }
        return false;
      }).toList();
    }

    setState(() {
      _filteredResults = filtered;
    });
  }

  // Quando cambia un filtro aggiorni i risultati
  void _onFilterChanged() {
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _annoController.dispose();
    _sviluppatoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(selectedImageName: _profileImageName),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cerca un gioco...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                searchGame(value);
              },
            ),
          ),

          // FILTRI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Row(
              children: [
                // Genere Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGenere,
                    decoration: const InputDecoration(
                      labelText: 'Filtra per genere',
                      border: OutlineInputBorder(),
                    ),
                    items: availableGeneri
                        .map<DropdownMenuItem<String>>((String genere) {
                      // Primo carattere maiuscolo, resto minuscolo
                      final display = genere.isNotEmpty
                          ? genere[0].toUpperCase() + genere.substring(1)
                          : genere;
                      return DropdownMenuItem<String>(
                        value: genere,
                        child: Text(display),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGenere = newValue;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Anno TextField
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _annoController,
                    decoration: InputDecoration(
                      labelText: 'Anno',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (value) {
                      _onFilterChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Sviluppatore TextField
                Expanded(
                  child: TextField(
                    controller: _sviluppatoreController,
                    decoration: InputDecoration(
                      labelText: 'Sviluppatore',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) {
                      _onFilterChanged();
                    },
                  ),
                ),
              ],
            ),
          ),

          if (_isSearching) const LinearProgressIndicator(),
          if (_searchError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child:
                  Text(_searchError, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                itemCount: _filteredResults.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1 / 1,
                ),
                itemBuilder: (context, index) {
                  final item = _filteredResults[index];
                  final logoUrl = item['details']?['logo image'] as String? ??
                      item['details']?['logo'] as String? ??
                      item['details']?['image']?['logo'] as String?;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Gamedatascreen(game: item),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: logoUrl != null
                                  ? (logoUrl.toLowerCase().endsWith('.svg')
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: NetworkSvgWidget(url: logoUrl),
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            logoUrl,
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                          ),
                                        ))
                                  : const Icon(Icons.videogame_asset, size: 40),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              item['label']?.toString() ?? 'Senza nome',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
