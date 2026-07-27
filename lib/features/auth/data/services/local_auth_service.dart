import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthService {
  static const _pinKey = 'dony_pin_v2'; // v1 → v2 : hashed+salted
  static const _pinKeyLegacy =
      'dony_pin_v1'; // legacy plaintext, migré au 1er login

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();

  Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    if (pin != null && pin.isNotEmpty) return true;
    // Compatibilité : si un PIN v1 (plaintext) existe encore, l'utilisateur en a un.
    // Il sera migré automatiquement vers v2 au premier validatePin réussi.
    final legacy = await _storage.read(key: _pinKeyLegacy);
    return legacy != null && legacy.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    final salt = base64Url.encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await _storage.write(key: _pinKey, value: '$salt:$hash');
    // Si un ancien PIN v1 traînait, le supprimer.
    await _storage.delete(key: _pinKeyLegacy);
  }

  Future<bool> validatePin(String pin) async {
    // Tentative format v2 (hashed+salted)
    final stored = await _storage.read(key: _pinKey);
    if (stored != null && stored.contains(':')) {
      final parts = stored.split(':');
      if (parts.length >= 2) {
        final salt = parts[0];
        final expectedHash = parts.sublist(1).join(':');
        final actualHash = sha256.convert(utf8.encode('$salt:$pin')).toString();
        if (_constantTimeEquals(actualHash, expectedHash)) return true;
      }
    }

    // Fallback v1 (plaintext) : migration transparente vers v2.
    final legacy = await _storage.read(key: _pinKeyLegacy);
    if (legacy != null && _constantTimeEquals(legacy, pin)) {
      await savePin(pin); // re-stocke en v2 (savePin supprime aussi v1)
      return true;
    }

    return false;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinKeyLegacy);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        return false;
      }
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Déverrouillez Yadony pour accéder à votre compte',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
