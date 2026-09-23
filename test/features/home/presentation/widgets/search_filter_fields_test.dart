// Champs de filtre partagés du composeur : libellés en français (inchangés)
// et en anglais.

import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Widget _fields() => _wrap(
  Column(
    children: [
      DatePresetsField(
        value: const HomeSearchFilters(departureCity: 'Paris'),
        onChanged: (_) {},
      ),
      PriceField(maxPrice: null, onTap: () {}),
      TransportModeField(mode: null, onTap: () {}),
      WeightField(weightKg: 6, onChanged: (_) {}),
    ],
  ),
);

void main() {
  testWidgets('en français : libellés inchangés', (tester) async {
    await tester.pumpWidget(_fields());

    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Ce mois'), findsOneWidget);
    expect(find.text('DATE PRÉCISE'), findsOneWidget);
    expect(find.text('Choisir'), findsOneWidget);
    expect(find.text('PRIX MAX'), findsOneWidget);
    expect(find.text('Tous'), findsNWidgets(2));
    expect(find.text('POIDS MIN'), findsOneWidget);
  });

  testWidgets('en anglais : libellés traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(_fields());

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('EXACT DATE'), findsOneWidget);
    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('MAX PRICE'), findsOneWidget);
    expect(find.text('Any'), findsNWidgets(2));
    expect(find.text('MIN WEIGHT'), findsOneWidget);
  });

  testWidgets('en anglais : sélecteur de poids traduit', (tester) async {
    useEnglish();
    await tester.pumpWidget(_fields());

    await tester.tap(find.text('MIN WEIGHT'));
    await tester.pumpAndSettle();

    expect(find.text('Minimum trip weight'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('en anglais : sélecteurs de prix et de transport traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () =>
                    showPricePicker(context, maxPrice: null, onApply: (_) {}),
                child: const Text('prix'),
              ),
              TextButton(
                onPressed: () =>
                    showTransportPicker(context, mode: null, onApply: (_) {}),
                child: const Text('transport'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('prix'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum price'), findsOneWidget);
    expect(find.text('Any price'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    Navigator.of(tester.element(find.text('Apply'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('transport'));
    await tester.pumpAndSettle();
    expect(find.text('Transport mode'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('DateField sans libellé affiche « DATE »', (tester) async {
    await tester.pumpWidget(_wrap(DateField(date: null, onChanged: (_) {})));

    expect(find.text('DATE'), findsOneWidget);
  });

  testWidgets('DateField garde le libellé passé par l\'appelant', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(DateField(date: null, onChanged: (_) {}, label: 'QUAND')),
    );

    expect(find.text('QUAND'), findsOneWidget);
    expect(find.text('DATE'), findsNothing);
  });

  testWidgets('en anglais : en-tête et valeur de TransportModeField', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(TransportModeField(mode: null, onTap: () {})),
    );

    expect(find.text('TRANSPORT'), findsOneWidget);
    expect(find.text('Any'), findsOneWidget);
  });
}
