import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugins.flutter.io/local_auth');
const _storage = FlutterSecureStorage();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Map<String, Object? Function(MethodCall)> answers;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    calls = [];
    answers = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          final answer = answers[call.method];
          return answer?.call(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('PIN', () {
    test('aucun PIN par défaut', () async {
      expect(await LocalAuthService().isPinSet(), isFalse);
    });

    test('savePin stocke un hash salé, jamais le PIN en clair', () async {
      final service = LocalAuthService();
      await service.savePin('1234');

      final stored = await _storage.read(key: 'dony_pin_v2');
      expect(stored, isNotNull);
      final parts = stored!.split(':');
      expect(parts, hasLength(2));
      // Aucun segment n'est le PIN. Pas de `contains('1234')` sur la chaîne
      // entière : le sel et le hash hexadécimal aléatoires contiennent parfois
      // « 1234 » par hasard (test rouge en CI le 13/10).
      expect(parts, isNot(contains('1234')));
      expect(
        parts[1],
        sha256.convert(utf8.encode('${parts[0]}:1234')).toString(),
      );
      expect(await service.isPinSet(), isTrue);
    });

    test('validatePin accepte le bon PIN et refuse les autres', () async {
      final service = LocalAuthService();
      await service.savePin('2580');
      expect(await service.validatePin('2580'), isTrue);
      expect(await service.validatePin('0000'), isFalse);
      expect(await service.validatePin('25801'), isFalse);
    });

    test('un PIN v1 en clair compte comme défini', () async {
      FlutterSecureStorage.setMockInitialValues({'dony_pin_v1': '1111'});
      expect(await LocalAuthService().isPinSet(), isTrue);
    });

    test('un PIN v1 vide ne compte pas', () async {
      FlutterSecureStorage.setMockInitialValues({
        'dony_pin_v2': '',
        'dony_pin_v1': '',
      });
      expect(await LocalAuthService().isPinSet(), isFalse);
    });

    test('validatePin migre un PIN v1 vers v2 et supprime v1', () async {
      FlutterSecureStorage.setMockInitialValues({'dony_pin_v1': '1111'});
      final service = LocalAuthService();

      expect(await service.validatePin('9999'), isFalse);
      expect(await _storage.read(key: 'dony_pin_v1'), '1111');

      expect(await service.validatePin('1111'), isTrue);
      expect(await _storage.read(key: 'dony_pin_v1'), isNull);
      final v2 = await _storage.read(key: 'dony_pin_v2');
      expect(v2, contains(':'));
      expect(await service.validatePin('1111'), isTrue);
    });

    test('un v2 sans séparateur retombe sur le v1', () async {
      FlutterSecureStorage.setMockInitialValues({'dony_pin_v2': 'corrompu'});
      expect(await LocalAuthService().validatePin('corrompu'), isFalse);
    });

    test('clearPin efface v1 et v2', () async {
      FlutterSecureStorage.setMockInitialValues({
        'dony_pin_v1': '1',
        'dony_pin_v2': 'a:b',
      });
      final service = LocalAuthService();
      await service.clearPin();
      expect(await _storage.readAll(), isEmpty);
      expect(await service.isPinSet(), isFalse);
    });
  });

  group('biométrie', () {
    test(
      'disponible si supportée et au moins une biométrie inscrite',
      () async {
        answers['getAvailableBiometrics'] = (_) => ['face'];
        answers['isDeviceSupported'] = (_) => true;
        expect(await LocalAuthService().isBiometricAvailable(), isTrue);
      },
    );

    test('indisponible si l’appareil n’est pas supporté', () async {
      answers['getAvailableBiometrics'] = (_) => ['fingerprint'];
      answers['isDeviceSupported'] = (_) => false;
      expect(await LocalAuthService().isBiometricAvailable(), isFalse);
    });

    test('indisponible avec seulement la sentinelle « undefined »', () async {
      answers['getAvailableBiometrics'] = (_) => ['undefined'];
      answers['isDeviceSupported'] = (_) => true;
      expect(await LocalAuthService().isBiometricAvailable(), isFalse);
    });

    test('indisponible si le canal plante', () async {
      answers['getAvailableBiometrics'] = (_) =>
          throw PlatformException(code: 'boom');
      expect(await LocalAuthService().isBiometricAvailable(), isFalse);
    });

    test('authenticateWithBiometric exige la biométrie seule', () async {
      answers['authenticate'] = (_) => true;
      expect(await LocalAuthService().authenticateWithBiometric(), isTrue);
      final args = calls.single.arguments as Map;
      expect(args['biometricOnly'], isTrue);
      expect(args['stickyAuth'], isTrue);
      expect(args['localizedReason'], isNotEmpty);
    });

    test('authenticateWithBiometric rend false sur erreur', () async {
      answers['authenticate'] = (_) => throw PlatformException(code: 'Lock');
      expect(await LocalAuthService().authenticateWithBiometric(), isFalse);
    });
  });
}
