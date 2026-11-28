import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_abandon_reason_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feuille « Qu'est-ce qui vous arrête ? » : une icône par raison, mêmes codes
/// rendus qu'avant, « Passer » sans raison.
void main() {
  String? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
  }) async {
    result = null;
    closed = false;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showKycAbandonReasonSheet(ctx);
                  closed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('cinq raisons, chacune avec son icône', (tester) async {
    await open(tester);

    for (final code in kycAbandonReasonCodes) {
      final row = find.byKey(Key('kyc-abandon-reason-$code'));
      expect(row, findsOneWidget, reason: code);
      expect(
        find.descendant(of: row, matching: find.byType(DonyIcon)),
        findsWidgets,
        reason: code,
      );
    }
    expect(
      find.text('Je n\'ai pas ma pièce d\'identité sous la main'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chaque ligne fait au moins 44 points de haut', (tester) async {
    await open(tester);
    for (final code in kycAbandonReasonCodes) {
      expect(
        tester.getSize(find.byKey(Key('kyc-abandon-reason-$code'))).height,
        greaterThanOrEqualTo(44),
        reason: code,
      );
    }
  });

  testWidgets('toucher une raison rend son code', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('kyc-abandon-reason-TECHNICAL')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, 'TECHNICAL');
  });

  testWidgets('« Passer » ne rend aucune raison', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('kyc-abandon-skip')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('en anglais, à 360 dp, sans débordement', (tester) async {
    await open(tester, locale: const Locale('en'));
    expect(find.text('What\'s stopping you?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
