import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/currency_switch_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

/// FLUTTER-GK : confirmation avant de basculer la devise du voyage.
void main() {
  Future<bool?> Function() open(WidgetTester tester, SupportedCurrency target) {
    bool? result;
    var done = false;
    return () async {
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await CurrencySwitchConfirmSheet.show(
                    context,
                    target: target,
                  );
                  done = true;
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return done ? result : null;
    };
  }

  testWidgets('XOF : message avec la perte de la carte, Confirmer → true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await CurrencySwitchConfirmSheet.show(
                    context,
                    target: SupportedCurrency.xof,
                  ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Publier en F CFA ?'), findsOneWidget);
    expect(
      find.text(
        'Tous les prix du voyage passent en F CFA et le paiement par carte '
        'ne sera plus proposé.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('currency-switch-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Annuler → false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await CurrencySwitchConfirmSheet.show(
                    context,
                    target: SupportedCurrency.xof,
                  ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency-switch-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('devise avec carte : pas de mention de la carte', (tester) async {
    await open(tester, SupportedCurrency.eur)();
    expect(find.text('Tous les prix du voyage passent en €.'), findsOneWidget);
  });

  testWidgets('anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => CurrencySwitchConfirmSheet.show(
                context,
                target: SupportedCurrency.xof,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'All prices on this trip switch to F CFA and card payment will no '
        'longer be offered.',
      ),
      findsOneWidget,
    );
  });
}
