import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pluriels ICU du domaine abonnements (follow) et de l'abonnement PRO,
/// vérifiés pour 0, 1 et 3, en français et en anglais.
///
/// `=1` est traduit par gen-l10n en `one:` (R41) : en français, la catégorie
/// « one » couvre aussi 0, d'où les accords singuliers attendus à 0 pour les
/// messages qui n'ont pas de branche `=0` dédiée.
void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('followTravelersCount', () {
    test('fr', () {
      expect(fr.followTravelersCount(0), '0 voyageur suivi');
      expect(fr.followTravelersCount(1), '1 voyageur suivi');
      expect(fr.followTravelersCount(3), '3 voyageurs suivis');
    });

    test('en', () {
      expect(en.followTravelersCount(0), 'Following 0 travelers');
      expect(en.followTravelersCount(1), 'Following 1 traveler');
      expect(en.followTravelersCount(3), 'Following 3 travelers');
    });
  });

  group('followNewSinceLastVisit', () {
    test('fr', () {
      expect(
        fr.followNewSinceLastVisit(0),
        '0 a publié depuis votre dernière visite',
      );
      expect(
        fr.followNewSinceLastVisit(1),
        '1 a publié depuis votre dernière visite',
      );
      expect(
        fr.followNewSinceLastVisit(3),
        '3 ont publié depuis votre dernière visite',
      );
    });

    test('en', () {
      expect(en.followNewSinceLastVisit(0), '0 posted since your last visit');
      expect(en.followNewSinceLastVisit(1), '1 posted since your last visit');
      expect(en.followNewSinceLastVisit(3), '3 posted since your last visit');
    });
  });

  group('followOngoingTrips (branche =0 dédiée, texte sans nombre)', () {
    test('fr', () {
      expect(fr.followOngoingTrips(0), 'Aucun trajet en cours');
      expect(fr.followOngoingTrips(1), '1 trajet en cours');
      expect(fr.followOngoingTrips(3), '3 trajets en cours');
    });

    test('en', () {
      expect(en.followOngoingTrips(0), 'No ongoing trips');
      expect(en.followOngoingTrips(1), '1 ongoing trip');
      expect(en.followOngoingTrips(3), '3 ongoing trips');
    });
  });

  group('followHubDeliveries', () {
    test('fr — « 0 livraison » au singulier, même rendu qu\'avant', () {
      expect(fr.followHubDeliveries(0), '0 livraison');
      expect(fr.followHubDeliveries(1), '1 livraison');
      expect(fr.followHubDeliveries(3), '3 livraisons');
    });

    test('en', () {
      expect(en.followHubDeliveries(0), '0 deliveries');
      expect(en.followHubDeliveries(1), '1 delivery');
      expect(en.followHubDeliveries(3), '3 deliveries');
    });
  });

  group('followHubReviewsCount (invariant en français)', () {
    test('fr', () {
      expect(fr.followHubReviewsCount(0), '0 avis');
      expect(fr.followHubReviewsCount(1), '1 avis');
      expect(fr.followHubReviewsCount(3), '3 avis');
    });

    test('en', () {
      expect(en.followHubReviewsCount(0), '0 reviews');
      expect(en.followHubReviewsCount(1), '1 review');
      expect(en.followHubReviewsCount(3), '3 reviews');
    });
  });

  group('proFreeAccessEndsInDays', () {
    test('fr — accord singulier à 1 jour', () {
      expect(
        fr.proFreeAccessEndsInDays(1),
        'Votre accès PRO gratuit prend fin dans 1 jour.',
      );
      expect(
        fr.proFreeAccessEndsInDays(3),
        'Votre accès PRO gratuit prend fin dans 3 jours.',
      );
    });

    test('en', () {
      expect(
        en.proFreeAccessEndsInDays(1),
        'Your free Pro access ends in 1 day.',
      );
      expect(
        en.proFreeAccessEndsInDays(3),
        'Your free Pro access ends in 3 days.',
      );
    });
  });
}
