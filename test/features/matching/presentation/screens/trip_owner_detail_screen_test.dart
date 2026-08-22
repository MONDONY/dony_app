import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/trip_owner_detail_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/stripe_account_test_doubles.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Fixture builder ───────────────────────────────────────────────────────────

const _ownerId = 'trav-001';

const _owner = UserModel(
  id: _ownerId,
  roles: [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

AnnouncementModel _makeAnnouncement({String status = 'ACTIVE'}) =>
    AnnouncementModel(
      id: 'ann-trip-001',
      travelerId: _ownerId,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 7),
      availableKg: 10,
      totalKg: 23,
      pricePerKg: 8,
      status: status,
      bidsCount: 0,
      createdAt: DateTime(2026, 6),
      updatedAt: DateTime(2026, 6),
    );

BidModel _makeBid({required String status}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-trip-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
);

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  required _MockAnnouncementBloc annBloc,
  required _MockBidBloc bidBloc,
  required _MockCancellationBloc cancelBloc,
  required _MockAuthBloc authBloc,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: annBloc),
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<CancellationBloc>.value(value: cancelBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
            // Fourni à l'échelle de l'app dans `app.dart` : le corps de détail
            // le lit pour savoir si Stripe couvre le pays du voyageur.
            BlocProvider<StripeAccountBloc>.value(
              value: stubStripeAccountBloc(),
            ),
          ],
          child: const TripOwnerDetailScreen(announcementId: 'ann-trip-001'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockAnnouncementBloc annBloc;
  late _MockBidBloc bidBloc;
  late _MockCancellationBloc cancelBloc;
  late _MockAuthBloc authBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidListRequested('fallback'));
  });

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    cancelBloc = _MockCancellationBloc();
    authBloc = _MockAuthBloc();
    analytics = _MockAnalyticsService();

    // Par défaut, non-propriétaire (aucun utilisateur authentifié résolu) —
    // seuls les tests dédiés au bouton "Arrivé à destination" surchargent cet
    // état pour simuler le propriétaire du trajet.
    when(() => authBloc.state).thenReturn(const AuthInitial());
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    whenListen(
      bidBloc,
      Stream<BidState>.value(BidListLoaded(const [])),
      initialState: BidListLoaded(const []),
    );
    when(() => cancelBloc.state).thenReturn(CancellationInitial());
    whenListen(
      cancelBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    annBloc.close();
    bidBloc.close();
    cancelBloc.close();
    authBloc.close();
  });

  testWidgets('affiche l\'AppBar Trajet, le bouton bug et le corridor', (
    tester,
  ) async {
    final announcement = _makeAnnouncement();
    when(
      () => annBloc.state,
    ).thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
    );
    await tester.pumpAndSettle();

    expect(find.byType(DonyAppBar), findsOneWidget);
    expect(find.text('Trajet'), findsOneWidget);
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
    // Corridor rendu par AnnouncementDetailBody.
    expect(find.text('Paris → Dakar'), findsOneWidget);
  });

  testWidgets(
    'affiche un skeleton quand le détail charge sans annonce initiale',
    (tester) async {
      when(() => annBloc.state).thenReturn(AnnouncementLoading());
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementLoading()),
        initialState: AnnouncementLoading(),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pump();

      expect(find.byType(DonyDetailSkeleton), findsOneWidget);
    },
  );

  testWidgets('shows arrival button when all active bids are IN_TRANSIT', (
    tester,
  ) async {
    final announcement = _makeAnnouncement();
    when(
      () => annBloc.state,
    ).thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_owner),
    );

    final bids = [_makeBid(status: 'IN_TRANSIT')];
    when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
    whenListen(
      bidBloc,
      Stream<BidState>.value(BidListLoaded(bids)),
      initialState: BidListLoaded(bids),
    );

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrivé à destination'), findsOneWidget);
  });

  testWidgets('hides arrival button when a bid is still HANDED_OVER', (
    tester,
  ) async {
    final announcement = _makeAnnouncement();
    when(
      () => annBloc.state,
    ).thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_owner),
    );

    final bids = [_makeBid(status: 'HANDED_OVER')];
    when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
    whenListen(
      bidBloc,
      Stream<BidState>.value(BidListLoaded(bids)),
      initialState: BidListLoaded(bids),
    );

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrivé à destination'), findsNothing);
  });

  testWidgets(
    'reloads bids after AnnouncementTripArrived so the CTA can switch mode',
    (tester) async {
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.fromIterable([
          AnnouncementDetailLoaded(announcement),
          AnnouncementTripArrived(announcement),
        ]),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );

      final bids = [_makeBid(status: 'IN_TRANSIT')];
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        Stream<BidState>.value(BidListLoaded(bids)),
        initialState: BidListLoaded(bids),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      // Régression I9(a) : sans le refresh, AnnouncementTripArrived ne
      // déclenche aucun BidListRequested, le bloc bids reste figé sur
      // IN_TRANSIT et le CTA rediraffiche "Arrivé à destination" au lieu de
      // basculer vers l'édition des instructions.
      verify(
        () => bidBloc.add(
          any(
            that: isA<BidListRequested>().having(
              (e) => e.announcementId,
              'announcementId',
              'ann-trip-001',
            ),
          ),
        ),
      ).called(1);
    },
  );

  // ── Régression ARRIVED : le CTA doit survivre au marquage ────────────────────
  // Avant le fix, ARRIVED n'était pas un statut « actif » : la liste des bids
  // actifs devenait vide et le bouton disparaissait définitivement, rendant les
  // instructions de retrait non éditables.
  testWidgets(
    'tous les colis ARRIVED → bouton "Modifier les instructions de retrait"',
    (tester) async {
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );

      final bids = [_makeBid(status: 'ARRIVED')];
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        Stream<BidState>.value(BidListLoaded(bids)),
        initialState: BidListLoaded(bids),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.text('Modifier les instructions de retrait'), findsOneWidget);
      expect(find.text('Arrivé à destination'), findsNothing);
    },
  );

  group('tripArrivalCtaFor', () {
    test('tous IN_TRANSIT → markArrived', () {
      expect(
        tripArrivalCtaFor([_makeBid(status: 'IN_TRANSIT')]),
        TripArrivalCta.markArrived,
      );
    });
    test('tous ARRIVED → editInstructions', () {
      expect(
        tripArrivalCtaFor([_makeBid(status: 'ARRIVED')]),
        TripArrivalCta.editInstructions,
      );
    });
    test('ARRIVED restant + COMPLETED → editInstructions', () {
      expect(
        tripArrivalCtaFor([
          _makeBid(status: 'ARRIVED'),
          _makeBid(status: 'COMPLETED'),
        ]),
        TripArrivalCta.editInstructions,
      );
    });
    test('un colis encore HANDED_OVER → aucun CTA', () {
      expect(
        tripArrivalCtaFor([
          _makeBid(status: 'HANDED_OVER'),
          _makeBid(status: 'IN_TRANSIT'),
        ]),
        isNull,
      );
    });
    test('aucun colis actif → aucun CTA', () {
      expect(tripArrivalCtaFor([_makeBid(status: 'COMPLETED')]), isNull);
      expect(tripArrivalCtaFor(const []), isNull);
    });
  });
}
