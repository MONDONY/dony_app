import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _host({
  Widget? primary,
  VoidCallback? onSkip,
  bool skipEnabled = true,
}) => localizedApp(
  Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AuthFlowActions(
        primary: primary,
        onSkip: onSkip,
        skipEnabled: skipEnabled,
      ),
    ),
  ),
);

void main() {
  const continueKey = Key('continue');

  testWidgets('« Continuer » est tout en bas, « Passer » est un bouton bordé '
      'juste au-dessus', (tester) async {
    await tester.pumpWidget(
      _host(
        primary: DonyButton(
          key: continueKey,
          label: 'Continuer',
          onPressed: () {},
        ),
        onSkip: () {},
      ),
    );

    final skip = find.widgetWithText(DonyButton, "Passer pour l'instant");
    expect(skip, findsOneWidget);
    expect(
      tester.widget<DonyButton>(skip).variant,
      DonyButtonVariant.secondary,
    );
    expect(tester.getSize(skip).height, greaterThanOrEqualTo(44));
    expect(
      tester.getBottomLeft(find.byKey(continueKey)).dy,
      greaterThan(tester.getBottomLeft(skip).dy),
      reason: '« Continuer » sous « Passer », au plus près du pouce',
    );
  });

  testWidgets('sans « Passer », « Continuer » reste en bas sans trou', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        primary: DonyButton(
          key: continueKey,
          label: 'Continuer',
          onPressed: () {},
        ),
      ),
    );

    expect(find.text("Passer pour l'instant"), findsNothing);
    final screen = tester.getSize(find.byType(Scaffold)).height;
    expect(tester.getBottomLeft(find.byKey(continueKey)).dy, screen);
  });

  testWidgets('« Passer » seul (écran sans action principale) touche et '
      'appelle onSkip', (tester) async {
    var skipped = 0;
    await tester.pumpWidget(_host(onSkip: () => skipped++));

    await tester.tap(find.text("Passer pour l'instant"));
    expect(skipped, 1);
  });

  testWidgets(
    'pendant un enregistrement, « Passer » reste visible mais inerte',
    (tester) async {
      var skipped = 0;
      await tester.pumpWidget(
        _host(onSkip: () => skipped++, skipEnabled: false),
      );

      expect(find.text("Passer pour l'instant"), findsOneWidget);
      await tester.tap(find.text("Passer pour l'instant"), warnIfMissed: false);
      expect(skipped, 0);
    },
  );
}
