import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/presentation/widgets/parsed_recap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _fields = [
  RecognizedField(field: 'departureCity', value: 'Lyon'),
  RecognizedField(field: 'maxPricePerKg', value: '8'),
];

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
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
