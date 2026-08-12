import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {bool reinforce = false, bool persistent = false}) =>
    MaterialApp(
      theme: AppTheme.light(),
      home: AccessibilityScope(
        underlineLinks: false,
        reinforceLabels: reinforce,
        persistentMessages: persistent,
        confirmImportantActions: false,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUp(DonySnackbar.clearDedup);

  group('DonyUrgentBadge', () {
    testWidgets('sans renforcement, affiche le libellé court', (tester) async {
      await tester.pumpWidget(wrap(const DonyUrgentBadge()));
      expect(find.textContaining('Urgent'), findsOneWidget);
      expect(find.textContaining('Départ imminent'), findsNothing);
    });

    testWidgets('avec renforcement, explicite le statut', (tester) async {
      await tester.pumpWidget(wrap(const DonyUrgentBadge(), reinforce: true));
      expect(find.textContaining('Départ imminent'), findsOneWidget);
    });
  });

  group('DonyBadge', () {
    testWidgets('avec renforcement, un badge sans icône en reçoit une', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DonyBadge(label: 'Payé', type: DonyBadgeType.success),
          reinforce: true,
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('sans renforcement, un badge sans icône n\'en reçoit pas', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const DonyBadge(label: 'Payé', type: DonyBadgeType.success)),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('une icône explicite n\'est jamais remplacée', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DonyBadge(
            label: 'Payé',
            type: DonyBadgeType.success,
            icon: Icons.star,
          ),
          reinforce: true,
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  group('DonySnackbar', () {
    testWidgets('sans option, la durée reste de 4 secondes', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      DonySnackbar.show(ctx, message: 'Bonjour');
      await tester.pump();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 4));
    });

    testWidgets('avec messages persistants, la durée est longue et fermable', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
          persistent: true,
        ),
      );
      DonySnackbar.show(ctx, message: 'Bonjour');
      await tester.pump();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration.inMinutes, greaterThanOrEqualTo(1));
      expect(find.text('Fermer'), findsOneWidget);
    });
  });
}
