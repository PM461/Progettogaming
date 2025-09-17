import 'dart:convert';
import 'dart:typed_data';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/schermate/profilescreen.dart';
import 'package:front_gaming/schermate/splashscreen.dart';
import 'package:front_gaming/services/notifications_center.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Avvio polling notifiche (idempotente)
  NotificationsCenter.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  @override
  Widget build(BuildContext context) {
    // === BRAND COLORI ===
    const primary = Color(0xFF0E91DD); // azzurro usato finora
    const accent = Color(0xFFEE3FD0); // fucsia usato finora
    const bg = Color(0xFF1A1A1A); // background scuro

    final brandGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, accent],
    );

    return MaterialApp(
      title: 'Ludos', // 👈 nuovo nome
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: accent,
          background: bg,
          surface: Color(0xFF232323),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 0, 0, 0), // header trasparente
          elevation: 0,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFBEBEBE),
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            color: Color.fromARGB(179, 255, 255, 255),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C1C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF5D5D5D)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: accent, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: const TextStyle(color: accent),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF222222),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
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
    const primary = Color(0xFF0E91DD);
    const accent = Color(0xFFEE3FD0);

    final brandGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, accent],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(
          children: [
            // LOGO HEADER
            Image.asset(
              'images/logoestesow.png', // 👈 assicurati di averlo in assets
              height: 36,
            ),
            const SizedBox(width: 12),

            const Spacer(),
            // Azioni rapide header
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Login classico'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                await AuthService.googleLogin();
                if (!mounted) return;
                Navigator.pushNamed(context, '/splash');
              },
              child: const Text('Accedi con Google'),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // BACKGROUND con GRADIENT + bagliori
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF141414), Color(0xFF0B0B0B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // “glow” diagonale brand
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withOpacity(0.25),
                      Colors.transparent,
                      accent.withOpacity(0.25),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // HERO
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 120, bottom: 40),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1200), // opzionale (desktop)
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo grande
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: ClipRRect(
                        child: Image.asset(
                          'images/logoestesow.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Titolo hero
                    Text(
                      'Benvenuto su Ludos',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    // Sottotitolo
                    Text(
                      'La tua libreria videoludica, obiettivi, ore di gioco e community — tutto in un unico posto.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 28),
                    // CTA

                    const SizedBox(height: 48),
                    // Sezione featurette
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: const [
                        _FeatureCard(
                          icon: Icons.library_books,
                          title: 'Crea la tua Collezione',
                          desc:
                              'Cataloga i tuoi giochi, crea wishlist e collezioni personali.',
                        ),
                        _FeatureCard(
                          icon: Icons.emoji_events_outlined,
                          title: 'Monitora i tuoi progressi',
                          desc:
                              'Cercavi un o strumento per tener traccia di Obiettivi e progressi? Ludos fa al caso tuo!',
                        ),
                        _FeatureCard(
                          icon: Icons.people_alt_outlined,
                          title: 'Community',
                          desc:
                              'Scopri cosa giocano gli amici e confrontati con loro.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0E91DD);
    const accent = Color(0xFFEE3FD0);
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [primary, accent]),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureCard(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                )),
                    const SizedBox(height: 6),
                    Text(desc, style: Theme.of(context).textTheme.bodyMedium),
                  ],
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
