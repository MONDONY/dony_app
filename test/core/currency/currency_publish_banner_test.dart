import 'package:dony/core/currency/currency_publish_banner.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('cache absent : ne prétend pas publier en EUR', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: CurrencyPublishBanner(currency: null)),
      ),
    );

    expect(find.text('Devise à confirmer'), findsOneWidget);
    expect(find.textContaining('Publié en Euro'), findsNothing);
  });

  testWidgets('devise connue : annonce la publication dans cette devise', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: CurrencyPublishBanner(currency: SupportedCurrency.eur),
        ),
      ),
    );

    expect(find.textContaining('Publié en Euro'), findsOneWidget);
  });

  testWidgets('en : sans devise en cache', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: CurrencyPublishBanner(currency: null)),
      ),
    );

    expect(find.text('Currency to confirm'), findsOneWidget);
  });

  testWidgets('en : devise connue', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: CurrencyPublishBanner(currency: SupportedCurrency.eur),
        ),
      ),
    );

    expect(find.textContaining('Posted in Euro'), findsOneWidget);
  });
}
