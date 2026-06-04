// Step 3 widget test — budget total + net preview + negotiable toggle + payment methods.
//
// Placed in test/features/package_request/presentation/
// per the task specification.
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockPackageRepo packageRepo;

  setUp(() {
    packageRepo = _MockPackageRepo();
  });

  Widget wrap(Widget child, {PackageRequestFormState? initialState}) {
    final bloc = PackageRequestFormBloc(packageRepo);
    if (initialState != null) {
      // Emit the initial state by dispatching events or wrapping differently.
      // Use BlocProvider.value with a pre-configured bloc.
      final configuredBloc = _BlocWithState(packageRepo, initialState);
      return MaterialApp(
        home: BlocProvider.value(
          value: configuredBloc,
          child: Scaffold(body: child),
        ),
      );
    }
    return MaterialApp(
      home: BlocProvider(
        create: (_) => bloc,
        child: Scaffold(body: child),
      ),
    );
  }

  group('Step3RecapBudget — total budget + net preview + negotiable + payment methods', () {
    // 1. total-budget-input field exists
    testWidgets('total-budget-input field exists', (tester) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('total-budget-input')), findsOneWidget);
    });

    // 2. When totalBudgetEur = 39.20, displays net traveler amount
    testWidgets('shows net traveler amount when totalBudgetEur is set', (tester) async {
      final bloc = PackageRequestFormBloc(packageRepo);
      bloc.add(const PackageRequestTotalBudgetChanged(39.20));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(body: Step3RecapBudget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Net = 39.20 / 1.12 ≈ 35.00
      final net = 39.20 / 1.12;
      final netLabel = PriceDisplay.eur(net);
      expect(find.textContaining(netLabel), findsOneWidget);
    });

    // 3. negotiable-toggle Switch exists
    testWidgets('negotiable-toggle switch exists', (tester) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('negotiable-toggle')), findsOneWidget);
    });

    // 4. Payment method chips are visible
    testWidgets('payment method chips are visible', (tester) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      await tester.pumpAndSettle();
      expect(find.text('Carte'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
    });

    // 5. Toggling negotiable dispatches the event and updates state
    testWidgets('tapping negotiable toggle dispatches PackageRequestNegotiableToggled',
        (tester) async {
      final bloc = PackageRequestFormBloc(packageRepo);
      // Default negotiable = true, so initial value is true
      expect(bloc.state.negotiable, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(body: Step3RecapBudget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the switch and tap it
      final switchFinder = find.byKey(const Key('negotiable-toggle'));
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(bloc.state.negotiable, isFalse);
    });

    // 6. Tapping a payment chip toggles its selected state
    testWidgets('tapping Cash chip toggles acceptedPaymentMethods', (tester) async {
      final bloc = PackageRequestFormBloc(packageRepo);
      // Default: {stripe} selected
      expect(bloc.state.acceptedPaymentMethods.contains(PaymentMethod.cash), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(body: Step3RecapBudget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Cash chip
      await tester.ensureVisible(find.text('Cash'));
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();

      expect(bloc.state.acceptedPaymentMethods.contains(PaymentMethod.cash), isTrue);
    });

    // 7. Net preview is NOT shown when totalBudgetEur is null
    testWidgets('no net preview shown when totalBudgetEur is null', (tester) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      await tester.pumpAndSettle();

      // "Le voyageur touchera" text should not be present when budget is null
      expect(find.textContaining('Le voyageur touchera'), findsNothing);
    });
  });
}

/// Helper: a bloc that starts with a custom state by applying a side-effect.
/// We create it and immediately add an event to set totalBudgetEur.
class _BlocWithState extends PackageRequestFormBloc {
  _BlocWithState(super.repository, PackageRequestFormState targetState) {
    if (targetState.totalBudgetEur != null) {
      add(PackageRequestTotalBudgetChanged(targetState.totalBudgetEur!));
    }
  }
}
