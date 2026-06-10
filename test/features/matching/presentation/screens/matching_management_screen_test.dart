import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/matching_management_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockNegotiationRepository extends Mock implements NegotiationRepository {
}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

UserModel _makeUser({
  bool isTraveler = false,
  bool isProAccount = false,
}) {
  return UserModel(
    id: 'u1',
    roles: [if (isTraveler) 'TRAVELER' else 'SENDER'],
    kycStatus: 'APPROVED',
    status: 'ACTIVE',
    isProAccount: isProAccount,
  );
}

void main() {
  late _MockAuthBloc authBloc;
  late _MockAnnouncementBloc announcementBloc;
  late _MockBidBloc bidBloc;
  late _MockPackageRequestBloc packageBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockNegotiationRepository negoRepo;
  late _MockPaymentBloc paymentBloc;
  late _MockAnalytics analytics;
  late _MockAnnouncementRepository announcementRepo;

  setUp(() {
    authBloc = _MockAuthBloc();
    announcementBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    packageBloc = _MockPackageRequestBloc();
    negoListBloc = _MockNegotiationListBloc();
    negoRepo = _MockNegotiationRepository();
    paymentBloc = _MockPaymentBloc();
    analytics = _MockAnalytics();
    announcementRepo = _MockAnnouncementRepository();

    when(() => paymentBloc.state).thenReturn(PaymentInitial());
    when(() => paymentBloc.stream)
        .thenAnswer((_) => const Stream<PaymentState>.empty());
    when(() => analytics.logScreen(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream)
        .thenAnswer((_) => const Stream<BidState>.empty());
    when(() => packageBloc.state).thenReturn(PackageRequestState());
    when(() => packageBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestState>.empty());
    when(() => negoListBloc.state).thenReturn(NegotiationListState());
    when(() => negoListBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationListState>.empty());
    when(() => negoRepo.findMine()).thenAnswer((_) async => []);
    when(() => announcementRepo.getTripsSummary()).thenAnswer(
      (_) async => const TripsSummaryModel(
          activeTrips: 0, kgSoldThisMonth: 0, revenueThisMonth: 0),
    );

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<NegotiationListBloc>()) {
      getIt.unregister<NegotiationListBloc>();
    }
    if (getIt.isRegistered<NegotiationRepository>()) {
      getIt.unregister<NegotiationRepository>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerFactory<PackageRequestBloc>(() => packageBloc);
    getIt.registerFactory<NegotiationListBloc>(() => negoListBloc);
    getIt.registerLazySingleton<NegotiationRepository>(() => negoRepo);

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<ShipmentFilterCubit>()) {
      getIt.unregister<ShipmentFilterCubit>();
    }
    if (getIt.isRegistered<RequestFilterCubit>()) {
      getIt.unregister<RequestFilterCubit>();
    }
    if (getIt.isRegistered<NegotiationFilterCubit>()) {
      getIt.unregister<NegotiationFilterCubit>();
    }
    if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.unregister<EnvoisRefreshNotifier>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerFactory<ShipmentFilterCubit>(
        () => ShipmentFilterCubit(analytics));
    getIt.registerFactory<RequestFilterCubit>(() => RequestFilterCubit());
    getIt.registerFactory<NegotiationFilterCubit>(
        () => NegotiationFilterCubit());
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(
        () => EnvoisRefreshNotifier());

    // New cubits required by AnnouncementListScreen (Task 9)
    if (getIt.isRegistered<TripsSummaryCubit>()) {
      getIt.unregister<TripsSummaryCubit>();
    }
    if (getIt.isRegistered<TripFilterCubit>()) {
      getIt.unregister<TripFilterCubit>();
    }
    getIt.registerFactory<TripsSummaryCubit>(
        () => TripsSummaryCubit(announcementRepo));
    getIt.registerFactory<TripFilterCubit>(
        () => TripFilterCubit(analytics));
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<NegotiationListBloc>()) {
      getIt.unregister<NegotiationListBloc>();
    }
    if (getIt.isRegistered<NegotiationRepository>()) {
      getIt.unregister<NegotiationRepository>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<ShipmentFilterCubit>()) {
      getIt.unregister<ShipmentFilterCubit>();
    }
    if (getIt.isRegistered<RequestFilterCubit>()) {
      getIt.unregister<RequestFilterCubit>();
    }
    if (getIt.isRegistered<NegotiationFilterCubit>()) {
      getIt.unregister<NegotiationFilterCubit>();
    }
    if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.unregister<EnvoisRefreshNotifier>();
    }
    if (getIt.isRegistered<TripsSummaryCubit>()) {
      getIt.unregister<TripsSummaryCubit>();
    }
    if (getIt.isRegistered<TripFilterCubit>()) {
      getIt.unregister<TripFilterCubit>();
    }
  });

  Widget wrap(UserModel? user) {
    final state = user != null
        ? AuthAuthenticated(user)
        : const AuthInitial();
    when(() => authBloc.state).thenReturn(state);
    when(() => authBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<PaymentBloc>.value(value: paymentBloc),
        ],
        child: const MatchingManagementScreen(),
      ),
    );
  }

  group('MatchingManagementScreen — composition par profil (Phase 2)', () {
    testWidgets('pur expéditeur → EnvoyerHubScreen, aucune pill "Mes trajets"',
        (tester) async {
      await tester.pumpWidget(wrap(_makeUser(isTraveler: false)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
      expect(find.byType(AnnouncementListScreen), findsNothing);
      // No "Mes trajets" pill for a pure sender
      expect(find.byKey(const Key('show-trips-pill')), findsNothing);
    });

    testWidgets(
        'voyageur occasionnel → EnvoyerHubScreen + pill "Mes trajets"',
        (tester) async {
      await tester
          .pumpWidget(wrap(_makeUser(isTraveler: true, isProAccount: false)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
      expect(find.byType(AnnouncementListScreen), findsNothing);
      // SecondaryActivityEntry replaced by HeaderPill (show-trips-pill key)
      expect(find.byKey(const Key('show-trips-pill')), findsOneWidget);
      expect(find.text('Mes trajets'), findsOneWidget);
    });

    testWidgets(
        'voyageur pro → AnnouncementListScreen (écran primaire trajets)',
        (tester) async {
      // AnnouncementInitial → spinner ; on vérifie juste le type d'écran.
      // L'accès « Envoyer » depuis AnnouncementListScreen passe désormais par
      // un HeaderPill (couvert par announcement_list_screen_test.dart).
      await tester
          .pumpWidget(wrap(_makeUser(isTraveler: true, isProAccount: true)));
      await tester.pump();
      expect(find.byType(AnnouncementListScreen), findsOneWidget);
      expect(find.byType(EnvoyerHubScreen), findsNothing);
    });

    testWidgets('utilisateur non authentifié → EnvoyerHubScreen (senderOnly)',
        (tester) async {
      await tester.pumpWidget(wrap(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
      expect(find.byType(AnnouncementListScreen), findsNothing);
      // No "Mes trajets" pill for unauthenticated user
      expect(find.byKey(const Key('show-trips-pill')), findsNothing);
    });
  });
}
