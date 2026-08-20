import 'package:dony/core/currency/converted_price.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String originalCurrency,
    double? convertedPricePerKg,
    String? convertedCurrency,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ConvertedPriceLabel(
            originalCurrency: originalCurrency,
            convertedPricePerKg: convertedPricePerKg,
            convertedCurrency: convertedCurrency,
          ),
        ),
      ),
    );
  }

  testWidgets('affiche l\'équivalent converti présenté comme une estimation', (
    tester,
  ) async {
    await pump(
      tester,
      originalCurrency: 'EUR',
      convertedPricePerKg: 6560,
      convertedCurrency: 'XOF',
    );

    // Le libellé annonce explicitement une estimation ("environ"), jamais
    // une formulation qui suggère un montant exact.
    expect(find.textContaining('environ'), findsOneWidget);
    expect(find.textContaining('F CFA'), findsOneWidget);
  });

  testWidgets('aucune conversion affichée quand les devises coïncident', (
    tester,
  ) async {
    await pump(
      tester,
      originalCurrency: 'EUR',
      convertedPricePerKg: 10,
      convertedCurrency: 'EUR',
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets(
    'aucune conversion affichée quand les devises coïncident (casse différente)',
    (tester) async {
      await pump(
        tester,
        originalCurrency: 'eur',
        convertedPricePerKg: 10,
        convertedCurrency: 'EUR',
      );

      expect(find.byType(Text), findsNothing);
    },
  );

  testWidgets(
    'aucune conversion affichée quand convertedPricePerKg est absent',
    (tester) async {
      await pump(tester, originalCurrency: 'EUR', convertedCurrency: 'USD');

      expect(find.byType(Text), findsNothing);
    },
  );

  testWidgets('aucune conversion affichée quand convertedCurrency est absent', (
    tester,
  ) async {
    await pump(tester, originalCurrency: 'EUR', convertedPricePerKg: 10);

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('le libellé ne promet jamais un montant réellement débité', (
    tester,
  ) async {
    await pump(
      tester,
      originalCurrency: 'EUR',
      convertedPricePerKg: 12,
      convertedCurrency: 'USD',
    );

    final textWidget = tester.widget<Text>(find.byType(Text));
    final text = textWidget.data ?? '';
    expect(text, contains('environ'));
    // Aucune formulation qui ferait croire à un montant exact facturé.
    expect(text.toLowerCase(), isNot(contains('débité')));
    expect(text.toLowerCase(), isNot(contains('payé')));
    expect(text.toLowerCase(), isNot(contains('facturé')));
  });
}
