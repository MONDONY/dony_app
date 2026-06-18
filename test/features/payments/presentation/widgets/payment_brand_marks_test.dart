import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dony/features/payments/presentation/widgets/payment_brand_marks.dart';

void main() {
  testWidgets('iOS → carte + Apple Pay + PayPal, pas Google Pay', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PaymentBrandMarks())));
    expect(find.byKey(const Key('payment-mark-card')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-apple-pay')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-paypal')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-google-pay')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android → carte + Google Pay + PayPal, pas Apple Pay', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PaymentBrandMarks())));
    expect(find.byKey(const Key('payment-mark-card')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-google-pay')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-paypal')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-apple-pay')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
