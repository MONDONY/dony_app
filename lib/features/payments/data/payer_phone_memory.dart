import 'dart:convert';

import 'package:dony/core/storage/form_draft_store.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Dernier compte mobile money utilisé pour payer : pays, opérateur et numéro.
///
/// Sert à préremplir le composant « compte qui paie » à la prochaine recharge
/// ou au prochain paiement.
class RememberedPayer extends Equatable {
  const RememberedPayer({
    required this.country,
    required this.operatorCode,
    required this.e164,
  });

  /// Code ISO 3166-1 alpha-2 (`CI`).
  final String country;

  /// Code pawaPay de l'opérateur (`ORANGE_CIV`).
  final String operatorCode;

  /// Numéro complet au format E.164 (`+2250748840856`).
  final String e164;

  Map<String, dynamic> toJson() => {
    'country': country,
    'operatorCode': operatorCode,
    'e164': e164,
  };

  /// `null` si l'un des trois champs manque ou n'est pas une chaîne.
  static RememberedPayer? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final country = json['country'];
    final operatorCode = json['operatorCode'];
    final e164 = json['e164'];
    if (country is! String || operatorCode is! String || e164 is! String) {
      return null;
    }
    return RememberedPayer(
      country: country,
      operatorCode: operatorCode,
      e164: e164,
    );
  }

  @override
  List<Object?> get props => [country, operatorCode, e164];
}

/// Mémoire du dernier compte payeur, dans le trousseau de l'appareil.
///
/// Une entrée par compte (`mm_last_payer_$uid`) : le numéro d'un compte ne
/// doit pas être proposé à un autre sur le même téléphone. Sans compte
/// connecté, ni lecture ni écriture.
///
/// Toute erreur du trousseau est avalée : perdre le préremplissage est un
/// désagrément, bloquer un paiement pour autant serait une panne.
class PayerPhoneMemory {
  PayerPhoneMemory({
    required FormDraftStorage storage,
    required String? Function() currentUid,
  }) : _storage = storage,
       _currentUid = currentUid;

  final FormDraftStorage _storage;
  final String? Function() _currentUid;

  String? _key() {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return null;
    return 'mm_last_payer_$uid';
  }

  /// Dernier compte mémorisé, ou `null` (absent, illisible, autre compte).
  Future<RememberedPayer?> read() async {
    final key = _key();
    if (key == null) return null;
    try {
      final raw = await _storage.read(key);
      if (raw == null) return null;
      return RememberedPayer.fromJson(jsonDecode(raw));
    } on Object catch (e) {
      // Jamais `$e` : une FormatException recopie la source, donc le numéro.
      debugPrint('PayerPhoneMemory.read failed: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> save(RememberedPayer payer) async {
    final key = _key();
    if (key == null) return;
    try {
      await _storage.write(key, jsonEncode(payer.toJson()));
    } on Object catch (e) {
      debugPrint('PayerPhoneMemory.save failed: ${e.runtimeType}');
    }
  }
}
