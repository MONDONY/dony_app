import 'package:dony/core/services/camera_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.yadony.yadony/permissions');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answerWith(Future<Object?>? Function(MethodCall call)? handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('CameraPermissionService sur Android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('accorde quand le système accorde', () async {
      var asked = 0;
      answerWith((call) async {
        expect(call.method, 'requestCamera');
        asked++;
        return true;
      });

      expect(await const CameraPermissionService().request(), isTrue);
      expect(asked, 1);
    });

    test('refuse quand le système refuse', () async {
      answerWith((_) async => false);
      expect(await const CameraPermissionService().request(), isFalse);
    });

    // Un canal muet renvoie `null`. Le traiter comme un accord laisserait la
    // page Stripe croire qu'elle a la caméra alors que rien ne l'a autorisée.
    test('refuse quand le canal ne répond rien', () async {
      answerWith((_) async => null);
      expect(await const CameraPermissionService().request(), isFalse);
    });

    test('refuse quand le canal lève une PlatformException', () async {
      answerWith((_) async => throw PlatformException(code: 'boom'));
      expect(await const CameraPermissionService().request(), isFalse);
    });

    test('refuse quand le pont natif est absent du binaire', () async {
      answerWith(null);
      expect(await const CameraPermissionService().request(), isFalse);
    });
  });

  group('CameraPermissionService hors Android', () {
    // WKWebView demande lui-même l'autorisation depuis NSCameraUsageDescription :
    // court-circuiter évite d'inventer un canal qui n'existe pas côté iOS.
    test('court-circuite sans toucher au canal natif', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var touched = false;
      answerWith((_) async {
        touched = true;
        return false;
      });

      expect(await const CameraPermissionService().request(), isTrue);
      expect(touched, isFalse);
    });
  });
}
