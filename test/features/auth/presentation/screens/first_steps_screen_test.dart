import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockActivationRepository extends Mock implements ActivationRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockActivationCubit extends MockCubit<ActivationState>
    implements ActivationCubit {}

void main() {
  setUpAll(() {
    registerFallbackValue(UserIntent.sender);
    registerFallbackValue(IntentSource.signup);
  });

  late MockAnalyticsBackend backend;
  late _MockActivationCubit activation;
  late AnalyticsService analytics;
  late _MockActivationRepository repo;
  late _MockAuthRepository auth;

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    activation = _MockActivationCubit();
    when(() => activation.state).thenReturn(const ActivationUnavailable());
    when(() => activation.load()).thenAnswer((_) async {});
    repo = _MockActivationRepository();
    when(
      () => repo.declareIntent(
        intent: any(named: 'intent'),
        destinationCountry: any(named: 'destinationCountry'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});
    auth = _MockAuthRepository();
    when(() => auth.markOnboardingSeen()).thenAnswer((_) async {});
    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
    }
    getIt.registerSingleton<AuthRepository>(auth);
    if (getIt.isRegistered<ActivationCubit>()) {
      getIt.unregister<ActivationCubit>();
    }
    getIt.registerSingleton<ActivationCubit>(activation);
  });

  tearDown(() {
    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
    }
    if (getIt.isRegistered<ActivationCubit>()) {
      getIt.unregister<ActivationCubit>();
    }
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final router = GoRouter(
      initialLocation: firstStepsRoute,
      routes: [
        GoRoute(
          path: firstStepsRoute,
          builder: (_, _) => BlocProvider<IntentCubit>(
            create: (_) => IntentCubit(repo, analytics),
            child: FirstStepsScreen(analytics: analytics),
          ),
        ),
        GoRoute(
          path: '/trips/publish-intro',
          builder: (_, _) => const Scaffold(body: Text('Trip intro')),
        ),
        GoRoute(
          path: '/parcels/send-intro',
          builder: (_, _) => const Scaffold(body: Text('Parcel intro')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home route')),
        ),
        GoRoute(
          path: '/announcements/:id/trip',
          builder: (_, state) =>
              Scaffold(body: Text('Trip ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/package-requests/:id/public',
          builder: (_, state) =>
              Scaffold(body: Text('Colis ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<ActivationCubit>.value(
        value: activation,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pose la question et propose les choix', (tester) async {
    await pump(tester);

    expect(find.text('Par quoi voulez-vous commencer ?'), findsOneWidget);
    expect(find.text('Envoyer un colis'), findsOneWidget);
    expect(find.text('Voyager avec des colis'), findsOneWidget);
    expect(find.text("Je regarde d'abord"), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    expect(
      find.text(
        "Votre identité n'est vérifiée qu'au moment d'envoyer un colis ou de publier un trajet.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('« Envoyer un colis » déclare SENDER puis va sur /home', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-send')));
    await tester.pumpAndSettle();

    verify(
      () => repo.declareIntent(
        intent: UserIntent.sender,
        destinationCountry: null,
        source: IntentSource.signup,
      ),
    ).called(1);
    expect(find.text('Home route'), findsOneWidget);
    // initState (1) puis le rechargement après `saved` (2).
    verify(() => activation.load()).called(2);
    verify(
      () =>
          backend.capture(AnalyticsEvents.firstStepsChoice, {'choice': 'send'}),
    ).called(1);
  });

  testWidgets('« Voyager avec des colis » déclare TRAVELER puis va sur /home', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-travel')));
    await tester.pumpAndSettle();

    verify(
      () => repo.declareIntent(
        intent: UserIntent.traveler,
        destinationCountry: null,
        source: IntentSource.signup,
      ),
    ).called(1);
    expect(find.text('Home route'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'travel',
      }),
    ).called(1);
  });

  testWidgets('« Je regarde d\'abord » et « Plus tard » ne déclarent rien', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('first-steps-browse')));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'browse',
      }),
    ).called(1);

    await pump(tester);
    await tester.tap(find.byKey(const Key('first-steps-later')));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'later',
      }),
    ).called(1);

    verifyNever(
      () => repo.declareIntent(
        intent: any(named: 'intent'),
        destinationCountry: any(named: 'destinationCountry'),
        source: any(named: 'source'),
      ),
    );
  });

  testWidgets('une erreur de declareIntent mène quand même à /home', (
    tester,
  ) async {
    when(
      () => repo.declareIntent(
        intent: any(named: 'intent'),
        destinationCountry: any(named: 'destinationCountry'),
        source: any(named: 'source'),
      ),
    ).thenThrow(Exception('boom'));
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-send')));
    await tester.pumpAndSettle();

    expect(find.text('Home route'), findsOneWidget);
    // Pas de rechargement sur `error` : seul l'appel d'initState a eu lieu.
    verify(() => activation.load()).called(1);
    verify(
      () =>
          backend.capture(AnalyticsEvents.firstStepsChoice, {'choice': 'send'}),
    ).called(1);
  });

  testWidgets('markOnboardingSeen est appelé une fois à l\'affichage', (
    tester,
  ) async {
    await pump(tester);
    // Des rebuilds supplémentaires ne le rappellent pas.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    verify(() => auth.markOnboardingSeen()).called(1);
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    testWidgets('libellés sur une ligne à 360 dp (${locale.languageCode})', (
      tester,
    ) async {
      await pump(tester, locale: locale, size: const Size(360, 800));
      expect(tester.takeException(), isNull);
      for (final key in const ['first-steps-browse', 'first-steps-later']) {
        final button = find.byKey(Key(key));
        expect(tester.getSize(button).height, 52, reason: key);
        final label = find.descendant(of: button, matching: find.byType(Text));
        expect(tester.getSize(label).height, lessThan(24), reason: key);
      }
      // Cartes : la police de test (Ahem) est plus large que la vraie, un
      // titre peut y passer à la ligne ; il doit rester dans sa carte.
      for (final key in const ['first-steps-send', 'first-steps-travel']) {
        final card = find.byKey(Key(key));
        final title = find
            .descendant(of: card, matching: find.byType(Text))
            .first;
        final cardRect = tester.getRect(card);
        final titleRect = tester.getRect(title);
        expect(cardRect.contains(titleRect.topLeft), isTrue, reason: key);
        expect(cardRect.contains(titleRect.bottomRight), isTrue, reason: key);
      }
    });
  }

  testWidgets('charge le statut d\'activation à l\'ouverture', (tester) async {
    await pump(tester);
    verify(() => activation.load()).called(1);
  });

  testWidgets('expéditeur avec trajets : titre, cartes et CTA', (tester) async {
    when(() => activation.state).thenReturn(
      ActivationLoaded(
        ActivationStatus(
          intent: UserIntent.sender,
          destinationCountry: 'CI',
          kycVerified: true,
          firstActionDone: false,
          kind: OpportunityKind.trips,
          total: 3,
          trips: [
            ActivationTrip(
              id: 't1',
              departureCity: 'Paris',
              arrivalCity: 'Abidjan',
              departureDate: DateTime(2026, 10, 10),
              availableKg: 12,
            ),
          ],
        ),
      ),
    );
    await pump(tester);

    expect(find.textContaining('3 voyageurs partent vers'), findsOneWidget);
    expect(find.text('Paris vers Abidjan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('first-steps-primary')));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'see_trips',
        'variant': 'sender_full',
      }),
    ).called(1);
  });

  testWidgets('expéditeur : une carte trajet ouvre le trajet', (tester) async {
    when(() => activation.state).thenReturn(
      ActivationLoaded(
        ActivationStatus(
          intent: UserIntent.sender,
          destinationCountry: 'CI',
          firstActionDone: false,
          kind: OpportunityKind.trips,
          total: 1,
          trips: [
            ActivationTrip(
              id: 't9',
              departureCity: 'Lyon',
              arrivalCity: 'Abidjan',
              departureDate: DateTime(2026, 10, 11),
            ),
          ],
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('first-steps-trip-t9')));
    await tester.pumpAndSettle();
    expect(find.text('Trip t9'), findsOneWidget);
  });

  testWidgets('expéditeur sans trajet : titre vide et lien demande de colis', (
    tester,
  ) async {
    when(() => activation.state).thenReturn(
      const ActivationLoaded(
        ActivationStatus(
          intent: UserIntent.sender,
          destinationCountry: 'SN',
          firstActionDone: false,
        ),
      ),
    );
    await pump(tester);
    expect(find.textContaining('Aucun voyageur vers'), findsOneWidget);
    expect(find.text("Me prévenir dès qu'un voyageur part"), findsOneWidget);
    await tester.tap(find.byKey(const Key('first-steps-publish-parcel')));
    await tester.pumpAndSettle();
    expect(find.text('Parcel intro'), findsOneWidget);
  });

  testWidgets('voyageur avec colis : une carte colis ouvre la demande', (
    tester,
  ) async {
    when(() => activation.state).thenReturn(
      ActivationLoaded(
        ActivationStatus(
          intent: UserIntent.traveler,
          destinationCountry: 'SN',
          firstActionDone: false,
          kind: OpportunityKind.packages,
          total: 2,
          packages: [
            ActivationPackage(
              id: 'p1',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
              desiredDate: DateTime(2026, 10, 12),
              weightKg: 3,
            ),
          ],
        ),
      ),
    );
    await pump(tester);
    expect(
      find.textContaining('2 colis attendent un voyageur'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('first-steps-package-p1')));
    await tester.pumpAndSettle();
    expect(find.text('Colis p1'), findsOneWidget);
  });

  testWidgets('voyageur avec un colis sans date : « Date flexible »', (
    tester,
  ) async {
    when(() => activation.state).thenReturn(
      const ActivationLoaded(
        ActivationStatus(
          intent: UserIntent.traveler,
          destinationCountry: 'SN',
          firstActionDone: false,
          kind: OpportunityKind.packages,
          total: 1,
          packages: [
            ActivationPackage(
              id: 'p2',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
              weightKg: 3,
            ),
          ],
        ),
      ),
    );
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Date flexible'), findsOneWidget);
  });

  testWidgets('voyageur sans colis : CTA publier mon trajet', (tester) async {
    when(() => activation.state).thenReturn(
      const ActivationLoaded(
        ActivationStatus(
          intent: UserIntent.traveler,
          destinationCountry: 'SN',
          firstActionDone: false,
        ),
      ),
    );
    await pump(tester);
    expect(
      find.text(
        'Publiez votre trajet, les expéditeurs de votre ligne seront prévenus',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('first-steps-publish-parcel')), findsNothing);
    await tester.tap(find.byKey(const Key('first-steps-primary')));
    await tester.pumpAndSettle();
    expect(find.text('Trip intro'), findsOneWidget);
  });

  testWidgets('les deux : lien « Vous voyagez aussi ? »', (tester) async {
    when(() => activation.state).thenReturn(
      const ActivationLoaded(
        ActivationStatus(
          intent: UserIntent.both,
          destinationCountry: 'ML',
          firstActionDone: false,
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('first-steps-both-travel')));
    await tester.pumpAndSettle();
    expect(find.text('Trip intro'), findsOneWidget);
  });

  testWidgets('personnalisé : « Plus tard » trace la variante', (tester) async {
    when(() => activation.state).thenReturn(
      const ActivationLoaded(
        ActivationStatus(intent: UserIntent.traveler, firstActionDone: false),
      ),
    );
    await pump(tester);
    expect(find.textContaining('votre destination'), findsNothing);
    await tester.tap(find.byKey(const Key('first-steps-later')));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'later',
        'variant': 'traveler_empty',
      }),
    ).called(1);
  });
}
