import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Couvre les 4 messages ICU imposés par la fiche B3, pour 1, 2 et 12,
/// en français (rendu identique à l'ancien code concaténé) et en anglais.
void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('requestDetailViews', () {
    test('français', () {
      expect(fr.requestDetailViews(1), '1 vue');
      expect(fr.requestDetailViews(2), '2 vues');
      expect(fr.requestDetailViews(12), '12 vues');
    });

    test('anglais', () {
      expect(en.requestDetailViews(1), '1 view');
      expect(en.requestDetailViews(2), '2 views');
      expect(en.requestDetailViews(12), '12 views');
    });
  });

  group('requestDetailTravelersWillSee', () {
    test('français', () {
      expect(fr.requestDetailTravelersWillSee(1), '1 voyageur la verra');
      expect(fr.requestDetailTravelersWillSee(2), '2 voyageurs la verront');
      expect(fr.requestDetailTravelersWillSee(12), '12 voyageurs la verront');
    });

    test('anglais', () {
      expect(en.requestDetailTravelersWillSee(1), '1 traveler will see it');
      expect(en.requestDetailTravelersWillSee(2), '2 travelers will see it');
      expect(en.requestDetailTravelersWillSee(12), '12 travelers will see it');
    });
  });

  group('requestStatusOffers', () {
    test('français', () {
      expect(fr.requestStatusOffers(1), '1 offre');
      expect(fr.requestStatusOffers(2), '2 offres');
      expect(fr.requestStatusOffers(12), '12 offres');
    });

    test('anglais', () {
      expect(en.requestStatusOffers(1), '1 offer');
      expect(en.requestStatusOffers(2), '2 offers');
      expect(en.requestStatusOffers(12), '12 offers');
    });
  });

  group('requestStatusCandidates', () {
    test('français', () {
      expect(fr.requestStatusCandidates(1), '1 candidat');
      expect(fr.requestStatusCandidates(2), '2 candidats');
      expect(fr.requestStatusCandidates(12), '12 candidats');
    });

    test('anglais', () {
      expect(en.requestStatusCandidates(1), '1 interested traveler');
      expect(en.requestStatusCandidates(2), '2 interested travelers');
      expect(en.requestStatusCandidates(12), '12 interested travelers');
    });
  });
}
