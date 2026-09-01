import 'package:dony/features/subscriptions/presentation/widgets/subscription_recency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 1, 12);

  String label(Duration ago) =>
      subscriptionRecencyLabel(now.subtract(ago), now: now);

  test('moins d\'une minute → à l\'instant', () {
    expect(label(const Duration(seconds: 20)), "à l'instant");
  });

  test('minutes puis heures', () {
    expect(label(const Duration(minutes: 5)), 'il y a 5 min');
    expect(label(const Duration(minutes: 59)), 'il y a 59 min');
    expect(label(const Duration(hours: 2)), 'il y a 2 h');
    expect(label(const Duration(hours: 23)), 'il y a 23 h');
  });

  test('hier, puis jours', () {
    expect(label(const Duration(days: 1)), 'hier');
    expect(label(const Duration(days: 3)), 'il y a 3 j');
  });

  test('au-delà d\'une semaine → date courte', () {
    expect(label(const Duration(days: 20)), '12 août');
  });

  test('date future → à l\'instant plutôt qu\'une durée négative', () {
    // Arrive quand l'horloge du téléphone retarde sur celle du serveur.
    expect(
      subscriptionRecencyLabel(now.add(const Duration(minutes: 3)), now: now),
      "à l'instant",
    );
  });

  group('date de départ', () {
    String depart(DateTime d) => subscriptionDepartureLabel(d, now: now);

    test('départ proche → jour et mois, sans année', () {
      expect(depart(DateTime(2026, 9, 27)), '27 sept.');
      expect(depart(DateTime(2027, 8, 30)), '30 août');
    });

    test('départ au-delà de douze mois → année ajoutée', () {
      // Sans l'année, « 3 janv. » pour un départ en 2028 serait trompeur.
      expect(depart(DateTime(2028, 1, 3)), '3 janv. 2028');
    });

    test('départ passé → affiché tel quel, sans année', () {
      expect(depart(DateTime(2026, 7, 4)), '4 juil.');
    });
  });
}
