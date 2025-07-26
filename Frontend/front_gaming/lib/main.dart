import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // Per ricevere il token da postMessage
import 'services/auth_service.dart';
import 'schermate/ClassicalLogin.dart';
import 'schermate/MyLibrary.dart'; // Schermata di login classico
import 'package:flutter_svg/flutter_svg.dart';
import 'package:front_gaming/services/image_services.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'Benvenuto'),
        '/main': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/library': (context) => const MyLibraryScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _listenForToken();
    _checkLogin();
  }

  void _listenForToken() {
    html.window.onMessage.listen((event) async {
      final data = event.data;
      if (data != null && data.toString().startsWith("access_token=")) {
        final token = data.toString().split("access_token=")[1];
        try {
          await AuthService.saveToken(token);
        } catch (e) {
          print('Errore nel salvataggio token e user_id: $e');
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      }
    });
  }

  void _checkLogin() async {
    bool loggedIn = await AuthService.isLoggedIn();
    if (loggedIn && mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: AuthService.googleLogin,
              child: const Text("Login con Google"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text("Login classico"),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Future<String> futureName;

  TextEditingController _searchController = TextEditingController();
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
              onChanged: (value) {
                searchGame(value);
              },
              decoration: InputDecoration(
                hintText: 'Cerca un gioco...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
  ),
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

Future<String> getName(String uid) async {
  final url =
      Uri.parse('http://localhost:8000/api/users/get-nickname?user_id=$uid');

  final response = await http.get(
    url,
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data.containsKey('name') &&
        data['name'] != null &&
        data['name'].toString().isNotEmpty) {
      return data['name'];
    } else if (data.containsKey('message')) {
      // se la API ritorna un messaggio di errore
      throw Exception(data['message']);
    } else {
      throw Exception('Nickname non trovato');
    }
  } else {
    throw Exception('Utente non trovato, status code: ${response.statusCode}');
  }
}

Future<String> fetchUserName(String token) async {
  final url = Uri.parse('http://localhost:8000/api/auth/me');

  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data['name'] != null && data['name'].toString().isNotEmpty) {
      return data['name'];
    } else {
      throw Exception('Nome utente non trovato nella risposta');
    }
  } else {
    throw Exception('Errore API: status code ${response.statusCode}');
  }
}

Future<String> getUserName({String? token, String? uid}) async {
  // Se c'è il token, prova a ottenere il nome da /auth/me
  if (token != null && token.isNotEmpty) {
    try {
      return await fetchUserName(token);
    } catch (e) {
      print('fetchUserName fallito: $e');
      // continua e prova con uid
    }
  }

  // Se non funziona o token non presente, prova con uid
  if (uid != null && uid.isNotEmpty) {
    try {
      return await getName(uid);
    } catch (e) {
      print('getName fallito: $e');
      // Se fallisce anche questo, rilancia errore
      throw Exception('Impossibile ottenere il nome utente da token o uid');
    }
  }

  // Se nessuno dei due parametri è fornito o validi
  throw Exception('Né token né uid forniti');
}

Future<Uint8List?> fetchPngFromSvgUrl(String svgUrl) async {
  final apiUrl = 'http://localhost:8001/convert_svg_to_png?url=${Uri.encodeComponent(svgUrl)}';

  try {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print('Errore nella conversione: ${response.statusCode}');
    }
  } catch (e) {
    print('Errore chiamata API SVG→PNG: $e');
  }

  return null;
}
