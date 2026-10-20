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

  testWidgets('layout = taille visuelle, zone tactile élargie à 44 pt', (
    tester,
  ) async {
    await tester.pumpWidget(subject(size: GpProBadgeSize.compact));
    final box = tester.getRect(find.byType(GpProBadge));
    expect(box.size, const Size(16, 16));

    // 13 pt hors du visuel : dans la zone de 44 pt, le tap ouvre la feuille.
    await tester.tapAt(box.centerLeft - const Offset(13, 0));
    await tester.pumpAndSettle();
    expect(find.text(l.gpProInfoTitle), findsOneWidget);
  });

  testWidgets('tap au-delà de 44 pt : ignoré', (tester) async {
    await tester.pumpWidget(subject(size: GpProBadgeSize.compact));
    final box = tester.getRect(find.byType(GpProBadge));
    await tester.tapAt(box.centerLeft - const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(find.text(l.gpProInfoTitle), findsNothing);
  });

  testWidgets('full : hauteur de layout inférieure à 44, zone tactile 44', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    final box = tester.getRect(find.byType(GpProBadge));
    expect(box.height, lessThan(44));
    await tester.tapAt(box.topCenter - const Offset(0, 10));
    await tester.pumpAndSettle();
    expect(find.text(l.gpProInfoTitle), findsOneWidget);
  });

  testWidgets('action tap exposée seulement si interactive', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(subject());
    expect(
      tester.getSemantics(find.bySemanticsLabel(l.gpProBadgeSemantics)),
      matchesSemantics(
        label: l.gpProBadgeSemantics,
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.pumpWidget(subject(interactive: false));
    expect(
      tester.getSemantics(find.bySemanticsLabel(l.gpProBadgeSemantics)),
      matchesSemantics(label: l.gpProBadgeSemantics),
    );
    handle.dispose();
  });

  testWidgets('pastille argent : fond gris clair, texte gris-bleu foncé', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    final box = tester.widget<Container>(
      find
          .ancestor(
            of: find.text(l.gpProBadgeLabel),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration! as BoxDecoration).color, const Color(0xFFE6EAF0));
    final text = tester.widget<Text>(find.text(l.gpProBadgeLabel));
    expect(text.style?.color, const Color(0xFF3A4556));
  });
}
