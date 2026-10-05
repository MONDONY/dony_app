import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
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

class _MockAuthRepository extends Mock implements AuthRepository {}

const _kUser = UserModel(
  id: 'uid-1',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: ['ROLE_TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

/// Paiements est la dernière étape comptée : `routeAfter(payouts)` doit
/// toujours pointer vers `/home`.
const _progress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
    OnboardingStep.identity,
    OnboardingStep.payouts,
  ],
  done: {
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
    OnboardingStep.identity,
  },
  current: OnboardingStep.payouts,
);

Widget _wrap(
  PaymentBloc bloc, {
  MockAuthBloc? authBloc,
  MockStripeAccountBloc? stripeBloc,
  OnboardingProgress? progress,
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
            child: PayoutOnboardingScreen(progress: progress),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home route')),
        ),
        GoRoute(
          path: '/first-steps',
          builder: (_, _) => const Scaffold(body: Text('First steps route')),
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
  late _MockAuthRepository mockAuthRepository;

  setUp(() {
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

    mockAuthRepository = _MockAuthRepository();
    when(
      () => mockAuthRepository.markOnboardingSeen(),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
    }
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
  });

  tearDown(() {
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
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
        find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
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

    group('depuis l\'onboarding (progress non null)', () {
      testWidgets(
        'état initial : affiche la jauge et « Passer pour l\'instant »',
        (tester) async {
          await tester.pumpWidget(_wrap(mockBloc, progress: _progress));
          await tester.pump(const Duration(milliseconds: 500));

          expect(find.text('Passer pour l\'instant'), findsOneWidget);
        },
      );

      testWidgets(
        '« Passer pour l\'instant » va vers /home et marque l\'onboarding '
        'vu — paiements est la dernière étape, personne ne doit être bloqué '
        'pour l\'avoir remise à plus tard',
        (tester) async {
          await tester.pumpWidget(_wrap(mockBloc, progress: _progress));
          await tester.pump(const Duration(milliseconds: 500));

          await tester.ensureVisible(find.text('Passer pour l\'instant'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Passer pour l\'instant'));
          await tester.pumpAndSettle();

          verify(() => mockAuthRepository.markOnboardingSeen()).called(1);
          expect(find.text('First steps route'), findsOneWidget);
        },
      );

      testWidgets(
        'état complete : « Continuer vers l\'accueil » va vers /home et '
        'marque l\'onboarding vu',
        (tester) async {
          // Contenu plus haut que la fenêtre de test par défaut (jauge +
          // mascotte + texte + bouton) : cette vue n'est pas scrollable
          // (`_SuccessView`, comme avant cette tâche), et sa mascotte anime
          // en boucle (`withGlow: true`) — `pumpAndSettle()` n'y terminerait
          // jamais. Agrandir la fenêtre plutôt que scroller.
          await tester.binding.setSurfaceSize(const Size(400, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          whenListen<PaymentState>(
            mockBloc,
            Stream.value(const PaymentOnboardingComplete()),
            initialState: const PaymentOnboardingComplete(),
          );
          await tester.pumpWidget(_wrap(mockBloc, progress: _progress));
          await tester.pump(const Duration(milliseconds: 500));

          expect(find.text('Paiements activés ✓'), findsOneWidget);
          await tester.tap(find.text('Continuer'));
          // Pas de `pumpAndSettle()` : la mascotte de la page quittée anime
          // en boucle. Des `pump()` bornés suffisent à laisser la transition
          // GoRouter se terminer.
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }

          verify(() => mockAuthRepository.markOnboardingSeen()).called(1);
          expect(find.text('First steps route'), findsOneWidget);
        },
      );

      testWidgets(
        'compte déjà connecté : la jauge s\'affiche et « Continuer vers '
        'l\'accueil » va vers /home',
        (tester) async {
          when(() => mockStripeBloc.state).thenReturn(
            const StripeAccountReady(
              ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
            ),
          );

          await tester.pumpWidget(
            _wrap(mockBloc, stripeBloc: mockStripeBloc, progress: _progress),
          );
          await tester.pump(const Duration(milliseconds: 500));

          expect(find.text('Compte bancaire connecté'), findsOneWidget);
          await tester.ensureVisible(find.text('Continuer'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Continuer'));
          await tester.pumpAndSettle();

          verify(() => mockAuthRepository.markOnboardingSeen()).called(1);
          expect(find.text('First steps route'), findsOneWidget);
        },
      );

      testWidgets(
        'pays non couvert par Stripe : continue silencieusement vers /home '
        'sans montrer d\'impasse — onboardingSteps() exclut déjà les '
        'paiements pour ces pays, arriver ici ne peut être qu\'une course',
        (tester) async {
          when(
            () => mockStripeBloc.state,
          ).thenReturn(stripeCountryUnavailableState);

          await tester.pumpWidget(
            _wrap(mockBloc, stripeBloc: mockStripeBloc, progress: _progress),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();

          verify(() => mockAuthRepository.markOnboardingSeen()).called(1);
          expect(find.text('First steps route'), findsOneWidget);
          expect(
            find.text('Pas encore disponible\ndans votre pays'),
            findsNothing,
          );
        },
      );
    });

    testWidgets('pays non couvert par Stripe SANS onboarding (progress null) : '
        'l\'impasse reste affichée, comportement inchangé', (tester) async {
      when(
        () => mockStripeBloc.state,
      ).thenReturn(stripeCountryUnavailableState);

      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Pas encore disponible\ndans votre pays'),
        findsOneWidget,
      );
      verifyNever(() => mockAuthRepository.markOnboardingSeen());
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
