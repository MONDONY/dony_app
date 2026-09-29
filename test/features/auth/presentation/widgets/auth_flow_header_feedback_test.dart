import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// `AuthFlowHeader` coiffe les écrans d'inscription et d'onboarding (téléphone,
/// code, e-mail, pays, infos personnelles, parrainage, consentement, statut
/// d'identité) : le scarabée y est posé une fois pour tous.
void main() {
  Widget host(Widget header) =>
      localizedApp(Scaffold(body: SafeArea(child: header)));

  testWidgets('pastille pré-compte : scarabée présent', (tester) async {
    await tester.pumpWidget(
      host(const AuthFlowHeader(current: 1, total: 3, label: 'Téléphone')),
    );
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
  });

  testWidgets('jauge d\'onboarding : scarabée présent', (tester) async {
    await tester.pumpWidget(
      host(const AuthFlowHeader.gauge(segments: [], label: 'Pays')),
    );
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
  });

  testWidgets('showFeedback: false sous un DonyAppBar : pas de doublon', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AuthFlowHeader.gauge(
          segments: [],
          label: 'Paiements',
          showFeedback: false,
        ),
      ),
    );
    expect(find.byType(DonyFeedbackButton), findsNothing);
  });
}
