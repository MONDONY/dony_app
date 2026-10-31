// Détail du gain du trajet (`TripGainContent`), contenu du sheet « Gain » de
// l'activité du trajet : gain estimé en grand s'il est positif, colis et
// kilos, sans bouton, FR / EN, 360 dp × 1,3. Le titre du sheet (« Gain
// estimé » ou « Résumé du trajet ») et quand la case Gain s'affiche sont
// testés par `trip_activity_sheets_test.dart` et `trip_activity_row_test.dart`.
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  Finder content() => find.byType(TripGainContent);

  testWidgets('gain positif : montant, colis, kilos, note', (tester) async {
    await pumpTripCard(tester, const TripGainContent(summary: _paid));

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
    await pumpTripCard(tester, const TripGainContent(summary: _cashOnly));

    expect(find.byKey(const Key('trip-summary-earnings')), findsNothing);
    expect(find.text('1 colis en votre possession'), findsOneWidget);
    expect(find.text('3 kg transportés'), findsOneWidget);
  });

  testWidgets('aucun bouton : lecture seule', (tester) async {
    await pumpTripCard(tester, const TripGainContent(summary: _paid));

    expect(
      find.descendant(of: content(), matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
    expect(find.byKey(const Key('trip-summary-view-parcels')), findsNothing);
  });

  testWidgets('devise du trajet (XOF)', (tester) async {
    await pumpTripCard(
      tester,
      const TripGainContent(
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
      const TripGainContent(summary: _paid),
      locale: const Locale('en'),
    );

    expect(
      find.text('Payment follows the delivery of each parcel.'),
      findsOneWidget,
    );
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
            TripGainContent(summary: summary),
            locale: locale,
            textScale: 1.3,
            size: kTripCardSmallPhone,
          );

          expect(tester.takeException(), isNull);
          expect(content(), findsOneWidget);
        });
      }
    }
  });
}
