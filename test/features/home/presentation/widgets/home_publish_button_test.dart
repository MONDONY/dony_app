import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/home/presentation/widgets/home_publish_button.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class _StubSessionProbe implements FirebaseSessionProbe {
  const _StubSessionProbe({required this.hasRealSession});

  @override
  final bool hasRealSession;
  @override
  bool get hasSession => true;
  @override
  bool get isAnonymous => !hasRealSession;
}

Widget _app({required ActiveRole role, Locale locale = const Locale('fr')}) {
  final roleCubit = _MockActiveRoleCubit();
  when(() => roleCubit.state).thenReturn(role);

  Widget stub(String label) => Scaffold(body: Text(label));

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<ActiveRoleCubit>.value(
          value: roleCubit,
          child: const Scaffold(
            body: SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: HomePublishButton(),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/parcels/send-intro',
        builder: (_, _) => stub('STUB_SEND_INTRO'),
      ),
      GoRoute(
        path: '/trips/publish-intro',
        builder: (_, _) => stub('STUB_TRIP_INTRO'),
      ),
      GoRoute(path: '/auth/method', builder: (_, _) => stub('STUB_AUTH')),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
  );
}

void main() {
  late _MockAnalyticsService analytics;

  setUp(() {
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerSingleton<FirebaseSessionProbe>(
      const _StubSessionProbe(hasRealSession: true),
    );
  });

  tearDown(getIt.reset);

  void asGuest() {
    getIt.unregister<FirebaseSessionProbe>();
    getIt.registerSingleton<FirebaseSessionProbe>(
      const _StubSessionProbe(hasRealSession: false),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home-publish-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('porte un libellé d\'accessibilité clair (bouton)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(role: ActiveRole.sender));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Publier : envoyer un colis ou publier un trajet'),
      findsOneWidget,
    );
    final node = tester.getSemantics(find.byType(HomePublishButton));
    expect(node.flagsCollection.isButton, isTrue);
    // Cible tactile ≥ 48 dp par défaut, comme la cloche.
    expect(
      tester.getSize(find.byKey(const Key('home-publish-button'))),
      const Size(48, 48),
    );
    handle.dispose();
  });

  testWidgets('libellé anglais', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(role: ActiveRole.sender, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Publish: send a parcel or publish a trip'),
      findsOneWidget,
    );
    await openSheet(tester);
    expect(find.text('What would you like to publish?'), findsOneWidget);
    expect(find.text('Send a parcel'), findsOneWidget);
    expect(find.text('Publish a trip'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('ouvre une feuille aux deux choix et trace son ouverture', (
    tester,
  ) async {
    await tester.pumpWidget(_app(role: ActiveRole.sender));
    await tester.pumpAndSettle();
    await openSheet(tester);

    expect(find.text('Que voulez-vous publier ?'), findsOneWidget);
    expect(find.byKey(const Key('home-publish-choice-parcel')), findsOneWidget);
    expect(find.byKey(const Key('home-publish-choice-trip')), findsOneWidget);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.homePublishSheetOpened,
        properties: {'active_role': 'sender'},
      ),
    ).called(1);
  });

  testWidgets('expéditeur : « Envoyer un colis » d\'abord, et il ouvre '
      'l\'intro d\'envoi', (tester) async {
    await tester.pumpWidget(_app(role: ActiveRole.sender));
    await tester.pumpAndSettle();
    await openSheet(tester);

    final parcelY = tester
        .getTopLeft(find.byKey(const Key('home-publish-choice-parcel')))
        .dy;
    final tripY = tester
        .getTopLeft(find.byKey(const Key('home-publish-choice-trip')))
        .dy;
    expect(parcelY, lessThan(tripY));

    await tester.tap(find.byKey(const Key('home-publish-choice-parcel')));
    await tester.pumpAndSettle();

    expect(find.text('STUB_SEND_INTRO'), findsOneWidget);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.homePublishTapped,
        properties: {'choice': 'parcel', 'active_role': 'sender'},
      ),
    ).called(1);
  });

  testWidgets('voyageur : « Publier un trajet » d\'abord, et il ouvre '
      'l\'intro de trajet', (tester) async {
    await tester.pumpWidget(_app(role: ActiveRole.traveler));
    await tester.pumpAndSettle();
    await openSheet(tester);

    final parcelY = tester
        .getTopLeft(find.byKey(const Key('home-publish-choice-parcel')))
        .dy;
    final tripY = tester
        .getTopLeft(find.byKey(const Key('home-publish-choice-trip')))
        .dy;
    expect(tripY, lessThan(parcelY));

    await tester.tap(find.byKey(const Key('home-publish-choice-trip')));
    await tester.pumpAndSettle();

    expect(find.text('STUB_TRIP_INTRO'), findsOneWidget);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.homePublishTapped,
        properties: {'choice': 'trip', 'active_role': 'traveler'},
      ),
    ).called(1);
  });

  testWidgets('voyageur : l\'envoi de colis reste proposé et navigue', (
    tester,
  ) async {
    await tester.pumpWidget(_app(role: ActiveRole.traveler));
    await tester.pumpAndSettle();
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('home-publish-choice-parcel')));
    await tester.pumpAndSettle();

    expect(find.text('STUB_SEND_INTRO'), findsOneWidget);
  });

  testWidgets('fermer la feuille sans choisir ne navigue pas', (tester) async {
    await tester.pumpWidget(_app(role: ActiveRole.sender));
    await tester.pumpAndSettle();
    await openSheet(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Que voulez-vous publier ?'), findsNothing);
    expect(find.text('STUB_SEND_INTRO'), findsNothing);
    expect(find.text('STUB_TRIP_INTRO'), findsNothing);
    verifyNever(
      () => analytics.logEvent(
        AnalyticsEvents.homePublishTapped,
        properties: any(named: 'properties'),
      ),
    );
  });

  testWidgets('invité : même garde que la cloche, « Connexion requise »', (
    tester,
  ) async {
    asGuest();
    await tester.pumpWidget(_app(role: ActiveRole.sender));
    await tester.pumpAndSettle();
    await openSheet(tester);

    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Que voulez-vous publier ?'), findsNothing);
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });

  test('ordre des choix selon le rôle, les deux toujours présents', () {
    expect(homePublishChoicesFor(ActiveRole.sender), [
      HomePublishChoice.parcel,
      HomePublishChoice.trip,
    ]);
    expect(homePublishChoicesFor(ActiveRole.traveler), [
      HomePublishChoice.trip,
      HomePublishChoice.parcel,
    ]);
    expect(HomePublishChoice.parcel.route, '/parcels/send-intro');
    expect(HomePublishChoice.trip.route, '/trips/publish-intro');
  });
}
