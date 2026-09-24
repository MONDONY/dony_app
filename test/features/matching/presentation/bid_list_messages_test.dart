// Tests des messages purs (pluriels ICU + libellés de filtre) de la partie
// « Demandes reçues » : pas besoin de pomper un widget, l'ARB fait foi.
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/presentation/traveler_bids_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  group('bidListRequestsToReview — fr', () {
    final l = lookupAppLocalizations(AppL10n.fr);

    test('1 demande (singulier fr, one{})', () {
      expect(l.bidListRequestsToReview(1), '1 demande à traiter');
    });

    test('3 demandes (pluriel)', () {
      expect(l.bidListRequestsToReview(3), '3 demandes à traiter');
    });

    test('0 demande tombe dans la catégorie fr "one" (singulier)', () {
      expect(l.bidListRequestsToReview(0), '0 demande à traiter');
    });
  });

  group('bidListRequestsToReview — en', () {
    final l = lookupAppLocalizations(AppL10n.en);

    test('1 request to review', () {
      expect(l.bidListRequestsToReview(1), '1 request to review');
    });

    test('3 requests to review', () {
      expect(l.bidListRequestsToReview(3), '3 requests to review');
    });
  });

  group('bidListHiddenOffers — fr', () {
    final l = lookupAppLocalizations(AppL10n.fr);

    test('1 offre masquée (singulier fr, one{})', () {
      expect(l.bidListHiddenOffers(1), '1 offre masquée (prix minimum actif)');
    });

    test('3 offres masquées (pluriel)', () {
      expect(
        l.bidListHiddenOffers(3),
        '3 offres masquées (prix minimum actif)',
      );
    });
  });

  group('bidListHiddenOffers — en', () {
    final l = lookupAppLocalizations(AppL10n.en);

    test('1 offer hidden', () {
      expect(l.bidListHiddenOffers(1), '1 offer hidden (minimum price on)');
    });

    test('3 offers hidden', () {
      expect(l.bidListHiddenOffers(3), '3 offers hidden (minimum price on)');
    });
  });

  group('TravelerBidFilterL10n.label — fr', () {
    final l = lookupAppLocalizations(AppL10n.fr);

    test('aTraiter → À traiter', () {
      expect(TravelerBidFilter.aTraiter.label(l), 'À traiter');
    });

    test('acceptees → Acceptées', () {
      expect(TravelerBidFilter.acceptees.label(l), 'Acceptées');
    });

    test('terminees → Terminées', () {
      expect(TravelerBidFilter.terminees.label(l), 'Terminées');
    });
  });

  group(
    'tripOwnerShareMessage — non-régression (trip_owner_detail_screen.dart)',
    () {
      // Ancien code (avant migration, HEAD ca8e1754) :
      //   '✈️ Je voyage $dep → $arr le '
      //   '${DateFormat('d MMMM', AppL10n.localeName).format(date)} '
      //   'avec de la place dans mes bagages !\n'
      //   'Réserve tes kilos sur Yadony 📦\n'
      //   '$url'
      // Migré vers l.tripOwnerShareMessage(dep, arr, date, url) avec
      // date formatée en DateFormat.MMMMd(locale) — ce test fige le rendu fr
      // exactement égal à l'ancienne chaîne concaténée, et couvre le cas en.
      const dep = 'Paris';
      const arr = 'Dakar';
      final departureDate = DateTime(2026, 10, 6);
      const url = 'https://yadony.app/annonce/ann-1';

      setUpAll(() async {
        await initializeDateFormatting('fr');
        await initializeDateFormatting('en');
      });

      test('fr — égal caractère près à l\'ancienne chaîne concaténée', () {
        final l = lookupAppLocalizations(AppL10n.fr);
        final oldDate = DateFormat('d MMMM', 'fr').format(departureDate);
        final oldMessage =
            '✈️ Je voyage $dep → $arr le '
            '$oldDate '
            'avec de la place dans mes bagages !\n'
            'Réserve tes kilos sur Yadony 📦\n'
            '$url';

        final newDate = DateFormat.MMMMd('fr').format(departureDate);
        final newMessage = l.tripOwnerShareMessage(dep, arr, newDate, url);

        expect(newDate, oldDate);
        expect(newMessage, oldMessage);
        expect(
          newMessage,
          '✈️ Je voyage Paris → Dakar le 6 octobre avec de la place dans mes '
          'bagages !\nRéserve tes kilos sur Yadony 📦\n'
          'https://yadony.app/annonce/ann-1',
        );
      });

      test('en — rendu anglais', () {
        final l = lookupAppLocalizations(AppL10n.en);
        final date = DateFormat.MMMMd('en').format(departureDate);
        final message = l.tripOwnerShareMessage(dep, arr, date, url);

        expect(
          message,
          "✈️ I'm traveling Paris → Dakar on $date with room in my luggage!\n"
          'Book your kilos on Yadony 📦\n'
          'https://yadony.app/annonce/ann-1',
        );
      });
    },
  );

  group('TravelerBidFilterL10n.label — en', () {
    final l = lookupAppLocalizations(AppL10n.en);

    test('aTraiter → To review', () {
      expect(TravelerBidFilter.aTraiter.label(l), 'To review');
    });

    test('acceptees → Accepted', () {
      expect(TravelerBidFilter.acceptees.label(l), 'Accepted');
    });

    test('terminees → Completed', () {
      expect(TravelerBidFilter.terminees.label(l), 'Completed');
    });
  });
}
