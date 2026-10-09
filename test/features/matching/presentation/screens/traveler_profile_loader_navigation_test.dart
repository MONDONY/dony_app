import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _RealSessionProbe implements FirebaseSessionProbe {
  const _RealSessionProbe();

  @override
  bool get hasSession => true;

  @override
  bool get isAnonymous => false;

  @override
  bool get hasRealSession => true;
}

AnnouncementModel _announcement() {
  final now = DateTime.now();
  return AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(now.year, now.month + 1, 15),
    availableKg: 12,
    totalKg: 20,
    pricePerKg: 8,
    status: 'ACTIVE',
    traveler: const TravelerProfile(id: 't1', displayName: 'Ibrahima Diallo'),
    createdAt: now,
    updatedAt: now,
  );
}

BidModel _myBid() => BidModel(
  id: 'bid-1',
  announcementId: 'a1',
  senderId: 'u1',
  status: 'ACCEPTED',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Écran « Notifications » (`/`) : « Alerte corridor » pousse `/traveler/a1`
/// (notification CORRIDOR_ALERT), « Depuis la carte » ouvre la feuille
/// directement, comme la carte, la liste ou la recherche.
Future<GoRouter> _pump(
  WidgetTester tester, {
  BidState? bidState,
  String kycStatus = 'VERIFIED',
}) async {
  await initializeDateFormatting('fr');
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final authBloc = _MockAuthBloc();
  when(() => authBloc.state).thenReturn(
    AuthAuthenticated(
      UserModel(
        id: 'u1',
        roles: const [],
        kycStatus: kycStatus,
        status: 'ACTIVE',
      ),
    ),
  );
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('Notifications'),
              TextButton(
                onPressed: () => context.push('/traveler/a1'),
                child: const Text('Alerte corridor'),
              ),
              TextButton(
                onPressed: () => showTravelerAnnouncementSheet(
                  context,
                  announcement: _announcement(),
                ),
                child: const Text('Depuis la carte'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/traveler/:announcementId',
        builder: (_, state) => TravelerProfileLoaderScreen(
          announcementId: state.pathParameters['announcementId']!,
        ),
      ),
      GoRoute(
        path: '/bids/:bidId',
        builder: (_, state) =>
            Scaffold(body: Text('Colis ${state.pathParameters['bidId']}')),
      ),
      GoRoute(
        path: '/settings/report-incident',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return Scaffold(body: Text('Signalement ${extra?['targetId']}'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<BidBloc>.value(value: bidBloc),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      ),
    ),
  );
  return router;
}

/// Emplacement de la page au sommet de la pile (les `push` n'altèrent pas
/// l'URI de base de la configuration).
String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

/// Nombre de pages dans la pile GoRouter.
int _depth(GoRouter router) =>
    router.routerDelegate.currentConfiguration.matches.length;

Future<void> _openViaLoader(WidgetTester tester) async {
  await tester.tap(find.text('Alerte corridor'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('report-announcement-link')), findsOneWidget);
}

void main() {
  setUp(() {
    final bloc = _MockAnnouncementBloc();
    whenListen(
      bloc,
      const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementDetailLoaded(_announcement()),
    );
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => bloc);
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
  });

  group('FLUTTER-HR — feuille ouverte par /traveler/:id', () {
    testWidgets('« Voir mon colis » → /bids/:id affiché, le retour ramène aux '
        'notifications', (tester) async {
      final router = await _pump(tester, bidState: BidListLoaded([_myBid()]));
      await _openViaLoader(tester);

      await tester.tap(find.byKey(const Key('see-my-parcel-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Colis bid-1'), findsOneWidget);
      expect(_location(router), '/bids/bid-1');
      expect(_depth(router), 2);

      // La page d'accueil vide a été remplacée, pas laissée dans la pile.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(_location(router), '/');
    });

    testWidgets('« Signaler ce trajet » → écran de signalement affiché', (
      tester,
    ) async {
      final router = await _pump(tester);
      await _openViaLoader(tester);

      final link = find.byKey(const Key('report-announcement-link'));
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.text('Signalement a1'), findsOneWidget);
      expect(_location(router), '/settings/report-incident');
      expect(_depth(router), 2);
    });

    testWidgets('fermeture sans action → retour à l\'écran précédent', (
      tester,
    ) async {
      final router = await _pump(tester);
      await _openViaLoader(tester);

      // Tap sur le voile, au-dessus de la feuille.
      await tester.tapAt(const Offset(400, 10));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-announcement-link')), findsNothing);
      expect(find.text('Notifications'), findsOneWidget);
      expect(_location(router), '/');
      expect(_depth(router), 1);
    });

    group('« Faire une demande »', () {
      setUp(() {
        if (getIt.isRegistered<FirebaseSessionProbe>()) {
          getIt.unregister<FirebaseSessionProbe>();
        }
        getIt.registerSingleton<FirebaseSessionProbe>(
          const _RealSessionProbe(),
        );
        final kycBloc = _MockKycBloc();
        when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => kycBloc.state).thenReturn(const KycInitial());
        if (getIt.isRegistered<KycBloc>()) getIt.unregister<KycBloc>();
        getIt.registerFactory<KycBloc>(() => kycBloc);
      });

      tearDown(() {
        getIt.unregister<FirebaseSessionProbe>();
        getIt.unregister<KycBloc>();
      });

      testWidgets('identité non vérifiée → la feuille KYC reste ouverte, '
          'la page d\'accueil s\'est retirée', (tester) async {
        final router = await _pump(tester, kycStatus: 'NOT_STARTED');
        await _openViaLoader(tester);

        await tester.tap(find.text('Faire une demande'));
        await tester.pumpAndSettle();

        // Sans la suite différée, le `pop` de la page d'accueil refermait
        // aussitôt la feuille KYC ouverte par-dessus.
        expect(find.text("Vérification d'identité"), findsOneWidget);
        expect(_location(router), '/');
        expect(_depth(router), 1);
      });
    });
  });

  group('autres points d\'entrée — comportement inchangé', () {
    testWidgets('« Voir mon colis » pousse /bids/:id par-dessus l\'écran', (
      tester,
    ) async {
      final router = await _pump(tester, bidState: BidListLoaded([_myBid()]));
      await tester.tap(find.text('Depuis la carte'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('see-my-parcel-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Colis bid-1'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('fermeture → la feuille ne rend aucune navigation', (
      tester,
    ) async {
      await _pump(tester);
      late Future<TravelerSheetExit?> result;
      final ctx = tester.element(find.text('Depuis la carte'));
      result = showTravelerAnnouncementSheet(
        ctx,
        announcement: _announcement(),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 10));
      await tester.pumpAndSettle();

      expect(await result, isNull);
      expect(find.text('Notifications'), findsOneWidget);
    });
  });
}
