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
    final text = tester.widget<Text>(find.text('2 adresses'));
    expect(text.style?.color, cs.success);
    final icon = tester.widget<DonyIcon>(find.byType(DonyIcon));
    expect(icon.color, cs.success);
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
    final text = tester.widget<Text>(find.text('À configurer'));
    expect(text.style?.color, cs.onSurfaceVariant);
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
    final text = tester.widget<Text>(find.text('1 alerte'));
    expect(text.style?.color, AppTheme.dark().colorScheme.success);
  });

  testWidgets('nouveautés : point ambre, pas de coche, fond ambre', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ToolStatusBadge(
          ready: true,
          tone: ToolStatusTone.news,
          label: '2 nouveaux',
          semanticsLabel:
              'Mes alertes, 2 nouveaux depuis votre dernière visite',
        ),
      ),
    );

    expect(find.text('2 nouveaux'), findsOneWidget);
    expect(find.byType(DonyIcon), findsNothing);
    expect(find.byKey(const Key('tool-status-badge-dot')), findsOneWidget);
    final box = tester.widget<Container>(
      find.byKey(const Key('tool-status-badge')),
    );
    expect((box.decoration! as BoxDecoration).color, DonyColors.amberLight);
    final text = tester.widget<Text>(find.text('2 nouveaux'));
    expect(text.style?.color, DonyColors.amberDark);
  });
}
