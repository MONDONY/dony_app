import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_expiration_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hidden when status is valid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommissionCardExpirationBanner(
            status: ExpirationStatus.valid,
            formattedExpiry: '12/2028',
          ),
        ),
      ),
    );
    expect(find.byType(Container), findsNothing);
  });

  testWidgets('shows amber warning when expires soon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommissionCardExpirationBanner(
            status: ExpirationStatus.expiresSoon,
            formattedExpiry: '01/2025',
          ),
        ),
      ),
    );
    expect(find.textContaining('01/2025'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'triangle-alert',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows red error when expired', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommissionCardExpirationBanner(
            status: ExpirationStatus.expired,
            formattedExpiry: '01/2024',
          ),
        ),
      ),
    );
    expect(find.textContaining('expiré'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'circle-alert'),
      findsOneWidget,
    );
  });
}
