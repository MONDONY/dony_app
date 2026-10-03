import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Le trousseau iOS refuse la lecture ou l'écriture tant que le téléphone
/// n'a pas été déverrouillé : app réveillée en arrière-plan par une
/// notification ou un appel (FLUTTER-AC). Les appelants s'en passent pour
/// cette fois : l'identifiant sera lu au prochain passage au premier plan.
class DeviceIdUnavailableException implements Exception {
  const DeviceIdUnavailableException(this.cause);

  final PlatformException cause;

  @override
  String toString() => 'DeviceIdUnavailableException(${cause.code})';
}

class DeviceIdService {
  static const _key = 'dony_device_id';

  final FlutterSecureStorage _storage;
  String? _cached;
  Future<String>? _ongoingInit;

  DeviceIdService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            // Lisible dès le premier déverrouillage après démarrage, même
            // écran verrouillé ensuite, et jamais restauré sur un autre
            // téléphone (un identifiant d'appareil ne se copie pas).
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  /// Lève [DeviceIdUnavailableException] quand le trousseau est inaccessible.
  /// Rien n'est mis en cache dans ce cas : l'appel suivant réessaie.
  Future<String> getDeviceId() {
    if (_cached != null) {
      return Future.value(_cached);
    }
    // Libéré une fois terminé, même en échec : l'appel suivant réessaie.
    return _ongoingInit ??= _init().whenComplete(() => _ongoingInit = null);
  }

  Future<String> _init() async {
    try {
      final stored = await _storage.read(key: _key);
      if (stored != null && stored.isNotEmpty) {
        _cached = stored;
        return stored;
      }
      final id = const Uuid().v4();
      await _storage.write(key: _key, value: id);
      _cached = id;
      return id;
    } on PlatformException catch (e) {
      throw DeviceIdUnavailableException(e);
    }
  }
}
