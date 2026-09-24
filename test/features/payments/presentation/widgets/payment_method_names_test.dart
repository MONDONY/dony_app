import 'package:dony/features/payments/presentation/widgets/payment_method_names.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

// Reset de debugDefaultTargetPlatformOverride EN FIN DE CORPS (pas en tearDown) :
// le binding exécute debugAssertAllFoundationVarsUnset avant les tearDowns.
void main() {
  testWidgets('iOS → Carte + Apple Pay + PayPal, pas Google Pay', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PaymentMethodNames())),
    );
    expect(find.text('Carte'), findsOneWidget);
    expect(find.text('Apple Pay'), findsOneWidget);
    expect(find.text('PayPal'), findsOneWidget);
    expect(find.text('Google Pay'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android → Carte + Google Pay + PayPal, pas Apple Pay', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PaymentMethodNames())),
    );
    expect(find.text('Carte'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('PayPal'), findsOneWidget);
    expect(find.text('Apple Pay'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('compact → une rangée de quatre logos, aucun nom, sémantique '
      'regroupée', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PaymentMethodNames(compact: true)),
      ),
    );
    expect(find.byType(SvgPicture), findsNWidgets(4));
    expect(find.byKey(const Key('payment-logo-google-pay')), findsOneWidget);
    expect(find.byKey(const Key('payment-logo-apple-pay')), findsNothing);
    expect(find.text('Carte'), findsNothing);
    expect(find.text('PayPal'), findsNothing);
    expect(find.bySemanticsLabel('Carte, Google Pay, PayPal'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('en anglais : libellé Carte traduit, semantics traduite', (
    tester,
  ) async {
    useEnglish();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PaymentMethodNames())),
    );
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('PayPal'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'clé de ligne stable, indépendante de la langue (pas dérivée du libellé traduit)',
    (tester) async {
      useEnglish();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PaymentMethodNames())),
      );
      expect(find.byKey(const Key('payment-row-card')), findsOneWidget);
      expect(find.byKey(const Key('payment-row-google-pay')), findsOneWidget);
      expect(find.byKey(const Key('payment-row-paypal')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('en anglais : mode compact, semantics regroupée traduite', (
    tester,
  ) async {
    useEnglish();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PaymentMethodNames(compact: true)),
      ),
    );
    expect(find.bySemanticsLabel('Card, Google Pay, PayPal'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
