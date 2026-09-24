import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockConnectOnboardingBloc
    extends MockBloc<ConnectOnboardingEvent, ConnectOnboardingState>
    implements ConnectOnboardingBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

void main() {
  late MockConnectOnboardingBloc mockBloc;
  late MockStripeAccountBloc mockStripeBloc;
  late StreamController<ConnectOnboardingState> stateController;

  setUp(() {
    mockBloc = MockConnectOnboardingBloc();
    stateController = StreamController<ConnectOnboardingState>.broadcast();
    when(
      () => mockBloc.state,
    ).thenReturn(const ConnectOnboardingNeedsOnboarding());
    when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);

    mockStripeBloc = MockStripeAccountBloc();
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
    getIt.registerSingleton<StripeAccountBloc>(mockStripeBloc);
  });

  tearDown(() {
    stateController.close();
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
  });

  // `.build()` seul (titre/description), sans passer par `.show()`.
  Widget buildContentOnly() => MaterialApp(
    home: BlocProvider<ConnectOnboardingBloc>.value(
      value: mockBloc,
      child: const Scaffold(body: ConnectPendingBottomSheet()),
    ),
  );

  // `.show()` complet (stickyBottom + BlocListener), via un vrai bottom sheet
  // ouvert depuis un bouton, avec les routes '/profile' et '/home' que
  // ConnectPendingBottomSheet cible.
  Widget buildShowHarness() => MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<ConnectOnboardingBloc>.value(
            value: mockBloc,
            child: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => ConnectPendingBottomSheet.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile route')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home route')),
        ),
      ],
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(buildShowHarness());
    await tester.tap(find.text('open'));
    // Pas de `pumpAndSettle()` : la mascotte du contenu anime en boucle
    // (voir payout_onboarding_screen_test.dart). Des `pump()` bornés
    // suffisent à laisser l'ouverture du bottom sheet se terminer.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> drainMascotteTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('affiche le titre et la description', (tester) async {
    await tester.pumpWidget(buildContentOnly());
    expect(find.text('En attente de Stripe'), findsOneWidget);
    expect(
      find.text(
        'Revenez ici après avoir complété le formulaire Stripe dans votre navigateur.',
      ),
      findsOneWidget,
    );

    await drainMascotteTimers(tester);
  });

  testWidgets('en anglais : titre et description traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(buildContentOnly());
    expect(find.text('Waiting for Stripe'), findsOneWidget);
    expect(
      find.text(
        'Come back here after completing the Stripe form in your browser.',
      ),
      findsOneWidget,
    );

    await drainMascotteTimers(tester);
  });

  group('boutons du stickyBottom (.show())', () {
    testWidgets('affiche les deux boutons', (tester) async {
      await openSheet(tester);
      expect(find.text("J'ai complété le formulaire"), findsOneWidget);
      expect(find.text('Revenir plus tard'), findsOneWidget);

      await drainMascotteTimers(tester);
    });

    testWidgets('en anglais : les deux boutons sont traduits', (tester) async {
      useEnglish();
      await openSheet(tester);
      expect(find.text('I completed the form'), findsOneWidget);
      expect(find.text('Come back later'), findsOneWidget);

      await drainMascotteTimers(tester);
    });

    testWidgets('« Revenir plus tard » ferme la feuille et va vers /profile', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text('Revenir plus tard'));
      await tester.pumpAndSettle();
      expect(find.text('Profile route'), findsOneWidget);
    });
  });

  group('messages du BlocListener (.show())', () {
    testWidgets('succès : snackbar « Compte bancaire configuré ! »', (
      tester,
    ) async {
      await openSheet(tester);
      stateController.add(const ConnectOnboardingComplete());
      await tester.pump();
      expect(find.text('Compte bancaire configuré !'), findsOneWidget);

      await drainMascotteTimers(tester);
    });

    testWidgets('en anglais : snackbar de succès traduit', (tester) async {
      useEnglish();
      await openSheet(tester);
      stateController.add(const ConnectOnboardingComplete());
      await tester.pump();
      expect(find.text('Bank account set up!'), findsOneWidget);

      await drainMascotteTimers(tester);
    });

    testWidgets('en attente : snackbar « Stripe n\'a pas encore reçu... »', (
      tester,
    ) async {
      await openSheet(tester);
      stateController.add(const ConnectOnboardingPending());
      await tester.pump();
      expect(
        find.text(
          "Stripe n'a pas encore reçu toutes vos informations. "
          'Reprenez le formulaire pour le terminer.',
        ),
        findsOneWidget,
      );

      await drainMascotteTimers(tester);
    });

    testWidgets('en anglais : snackbar d\'attente traduit', (tester) async {
      useEnglish();
      await openSheet(tester);
      stateController.add(const ConnectOnboardingPending());
      await tester.pump();
      expect(
        find.text(
          "Stripe hasn't received all your information yet. Resume the "
          'form to finish it.',
        ),
        findsOneWidget,
      );

      await drainMascotteTimers(tester);
    });
  });
}
