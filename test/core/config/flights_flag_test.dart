import 'package:dony/core/config/flights_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setFlightsEnabled(kFlightsEnabledDefault));

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
}
