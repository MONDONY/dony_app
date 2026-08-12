import 'package:dony/core/design/widgets/dony_back_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(
          path: '/a',
          builder: (_, __) => Scaffold(body: child),
        ),
      ],
    ),
  );

  testWidgets('tooltip par défaut "Retour"', (tester) async {
    await tester.pumpWidget(wrap(const DonyBackCircle()));
    expect(find.byTooltip('Retour'), findsOneWidget);
  });

  testWidgets('tooltip personnalisé', (tester) async {
    await tester.pumpWidget(wrap(const DonyBackCircle(tooltip: 'Fermer')));
    expect(find.byTooltip('Fermer'), findsOneWidget);
    expect(find.byTooltip('Retour'), findsNothing);
  });

  testWidgets('tap déclenche onTap si fourni', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(DonyBackCircle(onTap: () => tapped = true)));
    await tester.tap(find.byType(DonyBackCircle));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
