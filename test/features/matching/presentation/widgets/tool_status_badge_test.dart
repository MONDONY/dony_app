import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('prêt : coche, libellé, couleurs success du thème', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ToolStatusBadge(
          ready: true,
          label: '2 adresses',
          semanticsLabel: 'Mes adresses, prêt, 2 adresses',
        ),
      ),
    );

    expect(find.text('2 adresses'), findsOneWidget);
    expect(find.byType(DonyIcon), findsOneWidget);
    expect(
      find.bySemanticsLabel('Mes adresses, prêt, 2 adresses'),
      findsOneWidget,
    );
    final cs = AppTheme.light().colorScheme;
    final box = tester.widget<Container>(
      find.byKey(const Key('tool-status-badge')),
    );
    expect((box.decoration! as BoxDecoration).color, cs.successLight);
  });

  testWidgets('pas prêt : « À configurer », sans icône, fond neutre', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ToolStatusBadge(
          ready: false,
          label: 'À configurer',
          semanticsLabel: 'Mes alertes, à configurer',
        ),
      ),
    );

    expect(find.text('À configurer'), findsOneWidget);
    expect(find.byType(DonyIcon), findsNothing);
    final cs = AppTheme.light().colorScheme;
    final box = tester.widget<Container>(
      find.byKey(const Key('tool-status-badge')),
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      cs.surfaceContainerHighest,
    );
  });

  testWidgets('en sombre, le fond success vient bien du thème sombre', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ToolStatusBadge(
          ready: true,
          label: '1 alerte',
          semanticsLabel: 'Mes alertes, prêt, 1 alerte',
        ),
        theme: AppTheme.dark(),
      ),
    );

    final box = tester.widget<Container>(
      find.byKey(const Key('tool-status-badge')),
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      AppTheme.dark().colorScheme.successLight,
    );
  });
}
