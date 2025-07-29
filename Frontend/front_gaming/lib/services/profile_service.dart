import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  final String baseUrl;

  ProfileService({this.baseUrl = 'https://my-backend-ucgu.onrender.com'});

  Future<String?> getNickname(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/users/get-nickname?user_id=$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['name'] as String?;
      }
    } catch (e) {
      debugPrint('Errore get-nickname: $e');
    }
    return null;
  }

  Future<String?> getEmail(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/users/get-email?user_id=$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['email'] as String?;
      }
    } catch (e) {
      debugPrint('Errore get-email: $e');
    }
    return null;
  }

  Future<String?> getCreationDate(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/users/get-data?user_id=$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as String?;
      }
    } catch (e) {
      debugPrint('Errore get-data: $e');
    }
    return null;
  }

  Future<String?> getSteamId(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/users/get-steamid?user_id=$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['steam_id'] as String?;
      }
    } catch (e) {
      debugPrint('Errore get-steamid: $e');
    }
    return null;
  }

  Future<int?> getProfileImageIndex(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/users/get-propic?user_id=$userId'));
      if (response.statusCode == 200) {
        return int.tryParse(response.body);
      }
    } catch (e) {
      debugPrint('Errore get-propic: $e');
    }
    return null;
  }

  Future<bool> setProfileImage(String userId, String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(
          '$baseUrl/api/users/set-propic?user_id=$userId&propic_url=$imageUrl'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Errore set-propic: $e');
      return false;
    }
  }

  static Future<String> getProfileImageName() async {
    final prefs = await SharedPreferences.getInstance();
    String? imageName = prefs.getString('profile_image');
    final userId = prefs.getString('user_id');

    if (imageName != null && imageName.isNotEmpty) {
      return imageName;
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
            return imageName;
          }
        }
      } catch (e) {
        // Gestisci eventuali errori
      }
    }

    // Valore di default se nulla trovato
    return '1';
  }
}
