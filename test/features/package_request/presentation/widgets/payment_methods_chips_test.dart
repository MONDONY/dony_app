import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_methods_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget wrap(Set<PaymentMethod> methods) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: PaymentMethodsChips(methods: methods)),
  );

  testWidgets('rend un chip par moyen de paiement, ordre canonique', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const {PaymentMethod.cash, PaymentMethod.stripe}),
    );
    expect(find.text('Carte'), findsOneWidget);
    expect(find.text('Espèces'), findsOneWidget);
    expect(find.byKey(const Key('payment-method-chip-stripe')), findsOneWidget);
    expect(find.byKey(const Key('payment-method-chip-cash')), findsOneWidget);
  });

  testWidgets('anglais : moyen de paiement traduit', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap(const {PaymentMethod.cash}));
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Espèces'), findsNothing);
  });
}
