import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class Game {
  final String gameId;
  final String label;
  final String? logoImage;
  final List<dynamic> achievements;

  final String? editore;
  final String? genere;
  final String? sviluppatore;
  final String? serie;
  final List<String>? piattaforma;
  final String? modalitaDiGioco;
  final String? dispositivoIngresso;
  final DateTime? dataPubblicazione;
  final List<String>? distributore;
  final String? sitoWebUfficiale;
  final String? classificazioneUSK;
  final String? idSteam;
  final String? idGOG;

  Game({
    required this.gameId,
    required this.label,
    required this.logoImage,
    required this.achievements,
    this.editore,
    this.genere,
    this.sviluppatore,
    this.serie,
    this.piattaforma,
    this.modalitaDiGioco,
    this.dispositivoIngresso,
    this.dataPubblicazione,
    this.distributore,
    this.sitoWebUfficiale,
    this.classificazioneUSK,
    this.idSteam,
    this.idGOG,
  });

factory Game.fromJson(Map<String, dynamic> json) {
  return Game(
    gameId: toStringOrNull(json['game_id']) ?? 'Sconosciuto',
    label: toStringOrNull(json['label']) ?? 'Sconosciuto',
    logoImage: toStringOrNull(json['logo image']),
    achievements: json['achievements'] ?? [],
    editore: toStringOrNullList(json['editore'])?.join(', '),
    genere: toStringOrNullList(json['genere'])?.join(', '),
    sviluppatore: toStringOrNull(json['sviluppatore']),
    serie: toStringOrNull(json['serie']),
    piattaforma: toStringOrNullList(json['piattaforma']),
    modalitaDiGioco: toStringOrNullList(json['modalità_di_gioco'])?.join(', '),
    dispositivoIngresso:
        toStringOrNullList(json['dispositivo_di_ingresso'])?.join(', '),
    dataPubblicazione: parseDate(json['data_di_pubblicazione']),
    distributore: toStringOrNullList(json['distributore']),
    sitoWebUfficiale: toStringOrNull(json['sito_web_ufficiale']),
    classificazioneUSK: toStringOrNull(json['classificazione_USK']),
    idSteam: toStringOrNull(json['identificativo_Steam']),
    idGOG: toStringOrNull(json['identificativo_GOG.com']),
  );
}


}

List<String>? toStringOrNullList(dynamic val) {
  if (val == null) return null;
  if (val is String) {
    return val.toLowerCase() == "n/a" ? null : [val];
  }
  if (val is List) {
    return val
        .where((e) => e != null && e.toString().toLowerCase() != "n/a")
        .map((e) => e.toString())
        .toList();
  }
  return null;
}

String? toStringOrNull(dynamic val) {
  if (val == null) return null;
  if (val is String) {
    return val.toLowerCase() == "n/a" ? null : val;
  }
  if (val is List && val.isNotEmpty) {
    return val.first.toString();
  }
  return val.toString();
}

List<String>? toStringList(dynamic val) {
  if (val == null) return null;
  if (val is String) {
    return val.toLowerCase() == "n/a" ? null : [val];
  }
  if (val is List) {
    return val
        .where((e) => e != null && e.toString().toLowerCase() != "n/a")
        .map((e) => e.toString())
        .toList();
  }
  return null;
}

DateTime? parseDate(dynamic val) {
  try {
    if (val == null) return null;
    if (val is String && val.isNotEmpty) return DateTime.parse(val);
    if (val is List && val.isNotEmpty) return DateTime.parse(val.first);
  } catch (e) {
    debugPrint("Errore parsing data: $val");
  }
  return null;
}


class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  late Future<List<Game>> futureGames;

  @override
  void initState() {
    super.initState();
    futureGames = fetchUserGames();
  }

  Future<List<Game>> fetchUserGames() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null || userId.isEmpty) {
      throw Exception("ID utente non trovato");
    }

    final url = Uri.parse('http://localhost:8000/user/$userId/games');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List gamesJson = data['games'];

      return gamesJson.map((json) => Game.fromJson(json)).toList();
    } else {
      throw Exception("Errore nel recupero dei giochi");
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('La mia libreria')),
    body: FutureBuilder<List<Game>>(
      future: futureGames,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Errore: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Nessun gioco trovato"));
        }

        final games = snapshot.data!;
        return Container(  // <-- qui serve il return
          margin: const EdgeInsets.symmetric(vertical: 20),
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return Container(
                width: 180,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameDetailScreen(game: game),
                      ),
                    );
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 16,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: game.logoImage != null
                                ? Image.network(
                                    game.logoImage!,
                                    fit: BoxFit.cover,
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
                          flex: 9,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${game.achievements.length} obiettivi',
                                  style: Theme.of(context).textTheme.bodySmall,
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
            },
          ),
        );
      },
    ),
  );
}

}

class GameDetailScreen extends StatelessWidget {
  final Game game;

  const GameDetailScreen({required this.game, super.key});

  @override
  Widget build(BuildContext context) {
    Widget? row(String label, dynamic value) {
      if (value == null || value.toString().toLowerCase() == 'n/a') {
        return null; // Non mostrare niente
      }

      String text;
      if (value is List<String>) {
        text = value.join(', ');
      } else if (value is DateTime) {
        text = "${value.day}/${value.month}/${value.year}";
      } else {
        text = value.toString();
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: text),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(game.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          game.logoImage != null
              ? Image.network(game.logoImage!)
              : const Icon(Icons.videogame_asset, size: 100),
          const SizedBox(height: 16),
          ...[
            row('Editore', game.editore),
            row('Genere', game.genere),
            row('Sviluppatore', game.sviluppatore),
            row('Serie', game.serie),
            row('Piattaforme', game.piattaforma),
            row('Modalità', game.modalitaDiGioco),
            row('Dispositivo', game.dispositivoIngresso),
            row('Pubblicazione', game.dataPubblicazione),
            row('Distributore', game.distributore),
            row('Sito web', game.sitoWebUfficiale),
            row('Classificazione USK', game.classificazioneUSK),
            row('Steam ID', game.idSteam),
            row('GOG ID', game.idGOG),
          ].whereType<Widget>(), // rimuove i null!
          const Divider(),
          Text(
              'Obiettivi completati: ${game.achievements.where((a) => a['achieved'] == true).length} / ${game.achievements.length}'),
          const SizedBox(height: 16),

          // Qui inseriamo la lista orizzontale degli achievements
          SizedBox(
  height: 120,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: game.achievements.length,
    itemBuilder: (context, index) {
      final achievement = game.achievements[index];
      final imageUrl = achievement['image'] ?? '';
      final name = achievement['name'] ?? 'Senza nome';
      final achieved = achievement['achieved'] == true;

      return Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: achieved ? Colors.green : Colors.grey,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Icon(
                          achieved ? Icons.check_circle : Icons.star_border,
                          size: 60,
                          color: achieved ? Colors.green : Colors.grey,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  ),
),

        ],
      ),
    );
  }
}
