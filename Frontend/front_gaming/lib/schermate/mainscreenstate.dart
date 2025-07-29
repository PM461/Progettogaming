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
import 'search_page.dart';

class MainScreenState extends State<MainScreen> {
  late Future<String> futureName;

  String? _selectedImageName;
  bool _hasLoadedOnce = false;

  int _selectedIndex = 0; // indice selezione navbar

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    futureName = loadName();
    _loadProfileImage();

    // Inizializza le pagine per ogni tab
    _pages.add(_buildHomeContent());
    _pages.add(const MyLibraryScreen()); // Libreria
    _pages.add(const ProfilePage()); // Profilo
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
      try {
        final response = await http.get(
          Uri.parse(
              'https://my-backend-ucgu.onrender.com/api/users/get-propic?user_id=$userId'),
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        const Spacer(),
        // Non serve più bottone libreria qui perché c'è nella navbar
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 4,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                // Titolo a sinistra
                const Text(
                  'Gaming Collection',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const Spacer(),

                // Icona di ricerca al centro
                IconButton(
                  icon: const Icon(Icons.search, size: 30, color: Colors.white),
                  tooltip: 'Cerca',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SearchPage()),
                    );
                  },
                ),

                const SizedBox(width: 20),

                // Icona libreria
                IconButton(
                  icon: const Icon(Icons.library_books,
                      size: 30, color: Colors.white),
                  tooltip: 'Vai alla libreria',
                  onPressed: () {
                    Navigator.pushNamed(context, '/library');
                  },
                ),

                const SizedBox(width: 20),

                // Avatar profilo
                GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/profile');
                    _loadProfileImage();
                  },
                  child: CircleAvatar(
                    radius: 25,
                    backgroundImage: AssetImage(
                      _selectedImageName != null
                          ? 'images/propic/${_selectedImageName!}.png'
                          : 'images/propic/1.png',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Rimuoviamo vecchi contenuti nel body
      body: const SizedBox.shrink(),
    );
  }
}

// Placeholder per pagina Profilo, da sostituire con la tua implementazione
class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Pagina Profilo'),
    );
  }
}
