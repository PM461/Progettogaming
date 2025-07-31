import 'dart:convert';
import 'dart:typed_data';
import 'package:front_gaming/main.dart';

import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/services/auth_service.dart';
import 'package:front_gaming/services/drag.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // Per ricevere il token da postMessage
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'ClassicalLogin.dart';
import 'MyLibrary.dart'; // Schermata di login classico
import 'package:flutter_svg/flutter_svg.dart';
import 'package:front_gaming/services/image_services.dart';
import 'search_page.dart';

class MainScreenState extends State<MainScreen> {
  late Future<String> futureName;
  List<Map<String, dynamic>> raccomandati = [];
  List<Map<String, dynamic>> nuoviSimili = [];
  int _currentIndex = 0;

  String? _selectedImageName;
  bool _hasLoadedOnce = false;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    futureName = loadName();
    _loadProfileImage();
    _loadRecommendations(); // <--- AGGIUNTA

    // Inizializza le pagine per ogni tab
    _pages.add(_buildHomeContent());
    _pages.add(const MyLibraryScreen()); // Libreria
    _pages.add(const ProfilePage()); // Profilo
  }

  Future<void> _loadRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

    if (userId == null) return;

    try {
      final res = await http.get(Uri.parse(
          '$apiBaseUrl/api/users/get-raccomandazioni?user_id=$userId')); // usa la nuova API

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final raccomandazione = data['raccomandazione'] ?? {};
        final recommendations = raccomandazione['recommendations'] ?? {};

        // Ora ogni lista è già una lista di giochi dettagliati
        raccomandati = List<Map<String, dynamic>>.from(
            recommendations['raccomandati'] ?? []);
        nuoviSimili = List<Map<String, dynamic>>.from(
            recommendations['nuovi_simili'] ?? []);

        setState(() {});
      }
    } catch (e) {
      debugPrint('Errore nel caricamento delle raccomandazioni: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGamesByIds(
      List<String> ids, String baseUrl) async {
    final List<Map<String, dynamic>> games = [];

    for (final id in ids) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/game/$id'));
        if (res.statusCode == 200) {
          games.add(jsonDecode(res.body));
        }
      } catch (_) {
        continue;
      }
    }

    return games;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (ModalRoute.of(context)?.isCurrent == true && !_hasLoadedOnce) {
      _loadProfileImage(); // solo al primo ingresso
      _hasLoadedOnce = true;
    } else if (ModalRoute.of(context)?.isCurrent == true) {
      _loadProfileImage(); // ricarica se ritorni
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? imageName = prefs.getString('profile_image');
    final userId = prefs.getString('user_id');

    if (imageName != null && imageName.isNotEmpty) {
      setState(() {
        _selectedImageName = imageName;
      });
    } else if (userId != null && userId.isNotEmpty) {
      const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/api/users/get-propic?user_id=$userId'),
        );

        if (response.statusCode == 200) {
          final index = int.tryParse(response.body);
          if (index != null && index >= 0) {
            imageName = '$index';
            await prefs.setString('profile_image', imageName);
            setState(() {
              _selectedImageName = imageName;
            });
          }
        }
      } catch (e) {
        debugPrint('Errore durante il fetch della propic: $e');
      }
    } else {
      setState(() {
        _selectedImageName = '1';
      });
    }
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

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          DraggableGameList(
            title: "🎮 Raccomandati per te",
            games: raccomandati,
          ),
          DraggableGameList(
            title: "🆕 Nuovi aggiunti simili ai tuoi gusti",
            games: nuoviSimili,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeContent(), // solo widget senza Scaffold
      const MyLibraryScreen(), // assicurati che anche qui NON ci sia Scaffold/AppBar
      const ProfilePage(), // idem come sopra
    ];

    return Scaffold(
      appBar: CustomAppBar(
          selectedImageName: _selectedImageName), // qui solo la tua AppBar
      body: pages[_currentIndex],
    );
  }
}

// Placeholder per pagina Profilo, da sostituire con la tua implementazione
class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Solo contenuto, niente Scaffold o AppBar
    return Center(child: Text('Pagina Profilo'));
  }
}
