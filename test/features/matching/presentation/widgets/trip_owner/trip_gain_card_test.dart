// Carte « argent » du trajet (`TripSummaryCard`) : quand elle s'affiche,
// gain estimé en grand s'il est positif, colis et kilos, sans bouton (la
// liste des colis s'ouvre depuis la carte Colis), FR / EN, 360 dp × 1,3.
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'trip_card_harness.dart';

const _paid = TripParcelsSummary(
  count: 3,
  totalKg: 12.5,
  netAmount: 126,
  currency: 'EUR',
);
const _cashOnly = TripParcelsSummary(
  count: 1,
  totalKg: 3,
  netAmount: 0,
  currency: 'EUR',
);

AnnouncementModel _trip(String status, TripParcelsSummary? summary) =>
    AnnouncementModel(
      id: 'trip-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 11, 12),
      availableKg: 20,
      totalKg: 20,
      status: status,
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
      parcelsSummary: summary,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  Finder card() => find.byKey(const Key('trip-summary-card'));

  group('affichage (conditions inchangées)', () {
    const statuses = [
      'DRAFT',
      'ACTIVE',
      'FULL',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED',
      'REMOVED_BY_ADMIN',
      'SOMETHING_NEW',
    ];
    for (final status in statuses) {
      test('$status : propriétaire et résumé servi → carte', () {
        expect(
          TripSummaryCard.shownFor(isOwner: true, trip: _trip(status, _paid)),
          isTrue,
        );
      });
    }

    test('sans résumé, résumé à 0 colis ou visiteur : pas de carte', () {
      expect(
        TripSummaryCard.shownFor(isOwner: true, trip: _trip('ACTIVE', null)),
        isFalse,
      );
      expect(
        TripSummaryCard.shownFor(
          isOwner: true,
          trip: _trip(
            'ACTIVE',
            const TripParcelsSummary(
              count: 0,
              totalKg: 0,
              netAmount: 0,
              currency: 'EUR',
            ),
          ),
        ),
        isFalse,
      );
      expect(
        TripSummaryCard.shownFor(isOwner: false, trip: _trip('ACTIVE', _paid)),
        isFalse,
      );
    });
  });

  testWidgets('gain positif : « Gain estimé », montant, colis, kilos, note', (
    tester,
  ) async {
    await pumpTripCard(tester, const TripSummaryCard(summary: _paid));

    expect(find.text('Gain estimé'), findsOneWidget);
    expect(find.text('Résumé du trajet'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('trip-summary-earnings'))).data,
      contains('126'),
    );
    expect(find.text('3 colis en votre possession'), findsOneWidget);
    expect(find.text('12,5 kg transportés'), findsOneWidget);
    expect(
      find.text('Le paiement suit la livraison de chaque colis.'),
      findsOneWidget,
    );
  });

  testWidgets('colis payés en espèces (gain nul) : résumé sans montant', (
    tester,
  ) async {
    await pumpTripCard(tester, const TripSummaryCard(summary: _cashOnly));

    expect(find.text('Résumé du trajet'), findsOneWidget);
    expect(find.text('Gain estimé'), findsNothing);
    expect(find.byKey(const Key('trip-summary-earnings')), findsNothing);
    expect(find.text('1 colis en votre possession'), findsOneWidget);
    expect(find.text('3 kg transportés'), findsOneWidget);
  });

  testWidgets('aucun bouton : « Voir mes colis » a disparu', (tester) async {
    await pumpTripCard(tester, const TripSummaryCard(summary: _paid));

    expect(
      find.descendant(of: card(), matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
    expect(find.byKey(const Key('trip-summary-view-parcels')), findsNothing);
  });

  testWidgets('devise du trajet (XOF)', (tester) async {
    await pumpTripCard(
      tester,
      const TripSummaryCard(
        summary: TripParcelsSummary(
          count: 2,
          totalKg: 5,
          netAmount: 25000,
          currency: 'XOF',
        ),
      ),
    );

    final amount = tester
        .widget<Text>(find.byKey(const Key('trip-summary-earnings')))
        .data!;
    expect(amount, contains('CFA'));
    expect(amount, isNot(contains('€')));
  });

  testWidgets('en anglais', (tester) async {
    await pumpTripCard(
      tester,
      const TripSummaryCard(summary: _paid),
      locale: const Locale('en'),
    );

    expect(find.text('Estimated earnings'), findsOneWidget);
    expect(find.text('3 parcels in your possession'), findsOneWidget);
    expect(find.text('12.5 kg carried'), findsOneWidget);
  });

  group('360 dp, texte × 1,3', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final summary in const [_paid, _cashOnly]) {
        testWidgets('${locale.languageCode}, gain ${summary.netAmount} : '
            'aucun débordement', (tester) async {
          await pumpTripCard(
            tester,
            TripSummaryCard(summary: summary),
            locale: locale,
            textScale: 1.3,
            size: kTripCardSmallPhone,
          );

          expect(tester.takeException(), isNull);
          expect(card(), findsOneWidget);
        });
      }
    }
  });
}
