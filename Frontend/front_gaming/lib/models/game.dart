// lib/models/game.dart
import 'package:flutter/material.dart';

class Game {
  final String gameId;
  final String label;
  final String? logoImage;
  final List<dynamic> achievements;

  final bool isWishlist;
  final bool isCompleted;
  final bool isFavorite;
  final String? editore;
  final String? genere;
  final String? sviluppatore;
  final String? serie;
  final List<String>? piattaforma;
  final String? modalitaDiGioco;
  final String? dispositivoIngresso;
  final DateTime? dataPubblicazione;
  final List<String>? distributore;
  final String? sitoWebUfficiale;
  final String? classificazioneUSK;
  final String? idSteam;
  final String? idGOG;

  Game({
    required this.gameId,
    required this.label,
    required this.logoImage,
    required this.achievements,
    this.editore,
    this.isWishlist = false,
    this.isCompleted = false,
    this.isFavorite = false,
    this.genere,
    this.sviluppatore,
    this.serie,
    this.piattaforma,
    this.modalitaDiGioco,
    this.dispositivoIngresso,
    this.dataPubblicazione,
    this.distributore,
    this.sitoWebUfficiale,
    this.classificazioneUSK,
    this.idSteam,
    this.idGOG,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      gameId: toStringOrNull(json['game_id']) ?? 'Sconosciuto',
      label: toStringOrNull(json['label']) ?? 'Sconosciuto',
      logoImage: toStringOrNull(json['logo image']),
      achievements: json['achievements'] ?? [],
      editore: toStringOrNullList(json['editore'])?.join(', '),
      genere: toStringOrNullList(json['genere'])?.join(', '),
      sviluppatore: toStringOrNull(json['sviluppatore']),
      serie: toStringOrNull(json['serie']),
      piattaforma: toStringOrNullList(json['piattaforma']),
      modalitaDiGioco: toStringOrNullList(json['modalità_di_gioco'])?.join(', '),
      dispositivoIngresso: toStringOrNullList(json['dispositivo_di_ingresso'])?.join(', '),
      dataPubblicazione: parseDate(json['data_di_pubblicazione']),
      distributore: toStringOrNullList(json['distributore']),
      sitoWebUfficiale: toStringOrNull(json['sito_web_ufficiale']),
      classificazioneUSK: toStringOrNull(json['classificazione_USK']),
      idSteam: toStringOrNull(json['identificativo_Steam']),
      idGOG: toStringOrNull(json['identificativo_GOG.com']),
    );
  }
}

List<String>? toStringOrNullList(dynamic val) {
  if (val == null) return null;
  if (val is String) {
    return val.toLowerCase() == "n/a" ? null : [val];
  }
  if (val is List) {
    return val
        .where((e) => e != null && e.toString().toLowerCase() != "n/a")
        .map((e) => e.toString())
        .toList();
  }
  return null;
}

String? toStringOrNull(dynamic val) {
  if (val == null) return null;
  if (val is String) {
    return val.toLowerCase() == "n/a" ? null : val;
  }
  if (val is List && val.isNotEmpty) {
    return val.first.toString();
  }
  return val.toString();
}

DateTime? parseDate(dynamic val) {
  try {
    if (val == null) return null;
    if (val is String && val.isNotEmpty) return DateTime.parse(val);
    if (val is List && val.isNotEmpty) return DateTime.parse(val.first);
  } catch (e) {
    debugPrint("Errore parsing data: $val");
  }
  return null;
}
