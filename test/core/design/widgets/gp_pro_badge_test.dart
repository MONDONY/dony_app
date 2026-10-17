import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  final l = lookupAppLocalizations(AppL10n.fr);

  Widget subject({
    GpProBadgeSize size = GpProBadgeSize.full,
    bool interactive = true,
  }) => localizedApp(
    Scaffold(
      body: Center(
        child: GpProBadge(
          size: size,
          surface: 'chat',
          interactive: interactive,
        ),
      ),
    ),
  );

  bool isLuggage(Widget w) => w is DonyIcon && w.name == 'luggage';

  testWidgets('full affiche le libellé et l\'icône', (tester) async {
    await tester.pumpWidget(subject());
    expect(find.text(l.gpProBadgeLabel), findsOneWidget);
    expect(find.byWidgetPredicate(isLuggage), findsOneWidget);
  });

  testWidgets('compact : icône seule, sémantique exposée', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(subject(size: GpProBadgeSize.compact));
    expect(find.text(l.gpProBadgeLabel), findsNothing);
    expect(find.byWidgetPredicate(isLuggage), findsOneWidget);
    expect(find.bySemanticsLabel(l.gpProBadgeSemantics), findsOneWidget);
    handle.dispose();
  });

  testWidgets('le tap ouvre la feuille d\'explication', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byType(GpProBadge));
    await tester.pumpAndSettle();
    expect(find.text(l.gpProInfoTitle), findsOneWidget);
    expect(find.text(l.gpProInfoBody), findsOneWidget);
  });

  testWidgets('interactive: false ignore le tap', (tester) async {
    await tester.pumpWidget(subject(interactive: false));
    await tester.tap(find.byType(GpProBadge));
    await tester.pumpAndSettle();
    expect(find.text(l.gpProInfoTitle), findsNothing);
  });

  testWidgets('zone tactile >= 44x44 en full et compact', (tester) async {
    await tester.pumpWidget(subject());
    final full = tester.getSize(find.byType(GpProBadge));
    expect(full.height, greaterThanOrEqualTo(44));
    expect(full.width, greaterThanOrEqualTo(44));

    await tester.pumpWidget(subject(size: GpProBadgeSize.compact));
    final compact = tester.getSize(find.byType(GpProBadge));
    expect(compact.height, greaterThanOrEqualTo(44));
    expect(compact.width, greaterThanOrEqualTo(44));
  });
}
