import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockActivationCubit extends MockCubit<ActivationState>
    implements ActivationCubit {}

void main() {
  late MockAnalyticsBackend backend;
  late _MockActivationCubit activation;
  late AnalyticsService analytics;

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    activation = _MockActivationCubit();
    when(() => activation.state).thenReturn(const ActivationUnavailable());
    when(() => activation.load()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: firstStepsRoute,
      routes: [
        GoRoute(
          path: firstStepsRoute,
          builder: (_, _) => FirstStepsScreen(analytics: analytics),
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
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pose la question et propose les deux premiers pas', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Votre compte est prêt'), findsOneWidget);
    expect(find.text('Je voyage'), findsOneWidget);
    expect(find.text("J'envoie un colis"), findsOneWidget);
    expect(find.text("Plus tard, aller à l'accueil"), findsOneWidget);
  });

  testWidgets('« Je voyage » ouvre l\'intro de publication d\'un trajet', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-trip')));
    await tester.pumpAndSettle();

    expect(find.text('Trip intro'), findsOneWidget);
    verify(
      () =>
          backend.capture(AnalyticsEvents.firstStepsChoice, {'choice': 'trip'}),
    ).called(1);
  });

  testWidgets('« J\'envoie un colis » ouvre l\'intro d\'envoi', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-parcel')));
    await tester.pumpAndSettle();

    expect(find.text('Parcel intro'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'parcel',
      }),
    ).called(1);
  });

  testWidgets('« Plus tard » mène à l\'accueil, comme avant', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-later')));
    await tester.pumpAndSettle();

    expect(find.text('Home route'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'later',
      }),
    ).called(1);
  });

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
