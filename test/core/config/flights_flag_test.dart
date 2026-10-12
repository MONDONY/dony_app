import 'dart:async';

import 'package:dony/core/config/flights_flag.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(resetFlightsFlagForTest);

  test('éteint par défaut : rien ne change pour les utilisateurs', () {
    expect(kFlightsEnabledDefault, isFalse);
    expect(flightsEnabledListenable.value, isFalse);
  });

  test(
    'suit la valeur chargée depuis le backend et prévient les écouteurs',
    () {
      var notified = 0;
      void listener() => notified++;
      flightsEnabledListenable.addListener(listener);
      addTearDown(() => flightsEnabledListenable.removeListener(listener));

      setFlightsEnabled(true);

      expect(flightsEnabledListenable.value, isTrue);
      expect(notified, 1);
    },
  );

  test('une route ouverte au démarrage attend la réponse du flag', () async {
    final resolved = flightsEnabledResolved();
    setFlightsEnabled(true);
    markFlightsFlagLoaded();

    expect(await resolved, isTrue);
  });

  test('sans réponse, rend le repli au bout de kFlightsFlagWait', () {
    fakeAsync((async) {
      bool? value;
      unawaited(flightsEnabledResolved().then((v) => value = v));

      async.elapse(kFlightsFlagWait - const Duration(milliseconds: 1));
      expect(value, isNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(value, isFalse);
    });
  });
}
