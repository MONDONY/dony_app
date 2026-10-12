import 'package:dony/features/flights/presentation/widgets/flight_alert_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Future<void> _open(WidgetTester tester, double? lowest) async {
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => FlightAlertSheet.show(
            context,
            currentLowest: lowest,
            currencyCode: 'EUR',
            onSubmit: (_) async => true,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

String _threshold(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('flight-alert-price')))
    .controller!
    .text;

void main() {
  testWidgets(
    'seuil proposé strictement sous le prix le plus bas : aucune alerte '
    'immédiate sur un prix déjà affiché',
    (tester) async {
      await _open(tester, 431.6);
      expect(_threshold(tester), '431');
    },
  );

  testWidgets('prix entier : seuil un cran en dessous', (tester) async {
    await _open(tester, 431);
    expect(_threshold(tester), '430');
  });

  testWidgets('sans prix connu : champ vide', (tester) async {
    await _open(tester, null);
    expect(_threshold(tester), isEmpty);
  });
}
