import 'dart:convert';
import 'dart:typed_data';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/schermate/profilescreen.dart';
import 'package:front_gaming/services/profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // Per ricevere il token da postMessage
import 'services/auth_service.dart';
import 'schermate/ClassicalLogin.dart';
import 'schermate/MyLibrary.dart'; // Schermata di login classico
import 'package:flutter_svg/flutter_svg.dart';
import 'package:front_gaming/services/image_services.dart';
import 'package:front_gaming/schermate/mainscreenstate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

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
        '/details': (context) => const Placeholder(),
        '/profile': (context) => const ProfileScreen(),
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
  String? _profileImageName;
  Future<void> _loadProfileImage() async {
    final imageName = await ProfileService.getProfileImageName();
    setState(() {
      _profileImageName = imageName;
    });
  }

  @override
  void initState() {
    super.initState();
    _listenForToken();
    _checkLogin();
    _loadProfileImage();
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
  State<MainScreen> createState() => MainScreenState();
}

Future<String> getName(String uid) async {
  const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final url = Uri.parse('$apiBaseUrl/api/users/get-nickname?user_id=$uid');

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
  const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final url = Uri.parse('$apiBaseUrl/api/auth/me');

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
  const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final apiUrl =
      '$apiBaseUrl/convert_svg_to_png?url=${Uri.encodeComponent(svgUrl)}';

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
