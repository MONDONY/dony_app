// Détail du gain du trajet (`TripGainContent`), contenu du sheet « Gain » de
// l'activité du trajet : lignes « En ligne », « En espèces » et « Total
// estimé », chacune seulement si elle est positive, notes de versement et
// d'argent remis en main propre (commission non déduite), devise du trajet,
// FR / EN, 360 dp × 1,3. Le titre du sheet et quand la case Gain s'affiche
// sont testés par `trip_activity_sheets_test.dart` et
// `trip_activity_row_test.dart` ; le calcul par `trip_gain_test.dart`.
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/presentation/widgets/trip_gain_content.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_gain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'trip_card_harness.dart';

const _online = TripGain(currency: 'EUR', online: 126);
const _cash = TripGain(currency: 'EUR', cash: 40, cashGross: 45);
const _mix = TripGain(currency: 'EUR', online: 60, cash: 40, cashGross: 45);
const _cashLegacy = TripGain(currency: 'EUR', cash: 40, cashGross: 40);

String _eur(double v) => CurrencyFormatter.format(v, SupportedCurrency.eur);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  Finder content() => find.byType(TripGainContent);
  String amount(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('trip-gain-$id-amount'))).data!;

  testWidgets('en ligne seulement : ligne, note de versement, total', (
    tester,
  ) async {
    await pumpTripCard(tester, const TripGainContent(gain: _online));

    expect(find.text('En ligne'), findsOneWidget);
    expect(amount(tester, 'online'), _eur(126));
    expect(
      find.text('Versé après la livraison de chaque colis.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trip-gain-cash')), findsNothing);
    expect(find.text('Total estimé'), findsOneWidget);
    expect(amount(tester, 'total'), _eur(126));
  });

  testWidgets('espèces seulement : net, argent remis et commission avancée', (
    tester,
  ) async {
    await pumpTripCard(tester, const TripGainContent(gain: _cash));

    expect(find.byKey(const Key('trip-gain-online')), findsNothing);
    expect(find.text('En espèces'), findsOneWidget);
    expect(amount(tester, 'cash'), _eur(40));
    expect(
      tester.widget<Text>(find.byKey(const Key('trip-gain-cash-note'))).data,
      '${_eur(45)} à recevoir de l\'expéditeur en main propre, dont '
      '${_eur(5)} de frais de service avancés sur votre solde Yadony.',
    );
    expect(amount(tester, 'total'), _eur(40));
  });

  testWidgets('espèces sans brut distinct (ancien back) : note seule', (
    tester,
  ) async {
    await pumpTripCard(tester, const TripGainContent(gain: _cashLegacy));

    expect(
      find.text('À recevoir de l\'expéditeur en main propre.'),
      findsOneWidget,
    );
  });

  testWidgets('mix : trois lignes, total = en ligne + espèces', (tester) async {
    await pumpTripCard(tester, const TripGainContent(gain: _mix));

    expect(amount(tester, 'online'), _eur(60));
    expect(amount(tester, 'cash'), _eur(40));
    expect(amount(tester, 'total'), _eur(100));
    // Ordre : en ligne, espèces, total.
    final y = [
      for (final id in const ['online', 'cash', 'total'])
        tester.getTopLeft(find.byKey(Key('trip-gain-$id'))).dy,
    ];
    expect(y, orderedEquals([...y]..sort()));
  });

  testWidgets('sans gain : rien', (tester) async {
    await pumpTripCard(
      tester,
      const TripGainContent(gain: TripGain(currency: 'EUR')),
    );

    expect(find.byKey(const Key('trip-gain-total')), findsNothing);
    expect(find.text('Total estimé'), findsNothing);
  });

  testWidgets('aucun bouton : lecture seule', (tester) async {
    await pumpTripCard(tester, const TripGainContent(gain: _mix));

    expect(
      find.descendant(of: content(), matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
  });

  testWidgets('devise du trajet (XOF)', (tester) async {
    await pumpTripCard(
      tester,
      const TripGainContent(gain: TripGain(currency: 'XOF', online: 25000)),
    );

    expect(amount(tester, 'total'), contains('CFA'));
    expect(amount(tester, 'total'), isNot(contains('€')));
  });

  testWidgets('en anglais', (tester) async {
    await pumpTripCard(
      tester,
      const TripGainContent(gain: _mix),
      locale: const Locale('en'),
    );

    expect(find.text('Online'), findsOneWidget);
    expect(
      find.text('Paid out after each parcel is delivered.'),
      findsOneWidget,
    );
    expect(find.text('In cash'), findsOneWidget);
    expect(
      find.textContaining('to collect from the sender in person, including'),
      findsOneWidget,
    );
    expect(find.text('Estimated total'), findsOneWidget);
  });

  group('360 dp, texte × 1,3', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final (name, gain) in const [
        ('mix', _mix),
        (
          'XOF',
          TripGain(
            currency: 'XOF',
            online: 1250000,
            cash: 875000,
            cashGross: 950000,
          ),
        ),
      ]) {
        testWidgets('${locale.languageCode}, $name : aucun débordement', (
          tester,
        ) async {
          await pumpTripCard(
            tester,
            TripGainContent(gain: gain),
            locale: locale,
            textScale: 1.3,
            size: kTripCardSmallPhone,
          );

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('trip-gain-total')), findsOneWidget);
          for (final id in const ['online', 'cash', 'total']) {
            expect(find.byKey(Key('trip-gain-$id-amount')), findsOneWidget);
          }
        });
      }
    }
  });
}
