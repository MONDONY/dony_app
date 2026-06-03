import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_period_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('choisit un preset + bascule basis -> retourne (basis, preset)',
      (tester) async {
    ShipmentPeriodResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ShipmentPeriodFilterSheet.show(
                context,
                basis: ShipmentPeriodBasis.departure,
                preset: ShipmentPeriodPreset.all,
                range: null,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrer par période'), findsOneWidget);
    await tester.tap(find.text('Ce mois-ci'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date de création'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(result!.preset, ShipmentPeriodPreset.thisMonth);
    expect(result!.basis, ShipmentPeriodBasis.creation);
  });
}
