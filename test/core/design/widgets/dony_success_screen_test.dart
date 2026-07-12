import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required VoidCallback onCta}) => MaterialApp(
        theme: AppTheme.light,
        home: DonySuccessScreen(
          mascotteType: DonyMascotteType.securise,
          title: 'Envoi réservé !',
          subtitle: 'Ton paiement est sécurisé.',
          ctaLabel: 'Voir mes envois',
          onCta: onCta,
        ),
      );

  testWidgets('affiche titre, sous-titre et label du CTA', (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Envoi réservé !'), findsOneWidget);
    expect(find.text('Ton paiement est sécurisé.'), findsOneWidget);
    expect(find.text('Voir mes envois'), findsOneWidget);
  });

  testWidgets('tap sur le CTA appelle onCta exactement une fois', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(host(onCta: () => callCount++));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(DonyButton));
    await tester.pump();

    expect(callCount, 1);
  });

  testWidgets('pas d\'auto-navigation : le CTA reste visible après 5 secondes',
      (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Voir mes envois'), findsOneWidget);
  });
}
