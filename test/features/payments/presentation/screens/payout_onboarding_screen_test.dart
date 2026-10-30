import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/connect_onboarding/bloc/bank_account_link_cubit.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:dony/features/payments/presentation/stripe_onboarding_return.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';
// `MockStripeAccountBloc` est déjà déclaré localement ci-dessous : on n'importe
// que la constante d'état pour éviter la collision de noms.
import '../../../../helpers/stripe_account_test_doubles.dart'
    show stripeCountryUnavailableState;

class MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

class _MockConnectRepo extends Mock implements IConnectOnboardingRepository {}

const _kUser = UserModel(
  id: 'uid-1',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: ['ROLE_TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

Widget _wrap(
  PaymentBloc bloc, {
  MockAuthBloc? authBloc,
  MockStripeAccountBloc? stripeBloc,
}) {
  final auth = authBloc ?? MockAuthBloc();
  if (authBloc == null) {
    when(() => auth.state).thenReturn(const AuthAuthenticated(_kUser));
    when(() => auth.stream).thenAnswer((_) => const Stream.empty());
  }
  final stripe = stripeBloc ?? MockStripeAccountBloc();
  if (stripeBloc == null) {
    when(() => stripe.state).thenReturn(const StripeAccountInitial());
    when(() => stripe.stream).thenAnswer((_) => const Stream.empty());
    when(() => stripe.isClosed).thenReturn(false);
  }
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<PaymentBloc>.value(value: bloc),
              BlocProvider<StripeAccountBloc>.value(value: stripe),
            ],
            child: const PayoutOnboardingScreen(),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home route')),
        ),
        GoRoute(
          path: '/profile/edit/email',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('Edit email route'),
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('email-added'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('email-cancelled'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

final class _RecordingLauncher extends UrlLauncherPlatform {
  final launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
  });

  late MockPaymentBloc mockBloc;
  late MockStripeAccountBloc mockStripeBloc;
  late _MockConnectRepo mockConnectRepo;

  setUp(() {
    mockConnectRepo = _MockConnectRepo();
    if (getIt.isRegistered<BankAccountLinkCubit>()) {
      getIt.unregister<BankAccountLinkCubit>();
    }
    getIt.registerFactory<BankAccountLinkCubit>(
      () => BankAccountLinkCubit(
        mockConnectRepo,
        makeEnabledAnalytics(MockAnalyticsBackend()),
      ),
    );
    mockBloc = MockPaymentBloc();
    whenListen<PaymentState>(
      mockBloc,
      Stream.value(const PaymentInitial()),
      initialState: const PaymentInitial(),
    );
    mockStripeBloc = MockStripeAccountBloc();
    when(() => mockStripeBloc.state).thenReturn(const StripeAccountInitial());
    when(() => mockStripeBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockStripeBloc.isClosed).thenReturn(false);
    when(
      () => mockStripeBloc.add(const StripeAccountStatusRefreshed()),
    ).thenReturn(null);
    // Register in GetIt so the listener in PayoutOnboardingScreen can call
    // getIt<StripeAccountBloc>() when PaymentOnboardingComplete fires.
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
    getIt.registerSingleton<StripeAccountBloc>(mockStripeBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<BankAccountLinkCubit>()) {
      getIt.unregister<BankAccountLinkCubit>();
    }
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
  });

  group('PayoutOnboardingScreen', () {
    testWidgets('affiche le bouton Connecter en état initial', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Connecter mon compte bancaire'), findsOneWidget);
    });

    testWidgets('affiche le bandeau warning en état pending', (tester) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentOnboardingPending()),
        initialState: const PaymentOnboardingPending(),
      );
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('pas terminée'), findsOneWidget);
    });

    testWidgets(
      'le bandeau survit au démontage : il suit le statut serveur, pas le '
      'PaymentBloc recréé à chaque montage',
      (tester) async {
        // PaymentBloc revenu à Initial (nouvelle instance de route), mais le
        // serveur sait que l'inscription est entamée.
        when(() => mockStripeBloc.state).thenReturn(
          const StripeAccountReady(
            ConnectAccountStatus(status: 'PENDING_ONBOARDING'),
          ),
        );

        await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.textContaining('pas terminée'), findsOneWidget);
        expect(find.text('Reprendre mon inscription'), findsOneWidget);
        expect(find.text('Connecter mon compte bancaire'), findsNothing);
      },
    );

    testWidgets('aucun bandeau quand aucun compte n\'a jamais été créé', (
      tester,
    ) async {
      when(() => mockStripeBloc.state).thenReturn(
        const StripeAccountReady(ConnectAccountStatus(status: 'NOT_CREATED')),
      );

      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('pas terminée'), findsNothing);
      expect(find.text('Connecter mon compte bancaire'), findsOneWidget);
    });

    testWidgets('pays non couvert par Stripe : explique au lieu de proposer '
        'l\'inscription', (tester) async {
      // Second parcours d'onboarding Connect de l'app, distinct de
      // ConnectOnboardingIntroScreen : la même impasse doit y donner le
      // même écran, sinon le trou se rouvre par cette porte.
      when(
        () => mockStripeBloc.state,
      ).thenReturn(stripeCountryUnavailableState);

      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Pas encore disponible\ndans votre pays'),
        findsOneWidget,
      );
      expect(find.text('Connecter mon compte bancaire'), findsNothing);
    });

    testWidgets('resynchronise le statut à l\'ouverture de l\'écran', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => mockStripeBloc.add(const StripeAccountStatusRefreshed()),
      ).called(1);
    });

    testWidgets('affiche le bandeau error en état error', (tester) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentError(NetworkException('Compte refusé'))),
        initialState: const PaymentError(NetworkException('Compte refusé')),
      );
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      // L'écran affiche ErrorPresenter.resolve(error).message → texte du catalog.
      expect(
        find.text(
          'Une erreur est survenue. Vérifiez votre connexion et réessayez.',
        ),
        findsOneWidget,
      );
    });

    // ── FLUTTER-3T : compte inscrit par téléphone, retour du navigateur ────────

    testWidgets(
      'contact-email-required : message explicite + bouton vers l\'ajout d\'email',
      (tester) async {
        const error = PaymentError(
          ValidationException('Email requis', code: 'contact-email-required'),
        );
        whenListen<PaymentState>(
          mockBloc,
          Stream.value(error),
          initialState: error,
        );
        await tester.pumpWidget(_wrap(mockBloc));
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.textContaining('Stripe a besoin d\'une adresse e-mail'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Ajouter mon adresse e-mail'));
        await tester.tap(find.text('Ajouter mon adresse e-mail'));
        await tester.pumpAndSettle();
        expect(find.text('Edit email route'), findsOneWidget);
      },
    );

    // ── FLUTTER-BX : retour de l'ajout d'email ────────────────────────────────

    for (final (label, button, retried) in [
      ('email ajouté → la demande est relancée', 'email-added', true),
      ('ajout abandonné → rien n\'est relancé', 'email-cancelled', false),
    ]) {
      testWidgets('contact-email-required : $label', (tester) async {
        const error = PaymentError(
          ValidationException('Email requis', code: 'contact-email-required'),
        );
        whenListen<PaymentState>(
          mockBloc,
          Stream.value(error),
          initialState: error,
        );
        await tester.pumpWidget(_wrap(mockBloc));
        await tester.pump(const Duration(milliseconds: 500));

        await tester.ensureVisible(find.text('Ajouter mon adresse e-mail'));
        await tester.tap(find.text('Ajouter mon adresse e-mail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();

        if (retried) {
          verify(
            () => mockBloc.add(const PaymentConnectAccountRequested()),
          ).called(1);
        } else {
          verifyNever(
            () => mockBloc.add(const PaymentConnectAccountRequested()),
          );
        }
      });
    }

    testWidgets('affiche l\'email de contact quand il est connu', (
      tester,
    ) async {
      final auth = MockAuthBloc();
      when(() => auth.state).thenReturn(
        AuthAuthenticated(_kUser.copyWith(email: 'ibra@example.com')),
      );
      when(() => auth.stream).thenAnswer((_) => const Stream.empty());
      await tester.pumpWidget(_wrap(mockBloc, authBloc: auth));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('E-mail de contact : ibra@example.com'), findsOneWidget);
    });

    testWidgets('sans email connu : aucune ligne d\'email de contact', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('E-mail de contact'), findsNothing);
    });

    testWidgets('autre erreur : pas de bouton d\'ajout d\'email', (
      tester,
    ) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentError(NetworkException('Compte refusé'))),
        initialState: const PaymentError(NetworkException('Compte refusé')),
      );
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ajouter mon adresse e-mail'), findsNothing);
    });

    testWidgets(
      'retour au premier plan sans lien Stripe ouvert : pas de relecture en plus',
      (tester) async {
        await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
        await tester.pump(const Duration(milliseconds: 500));

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        // Seulement la resynchronisation d'ouverture.
        verify(
          () => mockStripeBloc.add(const StripeAccountStatusRefreshed()),
        ).called(1);
      },
    );

    testWidgets(
      'lien Stripe ouvert puis retour au premier plan : statut relu, origine retenue',
      (tester) async {
        final previous = UrlLauncherPlatform.instance;
        final launcher = _RecordingLauncher();
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() {
          UrlLauncherPlatform.instance = previous;
          StripeOnboardingReturn.consume();
        });
        whenListen<PaymentState>(
          mockBloc,
          Stream.value(
            const PaymentOnboardingUrlReady('https://connect.stripe.com/x'),
          ),
          initialState: const PaymentInitial(),
        );

        await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
        await tester.pump(const Duration(milliseconds: 500));
        expect(launcher.launchedUrls, ['https://connect.stripe.com/x']);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        // Ouverture de l'écran + retour du navigateur.
        verify(
          () => mockStripeBloc.add(const StripeAccountStatusRefreshed()),
        ).called(2);
        expect(StripeOnboardingReturn.consume(), '/');
      },
    );

    testWidgets('affiche la vue succès en état complete', (tester) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentOnboardingComplete()),
        initialState: const PaymentOnboardingComplete(),
      );
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paiements activés ✓'), findsOneWidget);
    });

    testWidgets('dispatch PaymentConnectAccountRequested au tap', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Connecter mon compte bancaire'));
      await tester.tap(find.text('Connecter mon compte bancaire'));
      verify(
        () => mockBloc.add(const PaymentConnectAccountRequested()),
      ).called(1);
    });

    // L'écran ne fait plus partie de l'inscription : rien à passer, rien vers
    // où continuer, on en sort par la barre d'app.
    testWidgets('état initial : pas de « Passer pour l\'instant »', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Connecter mon compte bancaire'), findsOneWidget);
      expect(find.text('Passer pour l\'instant'), findsNothing);
    });

    testWidgets('compte déjà connecté : pas de bouton « Continuer »', (
      tester,
    ) async {
      when(() => mockStripeBloc.state).thenReturn(
        const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
      );

      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Compte bancaire connecté'), findsOneWidget);
      expect(find.text('Continuer'), findsNothing);
    });

    testWidgets('compte connecté : « Changer de compte '
        'bancaire » ; 409 relit le statut Stripe', (tester) async {
      when(() => mockStripeBloc.state).thenReturn(
        const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
      );
      when(mockConnectRepo.createDashboardLink).thenThrow(
        const ConflictException('x', code: 'stripe-onboarding-incomplete'),
      );

      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Changer de compte bancaire'), findsOneWidget);
      expect(find.textContaining('modifier votre IBAN'), findsOneWidget);
      clearInteractions(mockStripeBloc);

      await tester.ensureVisible(find.text('Changer de compte bancaire'));
      await tester.tap(find.text('Changer de compte bancaire'));
      await tester.pump();
      await tester.pump();

      verify(mockConnectRepo.createDashboardLink).called(1);
      verify(
        () => mockStripeBloc.add(const StripeAccountStatusRefreshed()),
      ).called(1);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('pays non couvert par Stripe : l\'écran l\'explique', (
      tester,
    ) async {
      when(
        () => mockStripeBloc.state,
      ).thenReturn(stripeCountryUnavailableState);

      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Pas encore disponible\ndans votre pays'),
        findsOneWidget,
      );
    });

    testWidgets('en anglais : titre traduit', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Get paid'), findsOneWidget);
      expect(find.text('Connect my bank account'), findsOneWidget);
    });
  });
}
