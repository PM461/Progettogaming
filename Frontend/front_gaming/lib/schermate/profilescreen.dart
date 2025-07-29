import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:front_gaming/services/profile_service.dart';
import 'package:front_gaming/controllers/profile_controller.dart';

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
  final ProfileController _controller = ProfileController(ProfileService());

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

  Future<void> _loadSteamId() async {
    if (userId == null) return;
    final steamId = await _controller.loadSteamId(userId!);
    setState(() => _steamId = steamId);
  }

  Future<void> _loadCreationDate() async {
    if (userId == null) return;
    final date = await _controller.loadCreationDate(userId!);
    if (date != null) {
      setState(() => _creationDate = date);
    }
  }

  Future<void> _loadEmail() async {
    if (userId == null) return;
    final email = await _controller.loadEmail(userId!);
    if (email != null) {
      setState(() => _email = email);
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
  }

  Future<void> _loadNickname() async {
    if (userId == null) return;
    final nickname = await _controller.loadNickname(userId!);
    if (nickname != null) {
      setState(() => _nickname = nickname);
    }
  }

  Future<void> _loadProfileImage() async {
    if (userId == null) return;
    final imageName = await _controller.loadProfileImage(userId!);
    if (imageName != null) {
      setState(() => _selectedImageName = imageName);
    }
  }

  Future<void> _setProfileImage(String imageName) async {
    if (userId == null) return;

    final success = await _controller.setProfileImage(userId!, imageName);
    if (!mounted) return;

    if (success) {
      setState(() => _selectedImageName = imageName);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel salvataggio della foto')),
      );
    }
  }

  void _showImagePickerPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('profile_image');
    if (saved != null && mounted) {
      setState(() => _selectedImageName = saved);
    }
    if (!mounted) return;

    if (saved != null) {
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
      appBar: CustomAppBar(selectedImageName: _selectedImageName),
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
                                'https://my-flutter-web.onrender.com//auth/steam/login?account=$account';
                            final uri = Uri.parse(url);

                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.platformDefault,
                                webOnlyWindowName: '_blank',
                              );
                            } else {
                              // gestione errore
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
