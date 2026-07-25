import 'package:dony/core/design/accessibility_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context.a11y lit les valeurs du scope', (tester) async {
    late AccessibilityScope read;
    await tester.pumpWidget(
      const AccessibilityScope(
        underlineLinks: true,
        reinforceLabels: true,
        persistentMessages: false,
        confirmImportantActions: true,
        child: SizedBox.shrink(),
      ),
    );
    final ctx = tester.element(find.byType(SizedBox));
    read = ctx.a11y;
    expect(read.underlineLinks, isTrue);
    expect(read.reinforceLabels, isTrue);
    expect(read.persistentMessages, isFalse);
    expect(read.confirmImportantActions, isTrue);
  });

  testWidgets('sans scope monté, les valeurs par défaut sont sûres',
      (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final ctx = tester.element(find.byType(SizedBox));
    expect(ctx.a11y.underlineLinks, isFalse);
    expect(ctx.a11y.reinforceLabels, isFalse);
    expect(ctx.a11y.persistentMessages, isFalse);
    expect(ctx.a11y.confirmImportantActions, isFalse);
  });

  testWidgets('un changement de valeur reconstruit les dépendants',
      (tester) async {
    var builds = 0;
    Widget wrap(bool underline) => AccessibilityScope(
          underlineLinks: underline,
          reinforceLabels: false,
          persistentMessages: false,
          confirmImportantActions: false,
          child: Builder(builder: (ctx) {
            builds++;
            return Text('${ctx.a11y.underlineLinks}',
                textDirection: TextDirection.ltr);
          }),
        );

    await tester.pumpWidget(wrap(false));
    expect(builds, 1);
    await tester.pumpWidget(wrap(true));
    expect(builds, 2);
    expect(find.text('true'), findsOneWidget);
  });
}
