import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_gaming/services/profile_service.dart';

class ProfileController {
  final ProfileService _service;
  final List<String> availableImages = List.generate(6, (i) => '$i');

  ProfileController(this._service);

  Future<String?> loadNickname(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = await _service.getNickname(userId);

    if (nickname != null && nickname.isNotEmpty) {
      await prefs.setString('nickname', nickname);
      return nickname;
    }

    return prefs.getString('nickname');
  }

  Future<String?> loadEmail(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _service.getEmail(userId);

    if (email != null && email.isNotEmpty) {
      await prefs.setString('email', email);
      return email;
    }

    return prefs.getString('email');
  }

  Future<String?> loadCreationDate(String userId) async {
    final date = await _service.getCreationDate(userId);
    return (date != null && date.isNotEmpty) ? date : null;
  }

  Future<String?> loadSteamId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final steamId = await _service.getSteamId(userId);

    if (steamId != null && steamId.isNotEmpty) {
      await prefs.setString('steam_id', steamId);
      return steamId;
    } else {
      await prefs.remove('steam_id');
      return null;
    }
  }

  Future<String?> loadProfileImage(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('profile_image');

    int? idx = await _service.getProfileImageIndex(userId);
    if (idx != null && idx >= 0 && idx < availableImages.length) {
      final name = availableImages[idx];
      await prefs.setString('profile_image', name);
      return name;
    }

    return saved;
  }

  Future<bool> setProfileImage(String userId, String imageName) async {
    final prefs = await SharedPreferences.getInstance();
    final idx = availableImages.indexOf(imageName);
    final propicUrl = '${idx + 1}.png';

    final success = await _service.setProfileImage(userId, propicUrl);
    if (success) {
      await prefs.setString('profile_image', imageName);
      return true;
    }

    return false;
  }
}
