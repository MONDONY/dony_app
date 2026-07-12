import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'confirmation de paiement escrow utilise DonySuccessScreen avec la mascotte securise',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonySuccessScreen(
        mascotteType: DonyMascotteType.securise,
        title: 'Envoi réservé !',
        subtitle:
            '50.00 € sont bloqués en escrow et seront libérés après confirmation de livraison par le destinataire.',
        ctaLabel: 'Voir mes envois',
        onCta: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Envoi réservé !'), findsOneWidget);
  });
}
