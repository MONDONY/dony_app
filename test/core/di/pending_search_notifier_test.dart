import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('intention « colis pour mes trajets »', () {
    test('absente au départ', () {
      final sut = PendingSearchNotifier();

      expect(sut.hasParcelsForMyTrips, isFalse);
      expect(sut.consumeParcelsForMyTrips(), isFalse);
    });

    test('posée : prévient les écouteurs, se lit une seule fois', () {
      final sut = PendingSearchNotifier();
      var notified = 0;
      sut.addListener(() => notified++);

      sut.setPendingParcelsForMyTrips();

      expect(notified, 1);
      expect(sut.hasParcelsForMyTrips, isTrue);
      expect(sut.consumeParcelsForMyTrips(), isTrue);
      expect(sut.hasParcelsForMyTrips, isFalse);
      expect(sut.consumeParcelsForMyTrips(), isFalse);
    });

    test('indépendante des paramètres de recherche en attente', () {
      final sut = PendingSearchNotifier()..setPendingParcelsForMyTrips();

      expect(sut.params, isNull);
      expect(sut.consume(), isNull);
      expect(sut.hasParcelsForMyTrips, isTrue);
    });
  });
}
