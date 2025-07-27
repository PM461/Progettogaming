import 'dart:convert';
import 'dart:typed_data';
import 'package:front_gaming/main.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // Per ricevere il token da postMessage
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'ClassicalLogin.dart';
import 'MyLibrary.dart'; // Schermata di login classico
import 'package:flutter_svg/flutter_svg.dart';
import 'package:front_gaming/services/image_services.dart';



class MainScreenState extends State<MainScreen> {
  late Future<String> futureName;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  String _searchError = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> searchGame(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _searchError = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/find_game?query=$query'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = data['results'];
        });
      } else {
        setState(() {
          _searchResults = [];
          _searchError = 'Nessun gioco trovato';
        });
      }
    } catch (e) {
      setState(() {
        _searchError = 'Errore durante la ricerca';
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    futureName = loadName();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: TextField(
    controller: _searchController,
    onChanged: (value) => searchGame(value),
    decoration: InputDecoration(
      labelText: 'Cerca un gioco...',
      prefixIcon: const Icon(Icons.search),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    ),
    style: Theme.of(context).textTheme.bodyLarge,
  ),
),
          const SizedBox(height: 10),
          if (_isSearching) const CircularProgressIndicator(),
          if (_searchError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _searchError,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return ListTile(
                      leading: (() {
                        final logoUrl =
                            item['details']?['logo image'] as String? ??
                                item['details']?['logo'] as String? ??
                                item['details']?['image']?['logo'] as String?;

                        if (logoUrl != null && logoUrl.isNotEmpty) {
                          final isSvg = logoUrl.toLowerCase().endsWith('.svg');
                          if (isSvg) {
                            return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: NetworkSvgWidget(
          url: logoUrl,
          
          // modifica il fit nel widget stesso come BoxFit.contain, ti faccio vedere sotto
        ),
      );
                          } else {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                logoUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.contain,
                                //errorBuilder: (context, error, stackTrace) {
                                //  print('Errore caricamento immagine: $error');
                                //  return const Icon(Icons.broken_image);
                               // },
                              ),
                            );
                          }
                        } else {
                          return const Icon(Icons.videogame_asset);
                        }
                      })(),
                      title: Text(
    item['label']?.toString() ?? 'Senza nome',
    style: const TextStyle(fontSize: 16),
  ),onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Gamedatascreen(game: item),
      ),
    );
  },
                    );
                  }),
            ),
          if (_searchResults.isEmpty &&
              !_isSearching &&
              _searchController.text.length >= 3)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Nessun risultato'),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: IconButton(
              icon: const CircleAvatar(
                radius: 30,
                backgroundImage: AssetImage('assets/avatar_placeholder.png'),
              ),
              iconSize: 60,
              tooltip: 'Vai alla libreria',
              onPressed: () {
                Navigator.pushNamed(context, '/library');
              },
            ),
          ),
        ],
      ),
    );
  }
}