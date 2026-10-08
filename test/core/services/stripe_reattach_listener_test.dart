import 'package:dony/core/services/stripe_reattach_listener.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(StripeReattachListener.channelName);
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Simule l'appel envoyé par StripeActivityReattachPlugin (Kotlin).
  Future<void> nativeCalls(String method) async {
    await messenger.handlePlatformMessage(
      StripeReattachListener.channelName,
      codec.encodeMethodCall(MethodCall(method)),
      (_) {},
    );
  }

  tearDown(() {
    channel.setMethodCallHandler(null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('StripeReattachListener sur Android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('réinitialise Stripe quand l\'activité est rattachée', () async {
      var reinits = 0;
      StripeReattachListener(reinitialize: () async => reinits++).start();

      await nativeCalls(StripeReattachListener.reattachedMethod);
      expect(reinits, 1);

      // Chaque recréation suivante relance la réinitialisation.
      await nativeCalls(StripeReattachListener.reattachedMethod);
      expect(reinits, 2);
    });

    test('ignore les autres méthodes du canal', () async {
      var reinits = 0;
      StripeReattachListener(reinitialize: () async => reinits++).start();

      await nativeCalls('somethingElse');
      expect(reinits, 0);
    });

    test('un échec de réinitialisation est signalé sans planter', () async {
      Object? reported;
      StripeReattachListener(
        reinitialize: () async => throw StateError('boom'),
        onError: (error, _) => reported = error,
      ).start();

      await nativeCalls(StripeReattachListener.reattachedMethod);
      expect(reported, isA<StateError>());
    });

    test('stop() débranche l\'écoute', () async {
      var reinits = 0;
      StripeReattachListener(reinitialize: () async => reinits++)
        ..start()
        ..stop();

      await nativeCalls(StripeReattachListener.reattachedMethod);
      expect(reinits, 0);
    });
  });

  test('ne branche rien hors Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var reinits = 0;
    StripeReattachListener(reinitialize: () async => reinits++).start();

    await nativeCalls(StripeReattachListener.reattachedMethod);
    expect(reinits, 0);
  });
}
