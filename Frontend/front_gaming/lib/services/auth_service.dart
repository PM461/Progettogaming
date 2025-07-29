import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:html' as html; // solo per Flutter Web
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://my-backend-ucgu.onrender.com';

  // Login classico
  static Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password.trim()}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Response data: $data');
      final token = data['access_token'];
      final userId = data['user_id']; // ⬅️ Prendi l'id

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_id', userId); // ⬅️ Salva l'id

      return true;
    } else {
      return false;
    }
  }

  // Funzione aggiornata per salvare token e user_id da /api/auth/me
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);

    // Recupera user_id dal token (endpoint /auth/me)
    final userId = await _fetchUserIdFromToken(token);
    if (userId != null) {
      await prefs.setString('user_id', userId);
    } else {
      // Facoltativo: gestisci il caso in cui non si ottiene user_id
      print('Warning: user_id non trovato da /auth/me');
    }
  }

  // Chiamata per ottenere user_id usando il token
  static Future<String?> _fetchUserIdFromToken(String token) async {
    final url = Uri.parse('$baseUrl/api/auth/me');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['_id'] != null) {
          return data['_id'].toString();
        }
      }
    } catch (e) {
      print('Errore fetch user_id da token: $e');
    }
    return null;
  }

  // Login Google con popup e ascolto messaggi
  static Future<bool> googleLogin() async {
    const redirectBase = "https://my-backend-ucgu.onrender.com"; // Cambia se serve
    const loginUrl = "$redirectBase/auth/google/login";

    final completer = Completer<bool>();

    // Apri popup
    final popup = html.window.open(loginUrl, "Google Login", "width=500,height=600");

    // Listener messaggi
    late html.EventListener listener;
    listener = (event) async {
      final data = (event as html.MessageEvent).data;

      if (data is String && data.contains("access_token")) {
        final token = Uri.parse("http://dummy?$data").queryParameters["access_token"];
        if (token != null) {
          await saveToken(token);

          popup.close();

          // Rimuove il listener dopo aver ricevuto token
          html.window.removeEventListener('message', listener);

          completer.complete(true);
        } else {
          completer.complete(false);
        }
      }
    };

    html.window.addEventListener('message', listener);

    // Timeout di 2 minuti (opzionale)
    Future.delayed(const Duration(minutes: 2), () {
      if (!completer.isCompleted) {
        html.window.removeEventListener('message', listener);
        popup.close();
        completer.complete(false);
      }
    });

    return completer.future;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id'); // Rimuovi anche user_id al logout
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token != null;
  }
}
