import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = MobileMoneyProviderCatalog(
    country: 'CI',
    currency: 'XOF',
    detected: 'ORANGE_CIV',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_CIV',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave'),
      MobileMoneyProviderOption(code: 'MTN_CIV', label: 'MTN MoMo'),
    ],
  );

  Future<ValueNotifier<Set<String>>> pump(
    WidgetTester tester,
    Set<String> initial,
  ) async {
    final selection = ValueNotifier<Set<String>>(initial);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileMoneyNetworksChecklist(
            catalog: catalog,
            selection: selection,
            onChanged: (s) => selection.value = s,
          ),
        ),
      ),
    );
    return selection;
  }

  testWidgets(
    'affiche « Tous les réseaux » puis chaque opérateur avec le sous-titre du détecté',
    (tester) async {
      await pump(tester, {'ORANGE_CIV'});
      expect(find.text('Tous les réseaux'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Détecté pour ce numéro'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('MTN MoMo'), findsOneWidget);
    },
  );

  testWidgets('cocher un réseau l\'ajoute, le recocher le retire', (
    tester,
  ) async {
    final selection = await pump(tester, {'ORANGE_CIV'});
    await tester.tap(find.byKey(const Key('network-WAVE_CIV')));
    await tester.pump();
    expect(selection.value, {'ORANGE_CIV', 'WAVE_CIV'});
    await tester.tap(find.byKey(const Key('network-ORANGE_CIV')));
    await tester.pump();
    expect(selection.value, {'WAVE_CIV'});
  });

  testWidgets('« Tous les réseaux » coche tout, puis décoche tout', (
    tester,
  ) async {
    final selection = await pump(tester, {'ORANGE_CIV'});
    await tester.tap(find.byKey(const Key('network-all')));
    await tester.pump();
    expect(selection.value, {'ORANGE_CIV', 'WAVE_CIV', 'MTN_CIV'});
    await tester.tap(find.byKey(const Key('network-all')));
    await tester.pump();
    expect(selection.value, isEmpty);
  });
}
