import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  group('ThreadStateBanner', () {
    testWidgets('rend l\'icône + le message + le subtitle', (tester) async {
      await tester.pumpWidget(wrap(const ThreadStateBanner(
        icon: Icons.hourglass_top_rounded,
        message: 'Le voyageur prépare son trajet',
        subtitle: 'Tu seras notifié dès qu\'il l\'aura confirmé.',
        tint: Color(0xFFB5781E),
      )));
      expect(find.text('Le voyageur prépare son trajet'), findsOneWidget);
      expect(
        find.text('Tu seras notifié dès qu\'il l\'aura confirmé.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('subtitle optionnel — pas rendu si null', (tester) async {
      await tester.pumpWidget(wrap(const ThreadStateBanner(
        icon: Icons.payments_outlined,
        message: 'En attente du paiement',
        tint: Color(0xFF5B21B6),
      )));
      expect(find.text('En attente du paiement'), findsOneWidget);
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
    });
  });
}
