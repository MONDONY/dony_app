import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_period_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  ShipmentPeriodBasis basis = ShipmentPeriodBasis.departure,
  ShipmentPeriodPreset preset = ShipmentPeriodPreset.all,
  DateTimeRange? range,
  void Function(ShipmentPeriodResult?)? onResult,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          final r = await ShipmentPeriodFilterSheet.show(
            context,
            basis: basis,
            preset: preset,
            range: range,
          );
          onResult?.call(r);
        },
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets('choisit un preset + bascule basis -> retourne (basis, preset)', (
    tester,
  ) async {
    ShipmentPeriodResult? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
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

  testWidgets('sélectionne preset « Cette semaine » et applique', (
    tester,
  ) async {
    ShipmentPeriodResult? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cette semaine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(result!.preset, ShipmentPeriodPreset.thisWeek);
    expect(result!.basis, ShipmentPeriodBasis.departure);
    expect(result!.range, isNull);
  });

  testWidgets('sélectionne preset « 3 derniers mois » et applique', (
    tester,
  ) async {
    ShipmentPeriodResult? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3 derniers mois'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(result!.preset, ShipmentPeriodPreset.last3Months);
  });

  testWidgets('sélectionne preset « Cette année » et applique', (tester) async {
    ShipmentPeriodResult? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cette année'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(result!.preset, ShipmentPeriodPreset.thisYear);
  });

  testWidgets('sélectionne preset « Tout » et applique', (tester) async {
    ShipmentPeriodResult? result;
    // Start with a different preset to make "Tout" a real change
    await tester.pumpWidget(
      _app(preset: ShipmentPeriodPreset.thisMonth, onResult: (r) => result = r),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(result!.preset, ShipmentPeriodPreset.all);
    expect(result!.range, isNull);
  });

  testWidgets('bascule basis departure -> creation -> departure', (
    tester,
  ) async {
    ShipmentPeriodResult? result;
    await tester.pumpWidget(_app(onResult: (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Switch to creation
    await tester.tap(find.text('Date de création'));
    await tester.pumpAndSettle();
    // Switch back to departure
    await tester.tap(find.text('Date de départ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(result!.basis, ShipmentPeriodBasis.departure);
  });

  testWidgets('les deux tabs basis sont rendus', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Date de départ'), findsOneWidget);
    expect(find.text('Date de création'), findsOneWidget);
  });

  testWidgets('preset « Ce mois-ci » est visible', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ce mois-ci'), findsOneWidget);
  });

  testWidgets(
    'sheet ouverte avec preset existant montre la pré-sélection correcte',
    (tester) async {
      ShipmentPeriodResult? result;
      await tester.pumpWidget(
        _app(
          preset: ShipmentPeriodPreset.thisYear,
          basis: ShipmentPeriodBasis.creation,
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Apply without changing anything — should return the same values
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      expect(result!.preset, ShipmentPeriodPreset.thisYear);
      expect(result!.basis, ShipmentPeriodBasis.creation);
    },
  );

  testWidgets(
    'appuyer sur un preset non-custom efface la plage personnalisée',
    (tester) async {
      final existingRange = DateTimeRange(
        start: DateTime(2026, 4),
        end: DateTime(2026, 4, 30),
      );
      ShipmentPeriodResult? result;
      await tester.pumpWidget(
        _app(
          preset: ShipmentPeriodPreset.custom,
          range: existingRange,
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap a non-custom preset
      await tester.tap(find.text('Ce mois-ci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      expect(result!.preset, ShipmentPeriodPreset.thisMonth);
      expect(result!.range, isNull);
    },
  );
}
