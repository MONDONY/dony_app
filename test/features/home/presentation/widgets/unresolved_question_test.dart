import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/presentation/widgets/unresolved_question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap(UnresolvedItem item) =>
    MaterialApp(home: Scaffold(body: UnresolvedQuestion(item)));

const _cityUnknown = UnresolvedItem(
  kind: UnresolvedKind.cityUnknown,
  phrase: 'Bamak',
  options: ['Bamako', 'Dakar'],
);

const _dateVague = UnresolvedItem(
  kind: UnresolvedKind.dateVague,
  phrase: 'bientôt',
  options: [],
);

void main() {
  testWidgets('en français : question de ville et villes proposées', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_cityUnknown));

    expect(find.text('Vers quelle ville ?'), findsOneWidget);
    expect(find.text('Bamako'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
  });

  testWidgets('en français : options de date', (tester) async {
    await tester.pumpWidget(_wrap(_dateVague));

    expect(find.text('Quand voulez-vous partir ?'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Ce mois'), findsOneWidget);
    expect(find.text('Peu importe'), findsOneWidget);
  });

  testWidgets('en français : question de prix', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UnresolvedItem(
          kind: UnresolvedKind.priceVague,
          phrase: 'pas trop cher',
          options: [],
        ),
      ),
    );

    expect(find.text('« pas trop cher », c\'est combien ?'), findsOneWidget);
    expect(find.text('Peu importe le prix'), findsOneWidget);
    expect(find.textContaining('Jusqu\'à '), findsWidgets);
  });

  testWidgets('en anglais : question de ville inconnue', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap(_cityUnknown));

    expect(find.text('To which city?'), findsOneWidget);
  });

  testWidgets('en anglais : ville ambiguë et options de date', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        const UnresolvedItem(
          kind: UnresolvedKind.cityAmbiguous,
          phrase: 'Saint',
          options: ['Saint-Louis'],
        ),
      ),
    );
    expect(find.text('Which city exactly?'), findsOneWidget);

    await tester.pumpWidget(_wrap(_dateVague));
    expect(find.text('When do you want to leave?'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Any time'), findsOneWidget);
  });

  testWidgets('en anglais : question de prix', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        const UnresolvedItem(
          kind: UnresolvedKind.priceVague,
          phrase: 'not too expensive',
          options: [],
        ),
      ),
    );

    expect(find.text('“not too expensive”: how much?'), findsOneWidget);
    expect(find.text('Any price'), findsOneWidget);
    expect(find.textContaining('Up to '), findsWidgets);
  });
}
