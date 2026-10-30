import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// `AuthFlowHeader` coiffe les écrans d'inscription (téléphone, code, e-mail,
/// « Faisons connaissance », pays) : le scarabée y est posé une fois pour
/// tous.
void main() {
  Widget host(Widget header) =>
      localizedApp(Scaffold(body: SafeArea(child: header)));

  testWidgets('pastille pré-compte : scarabée présent', (tester) async {
    await tester.pumpWidget(
      host(const AuthFlowHeader(current: 1, total: 3, label: 'Téléphone')),
    );
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
  });

  testWidgets('en-tête simple : logo et scarabée, sans pastille', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AuthFlowHeader.plain()));
    expect(find.byType(DonyLogo), findsOneWidget);
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
    expect(find.byType(DonyStepPill), findsNothing);
  });
}
