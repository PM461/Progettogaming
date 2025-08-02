import 'dart:convert';
import 'dart:typed_data';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/schermate/profilescreen.dart';
import 'package:front_gaming/schermate/splashscreen.dart';
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
      title: 'GameHub',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color.fromARGB(255, 26, 26, 26),
        colorScheme: const ColorScheme.dark(
          primary: Color.fromARGB(255, 0, 0, 0),
          secondary: Colors.grey,
          background: Colors.black,
          surface: Colors.grey,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 132, 132, 132)),
          bodyMedium: TextStyle(
              fontSize: 16, color: Color.fromARGB(179, 255, 255, 255)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 214, 205, 205),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 93, 93, 93)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide:
                BorderSide(color: Color.fromARGB(255, 238, 63, 208), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: const TextStyle(color: Color.fromARGB(255, 248, 179, 225)),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        cardTheme: CardTheme(
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          margin: const EdgeInsets.all(8),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/': (context) => const MyHomePage(title: 'Benvenuto'),
        '/main': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/library': (context) => const MyLibraryScreen(),
        '/details': (context) => const Placeholder(),
        '/profile': (context) => const ProfileScreen(),
        '/splash': (context) => const SplashScreen(),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o icona simbolica
              const Icon(Icons.sports_esports,
                  size: 100, color: Colors.amberAccent),
              const SizedBox(height: 30),

              // Titolo e descrizione
              const Text(
                'GameHub - Il tuo universo videoludico',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Organizza i giochi che hai completato, registra i tuoi obiettivi, '
                'scopri cosa stanno giocando gli altri e unisciti alla community dei veri gamer. '
                'GameHub è il tuo punto di riferimento su web e mobile per tutto ciò che è gaming.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Pulsante login Google
              ElevatedButton.icon(
                onPressed: () async {
                  await AuthService.googleLogin(); // Aggiungi "await" e "()"
                  Navigator.pushNamed(
                      context, '/splash'); // Navigazione dopo il login
                },
                icon: const Icon(Icons.login),
                label: const Text("Login con Google"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // Pulsante login classico
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text("Login classico"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),

              // Pulsante registrazione solo se non loggato

              TextButton(
                onPressed: () {
                  // Dovrai creare questa schermata e route '/register'
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text(
                  "Non hai un account? Registrati",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
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
