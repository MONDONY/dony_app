import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/presentation/widgets/parsed_recap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _fields = [
  RecognizedField(field: 'departureCity', value: 'Lyon'),
  RecognizedField(field: 'maxPricePerKg', value: '8'),
];

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('date comprise : écrite comme le champ PÉRIODE', () {
    testWidgets('« en mars » : toute la période, pas la date ISO', (
      tester,
    ) async {
      // L'an prochain : l'année s'affiche quelle que soit la date du test.
      final next = DateTime.now().year + 1;
      await tester.pumpWidget(
        _wrap(
          ParsedRecapCard([
            RecognizedField(field: 'departureDateFrom', value: '$next-03-01'),
            RecognizedField(field: 'departureDateTo', value: '$next-03-31'),
          ]),
        ),
      );

      expect(find.text('Quand : 1 mars → 31 mars $next'), findsOneWidget);
      expect(find.textContaining('$next-03'), findsNothing);
    });

    testWidgets('un seul jour (bornes égales)', (tester) async {
      final year = DateTime.now().year;
      await tester.pumpWidget(
        _wrap(
          ParsedRecapCard([
            RecognizedField(field: 'departureDateFrom', value: '$year-11-12'),
            RecognizedField(field: 'departureDateTo', value: '$year-11-12'),
          ]),
        ),
      );

      expect(find.text('Quand : 12 nov.'), findsOneWidget);
    });

    testWidgets('en anglais', (tester) async {
      useEnglish();
      final next = DateTime.now().year + 1;
      await tester.pumpWidget(
        _wrap(
          ParsedRecapCard([
            RecognizedField(field: 'departureDateFrom', value: '$next-03-01'),
            RecognizedField(field: 'departureDateTo', value: '$next-03-31'),
          ]),
        ),
      );

      expect(find.text('When: Mar 1 → Mar 31, $next'), findsOneWidget);
    });
  });

  testWidgets('en français : titre et lignes « libellé : valeur »', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ParsedRecapCard(_fields)));

    expect(find.text('RÉGLÉ DEPUIS VOTRE PHRASE'), findsOneWidget);
    expect(find.text('Départ : Lyon'), findsOneWidget);
    expect(find.text('Prix maximum : 8'), findsOneWidget);
  });

  testWidgets(
    'en anglais : titre et lignes sans espace avant les deux-points',
    (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(const ParsedRecapCard(_fields)));

      expect(find.text('SET FROM YOUR SENTENCE'), findsOneWidget);
      expect(find.text('Departure: Lyon'), findsOneWidget);
      expect(find.text('Maximum price: 8'), findsOneWidget);
    },
  );

  testWidgets('un champ au nom inconnu n\'est pas affiché', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ParsedRecapCard([
          RecognizedField(field: 'somethingNew', value: 'x'),
        ]),
      ),
    );

    expect(find.text('RÉGLÉ DEPUIS VOTRE PHRASE'), findsNothing);
    expect(find.textContaining('x'), findsNothing);
  });

  testWidgets('les cinq champs connus ont chacun leur libellé', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ParsedRecapCard([
          RecognizedField(field: 'arrivalCity', value: 'Bamako'),
          RecognizedField(field: 'departureCity', value: 'Paris'),
          RecognizedField(field: 'departureDateFrom', value: 'mars'),
          RecognizedField(field: 'minAvailableKg', value: '20'),
          RecognizedField(field: 'maxPricePerKg', value: '6'),
        ]),
      ),
    );

    expect(find.text('Arrivée : Bamako'), findsOneWidget);
    expect(find.text('Départ : Paris'), findsOneWidget);
    expect(find.text('Quand : mars'), findsOneWidget);
    expect(find.text('Poids minimum : 20'), findsOneWidget);
    expect(find.text('Prix maximum : 6'), findsOneWidget);
  });
}
