import 'package:dony/features/cancellation/presentation/cancellation_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('cancellationReasonLabel', () {
    test('Vol annulé — fr égal à la valeur de donnée', () {
      expect(cancellationReasonLabel(fr, 'Vol annulé'), 'Vol annulé');
    });
    test('Vol annulé — en', () {
      expect(cancellationReasonLabel(en, 'Vol annulé'), 'Flight canceled');
    });

    test('Urgence personnelle — fr égal à la valeur de donnée', () {
      expect(
        cancellationReasonLabel(fr, 'Urgence personnelle'),
        'Urgence personnelle',
      );
    });
    test('Urgence personnelle — en', () {
      expect(
        cancellationReasonLabel(en, 'Urgence personnelle'),
        'Personal emergency',
      );
    });

    test('Problème de santé — fr égal à la valeur de donnée', () {
      expect(
        cancellationReasonLabel(fr, 'Problème de santé'),
        'Problème de santé',
      );
    });
    test('Problème de santé — en', () {
      expect(cancellationReasonLabel(en, 'Problème de santé'), 'Health issue');
    });

    test("Changement d'itinéraire — fr égal à la valeur de donnée", () {
      expect(
        cancellationReasonLabel(fr, "Changement d'itinéraire"),
        "Changement d'itinéraire",
      );
    });
    test("Changement d'itinéraire — en", () {
      expect(
        cancellationReasonLabel(en, "Changement d'itinéraire"),
        'Itinerary change',
      );
    });

    test('Autre — fr égal à la valeur de donnée', () {
      expect(cancellationReasonLabel(fr, 'Autre'), 'Autre');
    });
    test('Autre — en', () {
      expect(cancellationReasonLabel(en, 'Autre'), 'Other');
    });

    test('motif inconnu (texte libre saisi) — rendu tel quel', () {
      expect(
        cancellationReasonLabel(fr, 'Mon avion a eu un problème technique'),
        'Mon avion a eu un problème technique',
      );
    });
  });

  group('cancellationTripCanceledSnackbar', () {
    test('fr (égal au code vivant d\'avant migration)', () {
      expect(fr.cancellationTripCanceledSnackbar, 'Trajet annulé');
    });
    test('en', () {
      expect(en.cancellationTripCanceledSnackbar, 'Trip canceled');
    });
  });
}
