import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(AccessibilityState state) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: A11yPreviewCard(state: state)),
);

void main() {
  testWidgets('affiche un exemple de trajet', (tester) async {
    await tester.pumpWidget(wrap(const AccessibilityState()));
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Aperçu'), findsOneWidget);
  });

  testWidgets('le facteur de taille agrandit le texte de l\'aperçu', (
    tester,
  ) async {
    Size sizeOf(WidgetTester t) => t.getSize(find.text('Paris'));

    await tester.pumpWidget(
      wrap(
        const AccessibilityState(
          followSystemTextScale: false,
          textScaleFactor: 1.0,
        ),
      ),
    );
    final small = sizeOf(tester);

    await tester.pumpWidget(
      wrap(
        const AccessibilityState(
          followSystemTextScale: false,
          textScaleFactor: 2.0,
        ),
      ),
    );
    await tester.pump();
    final big = sizeOf(tester);

    expect(big.height, greaterThan(small.height));
  });

  testWidgets('le contraste élevé change la couleur du texte de l\'aperçu', (
    tester,
  ) async {
    Color colorOf(WidgetTester t) =>
        t.widget<Text>(find.text('Paris')).style?.color ?? Colors.transparent;

    await tester.pumpWidget(wrap(const AccessibilityState()));
    final normal = colorOf(tester);

    await tester.pumpWidget(
      wrap(const AccessibilityState(highContrast: AccessibilityMode.on)),
    );
    await tester.pump();
    expect(colorOf(tester), isNot(normal));
  });

  testWidgets('l\'aperçu affiche un badge de statut', (tester) async {
    await tester.pumpWidget(wrap(const AccessibilityState()));
    expect(find.textContaining('Urgent'), findsOneWidget);
  });
}
