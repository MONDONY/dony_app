import 'package:dony/core/config/pro_flag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setProEnabled(kProEnabledDefault));

  test('defaults to false (masqué) tant que le backend n\'a pas répondu', () {
    expect(proEnabledListenable.value, kProEnabledDefault);
    // Repli sûr : une offre fermée ne doit jamais apparaître par accident.
    expect(kProEnabledDefault, isFalse);
  });

  test('setProEnabled met à jour le flag et notifie les listeners', () {
    var notified = false;
    proEnabledListenable.addListener(() => notified = true);

    setProEnabled(true);

    expect(proEnabledListenable.value, isTrue);
    expect(notified, isTrue);
  });

  test(
    'jamais ouvert sur iOS, même si le serveur l\'active (App Store 3.1.1)',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      setProEnabled(true);

      expect(proEnabledListenable.value, isFalse);
    },
  );
}
