// Gain du trajet vu par son voyageur (fonctions pures `tripGainFor` et
// `tripGainOf`) : colis récupérés seulement, en ligne et en espèces séparés,
// commission des espèces, devise du trajet, colis sans net, repli sur le
// résumé du détail quand la liste n'a pas répondu.
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_gain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_answer_harness.dart';

const _cash = BidPaymentMethod.cash;

void main() {
  group('tripGainFor', () {
    test('colis en ligne seulement (carte et mobile money)', () {
      final g = tripGainFor([
        answerBid('c', status: 'HANDED_OVER', net: 30),
        answerBid(
          'm',
          status: 'IN_TRANSIT',
          method: BidPaymentMethod.mobileMoney,
          net: 12.5,
        ),
      ], 'EUR');
      expect(g.online, 42.5);
      expect(g.cash, 0);
      expect(g.total, 42.5);
      expect(g.currency, 'EUR');
    });

    test('espèces seulement : net, brut remis et commission', () {
      final g = tripGainFor([
        answerBid('e', status: 'ARRIVED', method: _cash, net: 40, gross: 45),
      ], 'EUR');
      expect(g.online, 0);
      expect(g.cash, 40);
      expect(g.cashGross, 45);
      expect(g.cashCommission, 5);
      expect(g.total, 40);
    });

    test('espèces sans brut (ancien back) : brut = net, aucune commission', () {
      final g = tripGainFor([
        answerBid('e', status: 'ARRIVED', method: _cash, net: 40),
      ], 'EUR');
      expect(g.cashGross, 40);
      expect(g.cashCommission, 0);
    });

    test('mix en ligne et espèces : total = les deux nets', () {
      final g = tripGainFor([
        answerBid('c', status: 'IN_TRANSIT', net: 30),
        answerBid(
          'e',
          status: 'HANDED_OVER',
          method: _cash,
          net: 20,
          gross: 22,
        ),
      ], 'EUR');
      expect(g.online, 30);
      expect(g.cash, 20);
      expect(g.total, 50);
    });

    test('COMPLETED compté (et DELIVERED, son ancien nom)', () {
      final g = tripGainFor([
        answerBid('d', status: 'COMPLETED', net: 10),
        answerBid('o', status: 'DELIVERED', method: _cash, net: 5),
      ], 'EUR');
      expect(g.online, 10);
      expect(g.cash, 5);
    });

    test('pas encore récupérés : ACCEPTED, AWAITING_PAYMENT, demandes', () {
      final g = tripGainFor([
        answerBid('a', status: 'ACCEPTED', net: 10),
        answerBid('w', status: 'AWAITING_PAYMENT', net: 10),
        answerBid('p', net: 10),
        answerBid('s', status: 'PAYMENT_ESCROWED', net: 10),
        answerBid('ae', status: 'ACCEPTED', method: _cash, net: 10),
      ], 'EUR');
      expect(g.total, 0);
    });

    test(
      'clos sans livraison exclus : annulé, refusé, absent, colis refusé',
      () {
        final g = tripGainFor([
          for (final s in const [
            'CANCELLED',
            'REJECTED',
            'NO_SHOW',
            'EXPIRED',
            'PARCEL_REFUSED',
          ]) ...[
            answerBid('o-$s', status: s, net: 10),
            answerBid('e-$s', status: s, method: _cash, net: 10),
          ],
        ], 'EUR');
        expect(g.total, 0);
      },
    );

    test('colis dans une autre devise : jamais mélangé', () {
      final g = tripGainFor([
        answerBid('eur', status: 'IN_TRANSIT', net: 30),
        answerBid('xof', status: 'IN_TRANSIT', net: 20000, currency: 'XOF'),
        answerBid(
          'xofc',
          status: 'IN_TRANSIT',
          method: _cash,
          net: 5000,
          currency: 'xof',
        ),
      ], 'EUR');
      expect(g.online, 30);
      expect(g.cash, 0);
      // Devise comparée sans tenir compte de la casse.
      final xof = tripGainFor([
        answerBid('x', status: 'IN_TRANSIT', net: 20000, currency: 'xof'),
      ], 'XOF');
      expect(xof.online, 20000);
      expect(xof.currency, 'XOF');
    });

    test('colis sans net connu : ignoré', () {
      final g = tripGainFor([
        answerBid('n', status: 'IN_TRANSIT', weightKg: null),
        answerBid('nc', status: 'IN_TRANSIT', method: _cash, weightKg: null),
        answerBid('ok', status: 'IN_TRANSIT', net: 8),
      ], 'EUR');
      expect(g.online, 8);
      expect(g.cash, 0);
    });

    test('aucun colis : zéro', () {
      final g = tripGainFor(const [], 'EUR');
      expect(g.total, 0);
      expect(g.hasGain, isFalse);
    });
  });

  group('tripGainOf : colis chargés et résumé du détail', () {
    const summary = TripParcelsSummary(
      count: 1,
      totalKg: 3,
      netAmount: 25,
      currency: 'EUR',
    );

    test('liste pas chargée : en ligne = net du résumé, espèces inconnues', () {
      final g = tripGainOf(answerTrip(parcelsSummary: summary), null);
      expect(g.online, 25);
      expect(g.cash, 0);
      expect(g.hasGain, isTrue);
      expect(tripGainOf(answerTrip(), null).hasGain, isFalse);
    });

    test('liste chargée : le calcul de l\'app couvre les espèces et les '
        'colis livrés que le résumé ignore', () {
      final g = tripGainOf(answerTrip(parcelsSummary: summary), [
        answerBid('c', status: 'IN_TRANSIT', net: 25),
        answerBid('d', status: 'COMPLETED', net: 10),
        answerBid('e', status: 'HANDED_OVER', method: _cash, net: 20),
      ]);
      expect(g.online, 35);
      expect(g.cash, 20);
      expect(g.total, 55);
    });

    test('résumé au-dessus du calcul (net en ligne absent des colis) : '
        'le résumé l\'emporte pour la part en ligne', () {
      final g = tripGainOf(answerTrip(parcelsSummary: summary), [
        answerBid('c', status: 'IN_TRANSIT', weightKg: null),
        answerBid('e', status: 'HANDED_OVER', method: _cash, net: 20),
      ]);
      expect(g.online, 25);
      expect(g.cash, 20);
      expect(g.total, 45);
    });

    test('résumé dans une autre devise que le trajet : ignoré', () {
      const xof = TripParcelsSummary(
        count: 1,
        totalKg: 3,
        netAmount: 20000,
        currency: 'XOF',
      );
      expect(tripGainOf(answerTrip(parcelsSummary: xof), null).hasGain, false);
      expect(
        tripGainOf(answerTrip(parcelsSummary: xof), const []).hasGain,
        isFalse,
      );
    });

    test('devise du trajet', () {
      final g = tripGainOf(answerTrip(currency: 'XOF'), [
        answerBid('x', status: 'IN_TRANSIT', net: 20000, currency: 'XOF'),
        answerBid('e', status: 'IN_TRANSIT', net: 30),
      ]);
      expect(g.currency, 'XOF');
      expect(g.online, 20000);
    });
  });
}
