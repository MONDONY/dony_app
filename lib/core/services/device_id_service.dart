import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _key = 'dony_device_id';

  final FlutterSecureStorage _storage;
  String? _cached;

  DeviceIdService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<String> getDeviceId() async {
    if (_cached != null) {
      return _cached!;
    }
    final stored = await _storage.read(key: _key);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return stored;
    }

    final id = const Uuid().v4();
    await _storage.write(key: _key, value: id);
    _cached = id;
    return id;
  }
}
