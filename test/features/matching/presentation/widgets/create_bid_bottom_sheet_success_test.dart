import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `_presentPaymentSheet` in `create_bid_bottom_sheet.dart` pops the sheet
/// then pushes this exact `DonySuccessScreen` config once
/// `DonyPaymentSheet.show(...).onSuccess` fires — see
/// `create_bid_screen_success_test.dart` for the same contract on the
/// full-screen bid form. Driving the real `onSuccess` callback end-to-end
/// requires a native Apple/Google Pay platform channel (crashes in the test
/// harness) or a full Stripe card-entry flow, so this is a focused contract
/// test on the widget the callback constructs.
void main() {
  testWidgets(
      'paiement de bid (bottom sheet) confirmé utilise DonySuccessScreen '
      'avec la mascotte securise', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonySuccessScreen(
        mascotteType: DonyMascotteType.securise,
        title: 'Offre payée !',
        subtitle: 'Le voyageur va être notifié de ta demande.',
        ctaLabel: 'Voir mon envoi',
        onCta: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Offre payée !'), findsOneWidget);
    expect(find.text('Voir mon envoi'), findsOneWidget);
  });
}
