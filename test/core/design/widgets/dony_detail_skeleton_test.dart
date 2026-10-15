import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sentry FLUTTER-4M : ~450 dp de squelette dans un body de 427 dp
  // (petit écran + barre d'action) débordaient de 26 px.
  testWidgets('squelette détail : aucun débordement dans un espace réduit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(height: 300, child: DonyDetailSkeleton()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });

  // Couleurs unies (demande du propriétaire) : le squelette pulse en
  // opacité, sans reflet en dégradé.
  testWidgets('DonyShimmer pulse en opacité, sans ShaderMask', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: DonyShimmer(child: DonySkeletonBox(width: 100)),
        ),
      ),
    );
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(DonyShimmer),
        matching: find.byType(FadeTransition),
      ),
    );
    final start = fade.opacity.value;
    await tester.pump(const Duration(milliseconds: 450));
    expect(fade.opacity.value, lessThan(start));
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('DonyShimmer reste statique quand les animations sont coupées', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: DonyShimmer(child: DonySkeletonBox(width: 100)),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(DonyShimmer),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });
}
