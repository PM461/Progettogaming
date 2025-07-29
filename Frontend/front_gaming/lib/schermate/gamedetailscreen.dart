import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/MyLibrary.dart';
import 'package:front_gaming/services/image_services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GameDetailScreen extends StatefulWidget {
  final Game game;

  const GameDetailScreen({required this.game, super.key});

  @override
  _GameDetailScreenState createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late List<Map<String, dynamic>> achievements;

  @override
  void initState() {
    super.initState();
    achievements = List<Map<String, dynamic>>.from(widget.game.achievements);
  }

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
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utente non loggato")),
      );
      return;
    }

    final url = Uri.parse(
      "https://my-flutter-web.onrender.com//user/$userId/game/${widget.game.gameId}/achievement/$index/toggle_achieved",
    );

    try {
      final response = await http.put(url);
      if (response.statusCode == 200) {
        setState(() {
          achievements[index]['achieved'] =
              !(achievements[index]['achieved'] == true);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Obiettivo aggiornato")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Errore aggiornamento")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore di rete")),
      );
    }
  }

  Future<void> _removeGameFromLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utente non loggato")),
      );
      return;
    }

    final url = Uri.parse(
        'https://my-flutter-web.onrender.com//user/$userId/remove_game/${widget.game.gameId}');

    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gioco rimosso dalla libreria")),
        );
        Navigator.of(context).pop(); // Torna indietro alla pagina precedente
      } else {
        final msg = jsonDecode(response.body)['detail'] ?? 'Errore sconosciuto';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $msg")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore di rete")),
      );
    }
  }

  Future<String?> fetchSviluppatoreLogo(String? name) async {
    if (name == null || name.isEmpty) return null;

    final uri = Uri.parse(
        'https://my-flutter-web.onrender.com//company_logo?name=${Uri.encodeComponent(name)}');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['logo'];
      }
    } catch (e) {
      debugPrint('Errore nel fetch del logo: $e');
    }
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoRow(String label, String logoUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: SizedBox(
              width: 50,
              height: 50,
              child: logoUrl.toLowerCase().endsWith('.svg')
                  ? NetworkSvgWidget(url: logoUrl)
                  : Image.network(logoUrl, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.label)),
      body: FutureBuilder<String?>(
        future: fetchSviluppatoreLogo(widget.game.sviluppatore),
        builder: (context, snapshot) {
          final sviluppatoreLogo = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              widget.game.logoImage != null
                  ? Image.network(widget.game.logoImage!)
                  : const Icon(Icons.videogame_asset, size: 100),
              const SizedBox(height: 16),

              // 🔎 Informazioni di dettaglio
              ...[
                _buildRow('Editore', widget.game.editore, context),
                _buildRow('Genere', widget.game.genere, context),
                sviluppatoreLogo != null
                    ? _buildLogoRow('Sviluppatore', sviluppatoreLogo)
                    : _buildRow(
                        'Sviluppatore', widget.game.sviluppatore, context),
                _buildRow('Serie', widget.game.serie, context),
                _buildRow('Piattaforme', widget.game.piattaforma, context),
                _buildRow(
                    'Modalità di gioco', widget.game.modalitaDiGioco, context),
                _buildRow('Dispositivo di ingresso',
                    widget.game.dispositivoIngresso, context),
                _buildRow('Data di pubblicazione',
                    widget.game.dataPubblicazione, context),
                _buildRow('Distributore', widget.game.distributore, context),
                _buildRow('Sito web ufficiale', widget.game.sitoWebUfficiale,
                    context),
                _buildRow('Classificazione USK', widget.game.classificazioneUSK,
                    context),
                _buildRow('Steam ID', widget.game.idSteam, context),
                _buildRow('GOG ID', widget.game.idGOG, context),
              ].whereType<Widget>(),

              const Divider(height: 32),

              // ✅ Stato obiettivi
              Text(
                'Obiettivi completati: ${achievements.where((a) => a['achieved'] == true).length} / ${achievements.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // 🏆 Lista obiettivi interattiva
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = achievements[index];
                    final name = achievement['name'] ?? 'Senza nome';
                    final achieved = achievement['achieved'] == true;
                    final imageUrl = achieved
                        ? (achievement['icon'] ?? '')
                        : (achievement['icongray'] ?? '');

                    return Container(
                      width: 120,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                showAchievementDialog(achievement);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        achieved ? Colors.green : Colors.grey,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl,
                                          fit: BoxFit.contain)
                                      : Icon(
                                          achieved
                                              ? Icons.check_circle
                                              : Icons.star_border,
                                          size: 60,
                                          color: achieved
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
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
                          const SizedBox(height: 4),
                          ElevatedButton(
                            onPressed: () => toggleAchievement(index),
                            child: Text(
                              achieved
                                  ? "Segna come non fatto"
                                  : "Segna come fatto",
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(100, 30),
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              //  Padding finale
              const SizedBox(height: 48),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _removeGameFromLibrary,
        label: const Text("Rimuovi dalla libreria"),
        icon: const Icon(Icons.delete),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
