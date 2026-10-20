import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/mobile_money_failure_message.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_panel.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_ring.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_outcome_body.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// Panneau d'attente partagé (recharge et paiement d'un colis) : anneau,
/// consigne selon l'opérateur, récapitulatif et bouton d'ouverture de
/// l'opérateur. L'anneau tourne : jamais de `pumpAndSettle()`.
class _MockLauncher extends Mock implements ExternalUrlLauncher {}

void main() {
  final fixedNow = DateTime.utc(2026, 10, 19, 10);

  Widget panel({
    MobileMoneyValidationHint hint = MobileMoneyValidationHint.generic,
    String? authorizationUrl,
    String? providerLabel,
    List<({String label, String value})>? recap,
  }) => localizedApp(
    Scaffold(
      body: MobileMoneyAwaitingPanel(
        expiresAt: fixedNow.add(const Duration(minutes: 15)),
        hint: hint,
        msisdnMasked: '+225 07 •• •• 56',
        recap:
            recap ??
            const [
              (label: 'Montant', value: '5 000 F CFA'),
              (label: 'Depuis', value: 'Orange Money ••56'),
              (label: 'Versé au voyageur', value: 'Séquestre'),
            ],
        authorizationUrl: authorizationUrl,
        providerLabel: providerLabel,
        now: () => fixedNow,
      ),
    ),
  );

  testWidgets('panel_smsLinkHint_texts', (tester) async {
    await tester.pumpWidget(panel(hint: MobileMoneyValidationHint.smsLink));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SMS envoyé au +225 07 •• •• 56'), findsOneWidget);
    expect(
      find.text('Ouvrez-le et cliquez sur le lien pour valider le paiement.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-money-awaiting-ring')), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
  });

  testWidgets('panel_pinPromptHint_texts', (tester) async {
    await tester.pumpWidget(panel(hint: MobileMoneyValidationHint.pinPrompt));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Demande envoyée au +225 07 •• •• 56'), findsOneWidget);
    expect(
      find.text(
        "Une fenêtre s'affiche sur votre téléphone : validez avec votre code secret.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('panel_genericHint_texts', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Demande envoyée au +225 07 •• •• 56'), findsOneWidget);
    expect(
      find.text(
        'Validez le paiement sur votre téléphone (SMS ou fenêtre de votre opérateur).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('panel_recap_rowsSeparatedByDividers', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Montant'), findsOneWidget);
    expect(find.text('5 000 F CFA'), findsOneWidget);
    expect(find.text('Versé au voyageur'), findsOneWidget);
    expect(find.byType(DonyInfoRow), findsNWidgets(5));
  });

  testWidgets('panel_noAuthorizationUrl_noOpenButton', (tester) async {
    await tester.pumpWidget(panel(providerLabel: 'Orange Money'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('mobile-money-awaiting-open-authorization')),
      findsNothing,
    );
  });

  testWidgets('panel_authorizationUrl_showsOpenButton', (tester) async {
    registerFallbackValue(Uri.parse('https://example.com'));
    final launcher = _MockLauncher();
    when(() => launcher.open(any())).thenAnswer((_) async => true);
    if (getIt.isRegistered<ExternalUrlLauncher>()) {
      getIt.unregister<ExternalUrlLauncher>();
    }
    getIt.registerSingleton<ExternalUrlLauncher>(launcher);
    addTearDown(() => getIt.unregister<ExternalUrlLauncher>());

    await tester.pumpWidget(
      panel(
        authorizationUrl: 'https://pay.example.com/auth',
        providerLabel: 'Orange Money',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final button = find.byKey(
      const Key('mobile-money-awaiting-open-authorization'),
    );
    expect(button, findsOneWidget);
    expect(find.text('Ouvrir Orange Money'), findsOneWidget);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    verify(
      () => launcher.open(Uri.parse('https://pay.example.com/auth')),
    ).called(1);
  });

  testWidgets('panel_ring_utiliseLHorlogeInjectee', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));

    final ring = tester.widget<MobileMoneyAwaitingRing>(
      find.byType(MobileMoneyAwaitingRing),
    );
    expect(ring.now(), fixedNow);
  });

  group('MobileMoneyOutcomeBody', () {
    testWidgets('titre et message', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          const Scaffold(
            body: MobileMoneyOutcomeBody(
              iconAsset: 'clock',
              warning: true,
              title: 'Titre',
              message: 'Message',
            ),
          ),
        ),
      );

      expect(find.text('Titre'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('sans titre', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          const Scaffold(
            body: MobileMoneyOutcomeBody(
              iconAsset: 'circle-alert',
              message: 'Seulement un message',
            ),
          ),
        ),
      );

      expect(find.text('Seulement un message'), findsOneWidget);
    });
  });

  test('failureMessage_knownCode_unknownCodeFallback_nullFallback', () {
    final l = lookupAppLocalizations(const Locale('fr'));

    // Code connu : le texte de l'app l'emporte sur le repli.
    expect(
      mobileMoneyFailureMessage(l, code: 'expired', fallback: 'motif du back'),
      "La demande a expiré avant d'être validée.",
    );
    // Code inconnu : le motif déjà traduit par le back.
    expect(
      mobileMoneyFailureMessage(l, code: 'nouveau-code', fallback: 'motif'),
      'motif',
    );
    // Code absent : idem.
    expect(mobileMoneyFailureMessage(l, fallback: 'motif'), 'motif');
    // Ni code connu ni repli : message générique.
    expect(
      mobileMoneyFailureMessage(l, code: 'nouveau-code'),
      "Le paiement a été refusé par l'opérateur.",
    );
    expect(
      mobileMoneyFailureMessage(l),
      "Le paiement a été refusé par l'opérateur.",
    );
  });
}
