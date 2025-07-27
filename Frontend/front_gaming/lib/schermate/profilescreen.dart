import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _selectedImageName;
  String? _nickname;
  String? _email;
  String? _creationDate;
  String? _steamId;

  final List<String> availableImages = List.generate(6, (i) => '$i');
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _loadNickname();
      _loadProfileImage();
      _loadEmail();
      _loadCreationDate();
      _loadSteamId(); // <- aggiunto
    });
  }

  Future<void> _checkSteamLoginStatus() async {
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/users/get-steamid?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final steamId = data['steam_id'] as String?;
        if (steamId != null && steamId.isNotEmpty) {
          await prefs.setString('steam_id', steamId);
          setState(() {
            _steamId = steamId;
          });
        }
      }
    } catch (e) {
      debugPrint('Errore get-steamid: $e');
    }
  }

  Future<void> _loadSteamId() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ 1. Richiesta sempre al backend
    if (userId != null) {
      try {
        final response = await http.get(
          Uri.parse('http://localhost:8000/users/get-steamid?user_id=$userId'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final steamId = data['steam_id'] as String?;

          if (steamId != null && steamId.isNotEmpty) {
            // ✅ 2. Aggiorna shared prefs e stato
            await prefs.setString('steam_id', steamId);
            setState(() => _steamId = steamId);
            return;
          } else {
            // 🟥 Se server non ha steam_id, rimuovi dalle shared
            await prefs.remove('steam_id');
            setState(() => _steamId = null);
            return;
          }
        }
      } catch (e) {
        debugPrint('Errore get-steamid: $e');
      }
    }

    // ⚠️ 3. Fallback in caso di errore di rete
    final savedSteamId = prefs.getString('steam_id');
    if (savedSteamId != null && savedSteamId.isNotEmpty) {
      setState(() => _steamId = savedSteamId);
    }
  }

  Future<void> _loadCreationDate() async {
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/users/get-data?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final date = data['data'] as String?;
        if (date != null && date.isNotEmpty) {
          setState(() => _creationDate = date);
        }
      }
    } catch (e) {
      debugPrint('Errore get-data: $e');
    }
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    if (savedEmail != null) {
      setState(() => _email = savedEmail);
    }

    if (userId != null) {
      try {
        final response = await http.get(
          Uri.parse(
              'http://localhost:8000/api/users/get-email?user_id=$userId'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final email = data['email'] as String?;
          if (email != null && email.isNotEmpty) {
            await prefs.setString('email', email);
            setState(() => _email = email);
          }
        }
      } catch (e) {
        debugPrint('Errore get-email: $e');
      }
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('nickname');
    if (saved != null) {
      setState(() => _nickname = saved);
    }

    if (userId != null) {
      try {
        _loadUserId();
        final response = await http.get(
          Uri.parse(
              'http://localhost:8000/api/users/get-nickname?user_id=$userId'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final nick = data['name'] as String?;
          if (nick != null && nick.isNotEmpty) {
            await prefs.setString('nickname', nick);
            setState(() => _nickname = nick);
          }
        }
      } catch (e) {
        debugPrint('Errore get-nickname: $e');
      }
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('profile_image');
    if (saved != null) {
      setState(() => _selectedImageName = saved);
    }

    if (userId != null) {
      try {
        final response = await http.get(
          Uri.parse(
              'http://localhost:8000/api/users/get-propic?user_id=$userId'),
        );
        if (response.statusCode == 200) {
          final idx = int.tryParse(response.body);
          if (idx != null && idx >= 0 && idx < availableImages.length) {
            final name = availableImages[idx];
            await prefs.setString('profile_image', name);
            setState(() => _selectedImageName = name);
          }
        }
      } catch (e) {
        debugPrint('Errore get-propic: $e');
      }
    }
  }

  Future<void> _setProfileImage(String imageName) async {
    final prefs = await SharedPreferences.getInstance();
    final idx = availableImages.indexOf(imageName);
    final propicUrl = '${idx + 1}.png';
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/users/set-propic?user_id=$userId&propic_url=$propicUrl'),
      );
      if (response.statusCode == 200) {
        await prefs.setString('profile_image', imageName);
        setState(() => _selectedImageName = imageName);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel salvataggio della foto')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di rete')),
      );
    }
  }

  void _showImagePickerPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('profile_image');
    if (saved != null && mounted) {
      setState(() => _selectedImageName = saved);
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seleziona immagine profilo'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: availableImages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (ctx, index) {
              final imageName = availableImages[index];
              return GestureDetector(
                onTap: () => _setProfileImage(imageName),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundImage:
                          AssetImage('images/propic/$imageName.png'),
                    ),
                    if (imageName == _selectedImageName)
                      const Positioned(
                        child: Icon(Icons.check_circle, color: Colors.green),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final imagePath = _selectedImageName != null
        ? 'images/propic/${_selectedImageName!}.png'
        : 'images/propic/1.png';

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _showImagePickerPopup,
                child: CircleAvatar(
                  radius: 60, // ridotto da 80
                  backgroundImage: AssetImage(imagePath),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _nickname ?? 'Nickname',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold), // ridotto
              ),
              const SizedBox(height: 20),
              _buildInfoRow('Email', _email ?? 'Caricamento...'),
              _buildInfoRow(
                  'Data creazione', _creationDate ?? 'Caricamento...'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: (_steamId == null || _steamId!.isEmpty)
                        ? () async {
                            final account = userId ?? '';
                            if (account.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('User ID non disponibile')),
                              );
                              return;
                            }

                            final url =
                                'http://localhost:8000/auth/steam/login?account=$account';

                            if (await canLaunch(url)) {
                              await launch(
                                url,
                                webOnlyWindowName:
                                    '_blank', // <-- importante per aprire nuova scheda
                              );

                              // Qui NON puoi chiudere la scheda da Flutter Web!
                              // Ma puoi aspettare e poi ricaricare lo steamId (vedi dopo)
                              await Future.delayed(const Duration(seconds: 5));
                              await _loadSteamId();
                            } else {
                              // errore
                            }
                          }
                        : null,
                    child: Image.asset(
                      _steamId != null && _steamId!.isNotEmpty
                          ? 'images/steam.png'
                          : 'images/steam_gray.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Informazioni su Steam'),
                      content: const Text(
                        '⚠️ Attenzione: gli obiettivi nella libreria verranno sovrascritti.\n\n'
                        'Se non dovesse funzionare, ricordati di rendere il tuo profilo Steam pubblico.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Chiudi'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Informazioni Steam'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {/* elimina profilo */},
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Elimina profilo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
