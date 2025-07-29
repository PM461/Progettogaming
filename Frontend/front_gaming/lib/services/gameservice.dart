import 'dart:convert';
import 'package:front_gaming/schermate/MyLibrary.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_gaming/services/gameservice.dart';

Future<List<Game>> fetchUserGames() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id');

  if (userId == null) throw Exception("ID utente non trovato");

  final url =
      Uri.parse('https://my-backend-ucgu.onrender.com/user/$userId/games');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    List gamesJson = data['games'];
    return gamesJson.map((json) => Game.fromJson(json)).toList();
  } else {
    throw Exception("Errore nel recupero dei giochi");
  }
}
