import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/models/game.dart';
import 'package:front_gaming/schermate/gamedetailscreen.dart';
import 'package:front_gaming/services/image_services.dart';
import 'package:front_gaming/services/profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';



class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  late Future<Map<String, List<Game>>>
      futureListsWithGames; // Map: listaNome -> listaGiochi
  String? _profileImageName;

  @override
  void initState() {
    super.initState();
    futureListsWithGames = fetchListsAndGames();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final imageName = await ProfileService.getProfileImageName();
    setState(() {
      _profileImageName = imageName;
    });
  }

  Future<Map<String, List<Game>>> fetchListsAndGames() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      throw Exception("ID utente non trovato");
    }
    const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    // Chiamata per ottenere giochi
    final gamesUrl = Uri.parse('$apiBaseUrl/user/$userId/games');
    final gamesResponse = await http.get(gamesUrl);
    if (gamesResponse.statusCode != 200) {
      throw Exception("Errore nel recupero dei giochi");
    }
    final gamesData = jsonDecode(gamesResponse.body);
    List<Game> allGames = (gamesData['games'] as List)
        .map((json) => Game.fromJson(json))
        .toList();

    // Chiamata per ottenere liste
    final listsUrl = Uri.parse('$apiBaseUrl/user/$userId/lists');
    final listsResponse = await http.get(listsUrl);
    if (listsResponse.statusCode != 200) {
      throw Exception("Errore nel recupero delle liste");
    }
    final listsData = jsonDecode(listsResponse.body);
    List<dynamic> lists = listsData['lists'];

    // Mappatura giochi per id per rapido accesso
    Map<String, Game> gamesById = {
      for (var game in allGames) game.gameId: game
    };

    // Costruzione mappa nome lista -> giochi
    Map<String, List<Game>> listsWithGames = {};
    for (var list in lists) {
      String listName = list['name'] ?? 'Senza nome';
      List<dynamic> gameIds = list['game_ids'] ?? [];

      listsWithGames[listName] = gameIds
          .map((id) => gamesById[id])
          .whereType<Game>()
          .toList(); // filtra null
    }
    // Aggiungiamo la sezione "Tutti i giochi"
    listsWithGames = {
      "Tutti i giochi": allGames,
      ...listsWithGames,
    };

    return listsWithGames;
  }

  Future<void> _removeGameFromList(String gameId, String listName) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      throw Exception("ID utente non trovato");
    }
    const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    final url = Uri.parse(
        '$apiBaseUrl/user/$userId/remove_game_from_list?list_name=${Uri.encodeQueryComponent(listName)}&game_id=${Uri.encodeQueryComponent(gameId)}');

    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception(
          "Errore durante la rimozione del gioco dalla lista: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(selectedImageName: _profileImageName),
      body: FutureBuilder<Map<String, List<Game>>>(
        future: futureListsWithGames,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Image.asset(
                'images/logow.gif',
                width: 60,
                height: 60,
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text("Errore: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nessuna lista trovata"));
          }

          final listsWithGames = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: listsWithGames.entries.map((entry) {
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
                        crossAxisCount = 2; // schermi piccoli
                      } else if (width < 800) {
                        crossAxisCount = 4; // tablet o schermi medi
                      } else {
                        crossAxisCount = 6; // schermi grandi
                      }

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1 / 1.3,
                        children: games.map((game) {
                          // qui metti il codice delle tue card, come già avevi
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GameDetailScreen(game: game),
                                    ),
                                  );
                                },
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
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
                                          child: game.logoImage != null
                                              ? Image.network(
                                                  game.logoImage!,
                                                  fit: BoxFit.contain,
                                                )
                                              : Container(
                                                  color: Colors.grey.shade300,
                                                  child: const Icon(
                                                      Icons.videogame_asset,
                                                      size: 60,
                                                      color: Colors.grey),
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
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${game.achievements.length} obiettivi',
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
                              ),
                              if (listName != "Tutti i giochi")
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color:
                                            Color.fromARGB(255, 54, 165, 244)),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Rimuovi gioco'),
                                          content: Text(
                                              'Sei sicuro di voler rimuovere "${game.label}" dalla lista "$listName"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Annulla'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Rimuovi'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        await _removeGameFromList(
                                            game.gameId, listName);
                                        setState(() {
                                          futureListsWithGames =
                                              fetchListsAndGames();
                                        });
                                      }
                                    },
                                  ),
                                ),
                            ],
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
