import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders masked number and expiry date', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommissionCardPreview(
            card: const CommissionMethod(
              brand: 'visa',
              last4: '4242',
              expMonth: 3,
              expYear: 2027,
              expirationStatus: ExpirationStatus.valid,
            ),
          ),
        ),
      ),
    );
    expect(find.text('•••• •••• •••• 4242'), findsOneWidget);
    expect(find.text('Expire le 03/2027'), findsOneWidget);
  });

  testWidgets('shows brand indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommissionCardPreview(
            card: const CommissionMethod(
              brand: 'mastercard',
              last4: '1234',
              expMonth: 12,
              expYear: 2028,
              expirationStatus: ExpirationStatus.valid,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('brand-logo-mastercard')), findsOneWidget);
  });
}
