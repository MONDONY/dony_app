import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Formulaire de publication dont la saisie peut être mise de côté.
enum FormDraftKind {
  trip('trip'),
  packageRequest('package_request');

  const FormDraftKind(this.wire);

  /// Valeur stable : clé de stockage et propriété analytics.
  final String wire;
}

/// Brouillon relu sur l'appareil : la saisie et sa date d'enregistrement.
@immutable
class StoredFormDraft {
  const StoredFormDraft({required this.data, required this.savedAt});

  /// Champs du formulaire, au format propre à chaque formulaire.
  final Map<String, dynamic> data;
  final DateTime savedAt;

  /// Étape où l'utilisateur s'était arrêté (0 = première).
  int get step => (data['step'] as num?)?.toInt() ?? 0;
}

/// Accès brut au stockage, isolé pour les tests.
abstract interface class FormDraftStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Trousseau iOS / Keystore Android. Un brouillon de trajet porte les points
/// de rendez-vous du voyageur : il ne va pas en clair dans Hive.
class SecureFormDraftStorage implements FormDraftStorage {
  SecureFormDraftStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            // Jamais restauré sur un autre téléphone : un brouillon reste
            // propre à l'appareil où il a été saisi.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Brouillons locaux des formulaires de publication (trajet, demande d'envoi).
///
/// Un brouillon par formulaire et par compte, enregistré à la demande de
/// l'utilisateur, à n'importe quelle étape. Il ne quitte jamais l'appareil :
/// le brouillon serveur (statut DRAFT) exige un formulaire complet, celui-ci
/// garde une saisie partielle.
///
/// Toute erreur du trousseau est avalée : perdre un brouillon est un
/// désagrément, bloquer la publication pour autant serait une panne.
class FormDraftStore {
  FormDraftStore({
    required FormDraftStorage storage,
    required String? Function() currentUid,
    DateTime Function()? clock,
  }) : _storage = storage,
       _currentUid = currentUid,
       _clock = clock ?? DateTime.now;

  final FormDraftStorage _storage;
  final String? Function() _currentUid;
  final DateTime Function() _clock;

  /// Au-delà, un brouillon n'est plus proposé : ses dates sont passées.
  static const maxAge = Duration(days: 30);

  static const _formatVersion = 1;

  /// Nulle sans compte connecté : le brouillon d'un compte ne doit pas être
  /// proposé à un autre sur le même téléphone.
  String? _keyFor(FormDraftKind kind) {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return null;
    return 'form_draft_${kind.wire}_$uid';
  }

  /// Brouillon en attente, ou `null` (absent, périmé, illisible).
  Future<StoredFormDraft?> read(FormDraftKind kind) async {
    final key = _keyFor(kind);
    if (key == null) return null;
    try {
      final raw = await _storage.read(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != _formatVersion ||
          decoded['data'] is! Map<String, dynamic>) {
        await _storage.delete(key);
        return null;
      }
      final savedAt = DateTime.tryParse(decoded['savedAt'] as String? ?? '');
      if (savedAt == null || _clock().difference(savedAt) > maxAge) {
        await _storage.delete(key);
        return null;
      }
      return StoredFormDraft(
        data: decoded['data'] as Map<String, dynamic>,
        savedAt: savedAt,
      );
    } on Object catch (e) {
      debugPrint('FormDraftStore.read failed: $e');
      return null;
    }
  }

  /// Remplace le brouillon de [kind]. Rend `false` si rien n'a pu être écrit.
  Future<bool> save(FormDraftKind kind, Map<String, dynamic> data) async {
    final key = _keyFor(kind);
    if (key == null) return false;
    try {
      await _storage.write(
        key,
        jsonEncode({
          'v': _formatVersion,
          'savedAt': _clock().toIso8601String(),
          'data': data,
        }),
      );
      return true;
    } on Object catch (e) {
      debugPrint('FormDraftStore.save failed: $e');
      return false;
    }
  }

  Future<void> delete(FormDraftKind kind) async {
    final key = _keyFor(kind);
    if (key == null) return;
    try {
      await _storage.delete(key);
    } on Object catch (e) {
      debugPrint('FormDraftStore.delete failed: $e');
    }
  }
}
