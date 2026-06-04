// Step 2 widget test — custom free-text content category ("Autre…").
//
// Placed in test/features/package_request/presentation/
// per the task specification.
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockPackageRepo packageRepo;

  setUp(() {
    packageRepo = _MockPackageRepo();
  });

  Widget wrap(Widget child) => MaterialApp(
        home: BlocProvider(
          create: (_) => PackageRequestFormBloc(
            packageRepo,
            analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
          ),
          child: Scaffold(body: child),
        ),
      );

  group('Step2Details — custom free-text category', () {
    // 1. "Autre…" chip is visible
    testWidgets('shows an "Autre…" chip', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();
      expect(find.text('Autre…'), findsOneWidget);
    });

    // 2. Custom text field is NOT shown initially
    testWidgets('custom-category-input is not shown initially', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-category-input')), findsNothing);
    });

    // 3. After tapping "Autre…", the custom text field appears
    testWidgets('tapping "Autre…" reveals custom-category-input field',
        (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Autre…'));
      await tester.tap(find.text('Autre…'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-category-input')), findsOneWidget);
    });

    // 4. Typing in the custom field dispatches FormStep2CategoryChanged with
    //    the typed value (verified via the BLoC state's customCategoryLabel).
    testWidgets(
        'typing in custom field dispatches category change event and updates state',
        (tester) async {
      final bloc = PackageRequestFormBloc(
        packageRepo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(body: Step2Details()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Autre…" to show the text field
      await tester.ensureVisible(find.text('Autre…'));
      await tester.tap(find.text('Autre…'));
      await tester.pumpAndSettle();

      // Type in the custom category field
      await tester.enterText(
        find.byKey(const Key('custom-category-input')),
        'Textile brodé',
      );
      await tester.pump();

      // The BLoC state should reflect the custom category label
      expect(bloc.state.customCategoryLabel, 'Textile brodé');
    });

    // 5. Selecting a predefined chip hides the custom field
    testWidgets('selecting a predefined chip hides custom-category-input',
        (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();

      // Show the custom field
      await tester.ensureVisible(find.text('Autre…'));
      await tester.tap(find.text('Autre…'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-category-input')), findsOneWidget);

      // Tap a predefined chip (e.g. "Vêtements")
      await tester.ensureVisible(find.text('Vêtements'));
      await tester.tap(find.text('Vêtements'));
      await tester.pumpAndSettle();

      // Custom field should disappear
      expect(find.byKey(const Key('custom-category-input')), findsNothing);
    });
  });
}
