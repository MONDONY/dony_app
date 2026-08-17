import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_step_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('WizardStepIndicator', () {
    testWidgets('renders the correct number of segments (3 by default)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WizardStepIndicator(currentStep: 0)));
      await tester.pump();
      // 3 AnimatedContainers for the 3 segments
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('renders custom totalSteps', (tester) async {
      await tester.pumpWidget(
        _wrap(const WizardStepIndicator(currentStep: 0, totalSteps: 4)),
      );
      await tester.pump();
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });

    testWidgets('preferredSize returns height 24', (tester) async {
      const indicator = WizardStepIndicator(currentStep: 0);
      expect(indicator.preferredSize.height, 24);
    });

    testWidgets('currentStep 0 renders without errors', (tester) async {
      await tester.pumpWidget(_wrap(const WizardStepIndicator(currentStep: 0)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('currentStep 1 renders without errors', (tester) async {
      await tester.pumpWidget(_wrap(const WizardStepIndicator(currentStep: 1)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('currentStep 2 renders without errors', (tester) async {
      await tester.pumpWidget(_wrap(const WizardStepIndicator(currentStep: 2)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
