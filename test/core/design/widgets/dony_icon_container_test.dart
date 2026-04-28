import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  group('DonyIconContainer', () {
    testWidgets('sm size renders 32x32 container', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyIconContainer(icon: Icons.home, size: DonyIconContainerSize.sm),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 32.0);
    });

    testWidgets('md size renders 40x40 container (default)', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyIconContainer(icon: Icons.star),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 40.0);
    });

    testWidgets('lg size renders 56x56 container', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyIconContainer(icon: Icons.person, size: DonyIconContainerSize.lg),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 56.0);
    });

    testWidgets('xl size renders 72x72 container', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyIconContainer(icon: Icons.check, size: DonyIconContainerSize.xl),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 72.0);
    });

    testWidgets('custom colors are applied', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyIconContainer(
          icon: Icons.info,
          backgroundColor: DonyColors.infoLight,
          iconColor: DonyColors.info,
        ),
      ));
      expect(find.byType(Icon), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, DonyColors.info);
    });

    testWidgets('custom borderRadius overrides default', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyIconContainer(icon: Icons.lock, borderRadius: 8),
      ));
      expect(find.byType(Container), findsOneWidget);
    });
  });
}
