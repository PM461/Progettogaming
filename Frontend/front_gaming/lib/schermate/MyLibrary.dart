import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/gamedetailscreen.dart';
import 'package:front_gaming/services/image_services.dart';
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
                                    fit: BoxFit.contain,
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

