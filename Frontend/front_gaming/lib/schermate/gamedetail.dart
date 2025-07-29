import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:front_gaming/services/image_services.dart';

class Gamedatascreen extends StatefulWidget {
  final Map<String, dynamic> game;

  const Gamedatascreen({super.key, required this.game});

  @override
  State<Gamedatascreen> createState() => _GamedatascreenState();
}

class _GamedatascreenState extends State<Gamedatascreen> {
  late String gameId;
  bool isInLibrary = false;
  String? userId;
  bool isLoading = true;
  String? _companyLogo;
  bool _isLogoLoading = true;

  // Mappa per memorizzare i loghi degli editori
  Map<String, String> publisherLogos = {};

  @override
  void initState() {
    super.initState();
    gameId = widget.game['_id'].toString();

    getUserId().then((uid) {
      if (mounted) {
        setState(() {
          userId = uid;
        });

        _checkLibraryStatus();

        // Prendi nome sviluppatore con fallback sicuro
        final details = widget.game['details'] as Map<String, dynamic>? ?? {};
        final developerName =
            details['sviluppatore'] ?? details['developer'] ?? '';
        if (developerName.toString().isNotEmpty) {
          _fetchLogo(developerName.toString());
        }

        // Prendi nome editore e fetch logo
        final publisherName = details['editore'] ?? details['publisher'] ?? '';
        if (publisherName.toString().isNotEmpty) {
          _fetchPublisherLogo(publisherName.toString());
        }
      }
    });
  }

  Future<void> _showAddToListDialog() async {
    if (userId == null) return;

    final url = Uri.parse(
        'https://https://my-backend-ucgu.onrender.com//user/$userId/lists');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore nel recupero delle liste.")),
      );
      return;
    }

    final data = json.decode(response.body);
    final lists = data['lists'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Seleziona una lista"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                return ListTile(
                  title: Text(list['name']),
                  onTap: () async {
                    Navigator.pop(context);
                    await _addGameToLibraryIfNeeded();
                    await _addGameToList(list['name']);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCreateListDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Crea nuova lista"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Nome della lista"),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty || userId == null) return;

                Navigator.pop(context);
                await _addGameToLibraryIfNeeded();

                final url = Uri.parse(
                    "https://https://my-backend-ucgu.onrender.com//user/$userId/create_list");
                final response = await http.post(
                  url,
                  headers: {"Content-Type": "application/json"},
                  body: json.encode({
                    "name": name,
                    "game_ids": [gameId]
                  }),
                );

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Lista creata e gioco aggiunto!")),
                  );
                } else {
                  final error = json.decode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("Errore: ${error['detail'] ?? 'generico'}")),
                  );
                }
              },
              child: const Text("Crea"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addGameToLibraryIfNeeded() async {
    if (!isInLibrary && userId != null) {
      final url = Uri.parse(
          'https://https://my-backend-ucgu.onrender.com//user/$userId/add_game/$gameId');
      final response = await http.post(url);
      if (response.statusCode == 200) {
        setState(() {
          isInLibrary = true;
        });
      }
    }
  }

  Future<void> _addGameToList(String listName) async {
    final url = Uri.parse(
        "https://https://my-backend-ucgu.onrender.com//user/$userId/add_game_to_list");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "name": listName,
        "game_id": gameId,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gioco aggiunto alla lista '$listName'")),
      );
    } else {
      final error = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: ${error['detail'] ?? 'generico'}")),
      );
    }
  }

  Future<void> _fetchLogo(String company) async {
    final encodedCompany = Uri.encodeComponent(company);
    final apiUrl =
        'https://https://my-backend-ucgu.onrender.com//company_logo?name=$encodedCompany';
    print('Fetching company logo for "$company" from $apiUrl');
    try {
      final response = await http.get(Uri.parse(apiUrl));
      print('Company logo response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Company logo response data: $data');
        final logo = data['logo'] as String?;
        if (mounted) {
          setState(() {
            _companyLogo = logo;
            _isLogoLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLogoLoading = false);
        }
      }
    } catch (e) {
      print('Exception fetching company logo: $e');
      if (mounted) {
        setState(() => _isLogoLoading = false);
      }
    }
  }

  Future<void> _fetchPublisherLogo(String publisherName) async {
    final encodedName = Uri.encodeComponent(publisherName);
    final apiUrl =
        'https://https://my-backend-ucgu.onrender.com//publisher_logo/$encodedName';
    print('Fetching publisher logo for "$publisherName" from $apiUrl');
    try {
      final response = await http.get(Uri.parse(apiUrl));
      print('Publisher logo response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Publisher logo response data: $data');
        final logo = data['logo'] as String?;
        if (logo != null && logo.isNotEmpty && mounted) {
          setState(() {
            publisherLogos[publisherName] = logo;
          });
        }
      }
    } catch (e) {
      print('Exception fetching publisher logo: $e');
    }
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    print("GameDetails user_id: $userId");
    return userId;
  }

  Future<void> _checkLibraryStatus() async {
    print('Checking library status...');
    if (userId == null) {
      print('User ID is null. Cannot check library.');
      setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse(
        'https://https://my-backend-ucgu.onrender.com//user/$userId/games');
    print('Fetching from $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final games = (data['games'] as List?) ?? [];
      final inLib =
          games.any((g) => g['game_id'].toString() == gameId.toString());
      print('Is in library: $inLib');

      setState(() {
        isInLibrary = inLib;
        isLoading = false;
      });
    } else {
      print('HTTP Error: ${response.statusCode}');
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleGameInLibrary() async {
    if (userId == null) return;

    final url = Uri.parse(
      isInLibrary
          ? 'https://https://my-backend-ucgu.onrender.com//user/$userId/remove_game/$gameId'
          : 'https://https://my-backend-ucgu.onrender.com//user/$userId/add_game/$gameId',
    );

    final response = await (isInLibrary ? http.delete(url) : http.post(url));

    if (response.statusCode == 200) {
      // Se rimuoviamo il gioco dalla libreria, rimuoviamolo anche da tutte le liste
      if (isInLibrary) {
        final cleanupUrl = Uri.parse(
          'https://https://my-backend-ucgu.onrender.com//user/$userId/remove_game_from_all_lists/$gameId',
        );
        final cleanupResponse = await http.post(cleanupUrl);

        if (cleanupResponse.statusCode == 200) {
          print("Rimosso anche da tutte le liste");
        } else {
          print("Errore nella rimozione da liste");
        }
      }

      setState(() => isInLibrary = !isInLibrary);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isInLibrary
              ? 'Gioco aggiunto alla collezione'
              : 'Gioco rimosso dalla collezione e da tutte le liste'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nell\'operazione')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.game['details'] as Map<String, dynamic>? ?? {};
    final label = widget.game['label'] ?? 'Titolo sconosciuto';

    final logo = details['logo image'] ??
        details['logo'] ??
        details['image']?['logo'] ??
        '';

    final developerName = details['sviluppatore'] ?? details['developer'];

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (logo.toString().isNotEmpty) ...[
            Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: logo.toString().toLowerCase().endsWith('.svg')
                    ? NetworkSvgWidget(url: logo)
                    : Image.network(logo, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // "Informazioni generali" senza sviluppatore
          _buildSection("Informazioni generali", {
            'Titolo originale': details['title'] ?? details['titolo'],
            'Genere': details['genere'] ?? details['genre'],
            'Editore': details['editore'] ?? details['publisher'],
            'Data di pubblicazione': _formatDate(
                details['data di pubblicazione'] ??
                    details['publication date']),
          }),

          // Sviluppatore con logo o testo
          if (developerName != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Text(
                    'Sviluppatore: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_companyLogo != null && _companyLogo!.isNotEmpty)
                    Tooltip(
                      message: developerName.toString(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: _companyLogo!.toLowerCase().endsWith('.svg')
                            ? NetworkSvgWidget(url: _companyLogo!)
                            : Image.network(_companyLogo!, fit: BoxFit.contain),
                      ),
                    )
                  else
                    Expanded(child: Text(developerName.toString())),
                ],
              ),
            ),

          _buildSection("Serie e piattaforme", {
            'Serie': details['serie'] ?? details['part of the series'],
            'Piattaforma': details['piattaforma'] ?? details['platform'],
            'Distributore':
                details['distributore'] ?? details['distributed by'],
          }),
          _buildSection("Altre info", {
            'Modalità di gioco':
                details['modalità di gioco'] ?? details['game mode'],
            'Nintendo eShop ID': details['identificativo Nintendo eShop'],
            'Metacritic ID':
                details['identificativo Metacritic di un videogioco'],
          }),
        ],
      ),
      floatingActionButton: isLoading || userId == null
          ? FloatingActionButton(
              onPressed: null,
              backgroundColor: Colors.grey,
              child: const Icon(Icons.more_vert),
            )
          : FloatingActionButton(
              onPressed: _showActionMenu,
              child: const Icon(Icons.more_vert),
            ),
    );
  }

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(isInLibrary ? Icons.remove : Icons.library_add),
                title: Text(isInLibrary
                    ? "Rimuovi da libreria"
                    : "Aggiungi a libreria"),
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleGameInLibrary();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text("Aggiungi a lista"),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToListDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text("Crea nuova lista e aggiungi"),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateListDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, Map<String, dynamic> fields) {
    final content = fields.entries.where((e) => e.value != null).map((entry) {
      final value = entry.value;

      // Se è editore e abbiamo il logo, mostra immagine
      if ((entry.key == 'Editore' || entry.key == 'publisher') &&
          value is String) {
        final logoUrl = publisherLogos[value];
        if (logoUrl != null && logoUrl.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Text('${entry.key}:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    width: 80,
                    height: 40,
                    child: logoUrl.toLowerCase().endsWith('.svg')
                        ? NetworkSvgWidget(url: logoUrl)
                        : Image.network(logoUrl, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          );
        }
      }

      // Altrimenti mostra il testo normalmente
      final formatted = value is List ? value.join(', ') : value.toString();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text('${entry.key}:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(flex: 3, child: Text(formatted)),
          ],
        ),
      );
    }).toList();

    if (content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple)),
          const SizedBox(height: 8),
          ...content,
        ],
      ),
    );
  }

  String? _formatDate(dynamic date) {
    if (date is String && DateTime.tryParse(date) != null) {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    }
    return null;
  }
}
