import 'package:dony/core/currency/currency_publish_banner.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
