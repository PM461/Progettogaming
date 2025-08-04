import 'dart:convert';
import 'dart:typed_data';
import 'package:front_gaming/main.dart';

import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/services/auth_service.dart';
import 'package:front_gaming/services/drag.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // Per ricevere il token da postMessage
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'ClassicalLogin.dart';
import 'MyLibrary.dart'; // Schermata di login classico
import 'package:flutter_svg/flutter_svg.dart';
import 'package:front_gaming/services/image_services.dart';
import 'search_page.dart';

const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

class MainScreenState extends State<MainScreen> {
  late Future<String> futureName;
  List<Map<String, dynamic>> raccomandati = [];
  List<Map<String, dynamic>> nuoviSimili = [];
  int _currentIndex = 0;

  String? _selectedImageName;
  bool _hasLoadedOnce = false;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    futureName = loadName();
    _loadProfileImage();
    _loadRecommendations();
    _checkFirstAccessAndShowPopup(); // <--- qui
    _pages.add(_buildHomeContent());
    _pages.add(const MyLibraryScreen());
    _pages.add(const ProfilePage());
  }

  Future<void> _loadRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) return;

    try {
      final res = await http.get(Uri.parse(
          '$apiBaseUrl/api/users/get-raccomandazioni?user_id=$userId')); // usa la nuova API

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final raccomandazione = data['raccomandazione'] ?? {};
        final recommendations = raccomandazione['recommendations'] ?? {};

        // Ora ogni lista è già una lista di giochi dettagliati
        raccomandati = List<Map<String, dynamic>>.from(
            recommendations['raccomandati'] ?? []);
        nuoviSimili = List<Map<String, dynamic>>.from(
            recommendations['nuovi_simili'] ?? []);

        setState(() {});
      }
    } catch (e) {
      debugPrint('Errore nel caricamento delle raccomandazioni: $e');
    }
  }

  void _showClassicGamePopup(String userId) {
    final capturedContext = context;

    http.get(Uri.parse('$apiBaseUrl/api/users/get-game-guide')).then((res) {
      if (res.statusCode == 200) {
        final guide = jsonDecode(res.body);
        final classicGamesByCategory =
            guide['classic_games'] as Map<String, dynamic>;

        // Unisci tutte le liste in una sola
        final classicGames = classicGamesByCategory.values
            .expand((categoryList) => categoryList)
            .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
            .toList();

        List<String> selectedIds = [];

        showDialog(
          context: capturedContext,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
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
                        title:
                            const Text('Benvenuto! Aggiungi giochi classici'),
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
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: classicGames.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                              itemBuilder: (context, index) {
                                final game = classicGames[index];
                                final gameId = game['wikidata_id'];
                                final isSelected = selectedIds.contains(gameId);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedIds.remove(gameId);
                                      } else {
                                        selectedIds.add(gameId);
                                      }
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blueAccent.withOpacity(0.6)
                                          : Colors.white12,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.white24,
                                        width: 2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Immagine del gioco
                                        if (game.containsKey('image_url') &&
                                            game['image_url'] != null)
                                          Expanded(
                                            child: Image.network(
                                              game['image_url'],
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  const Icon(Icons.broken_image,
                                                      size: 48,
                                                      color: Colors.white30),
                                            ),
                                          )
                                        else
                                          const Icon(Icons.videogame_asset,
                                              size: 48, color: Colors.white),

                                        const SizedBox(height: 8),
                                        // Titolo del gioco
                                        if (game.containsKey('title') &&
                                            game['title'] != null)
                                          Text(
                                            game['title'],
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        else
                                          Text(
                                            gameId,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                      ],
                                    ),
                                  ),
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
                                        // Aggiungi ogni gioco singolarmente
                                        for (final gameId in selectedIds) {
                                          final addRes = await http.post(
                                            Uri.parse(
                                                '$apiBaseUrl/user/$userId/add_game/$gameId'),
                                          );
                                          if (addRes.statusCode != 200) {
                                            throw Exception(
                                                'Errore aggiunta gioco $gameId');
                                          }
                                        }

                                        // Imposta isfirst a 1
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

                                          // Reindirizza alla home (modifica qui se usi Navigator, esempio)
                                          Navigator.of(capturedContext)
                                              .pushReplacementNamed('/main');
                                        } else {
                                          throw Exception(
                                              'Errore aggiornamento isfirst');
                                        }
                                      } catch (e) {
                                        debugPrint(
                                            'Errore durante l\'aggiunta giochi o aggiornamento isfirst: $e');
                                        // Qui puoi mostrare un alert o snackbar con errore
                                      }
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
      }
    }).catchError((e) {
      debugPrint('Errore caricamento game guide: $e');
    });
  }

  Future<List<Map<String, dynamic>>> _fetchGamesByIds(
      List<String> ids, String baseUrl) async {
    final List<Map<String, dynamic>> games = [];

    for (final id in ids) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/game/$id'));
        if (res.statusCode == 200) {
          games.add(jsonDecode(res.body));
        }
      } catch (_) {
        continue;
      }
    }

    return games;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
      _loadProfileImage();

      // Mostra il popup dopo che il widget è visibile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkFirstAccessAndShowPopup();
      });
    }
  }

  Future<void> _checkFirstAccessAndShowPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final isFirst = data['isfirst'] == 0;
        final userId = data['_id']?.toString();

        debugPrint('✅ isFirst from /auth/me = $isFirst');

        if (isFirst && userId != null) {
          _showClassicGamePopup(userId); // 🔁 usa direttamente
        }
      } else {
        debugPrint('Errore nel fetch di /auth/me: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore nel controllo isfirst: $e');
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? imageName = prefs.getString('profile_image');
    final userId = prefs.getString('user_id');

    if (imageName != null && imageName.isNotEmpty) {
      setState(() {
        _selectedImageName = imageName;
      });
    } else if (userId != null && userId.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/api/users/get-propic?user_id=$userId'),
        );

        if (response.statusCode == 200) {
          final index = int.tryParse(response.body);
          if (index != null && index >= 0) {
            imageName = '$index';
            await prefs.setString('profile_image', imageName);
            setState(() {
              _selectedImageName = imageName;
            });
          }
        }
      } catch (e) {
        debugPrint('Errore durante il fetch della propic: $e');
      }
    } else {
      setState(() {
        _selectedImageName = '1';
      });
    }
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

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          DraggableGameList(
            title: "🎮 Raccomandati per te",
            games: raccomandati,
          ),
          const SizedBox(height: 30),
          DraggableGameList(
            title: "🆕 Nuovi aggiunti simili ai tuoi gusti",
            games: nuoviSimili,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeContent(), // solo widget senza Scaffold
      const MyLibraryScreen(), // assicurati che anche qui NON ci sia Scaffold/AppBar
      const ProfilePage(), // idem come sopra
    ];

    return Scaffold(
      appBar: CustomAppBar(
          selectedImageName: _selectedImageName), // qui solo la tua AppBar
      body: pages[_currentIndex],
    );
  }
}

// Placeholder per pagina Profilo, da sostituire con la tua implementazione
class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Solo contenuto, niente Scaffold o AppBar
    return Center(child: Text('Pagina Profilo'));
  }
}
