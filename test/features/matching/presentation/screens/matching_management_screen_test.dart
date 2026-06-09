import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/matching_management_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
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

class _MockNegotiationRepository extends Mock
    implements NegotiationRepository {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockAnalytics extends Mock implements AnalyticsService {}

UserModel _userWith({required bool isTraveler}) => UserModel(
  id: 'user-1',
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
  roles: isTraveler ? const ['SENDER', 'TRAVELER'] : const ['SENDER'],
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockAnnouncementBloc announcementBloc;
  late _MockBidBloc bidBloc;
  late _MockPackageRequestBloc packageBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockNegotiationRepository negoRepo;
  late _MockPaymentBloc paymentBloc;
  late _MockAnalytics analytics;

  setUp(() {
    authBloc = _MockAuthBloc();
    announcementBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    packageBloc = _MockPackageRequestBloc();
    negoListBloc = _MockNegotiationListBloc();
    negoRepo = _MockNegotiationRepository();
    paymentBloc = _MockPaymentBloc();
    analytics = _MockAnalytics();
    when(() => paymentBloc.state).thenReturn(PaymentInitial());
    when(
      () => paymentBloc.stream,
    ).thenAnswer((_) => const Stream<PaymentState>.empty());
    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(
      () => announcementBloc.stream,
    ).thenAnswer((_) => const Stream<AnnouncementState>.empty());
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => bidBloc.stream,
    ).thenAnswer((_) => const Stream<BidState>.empty());
    when(() => packageBloc.state).thenReturn(PackageRequestState());
    when(
      () => packageBloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestState>.empty());
    when(() => negoListBloc.state).thenReturn(NegotiationListState());
    when(
      () => negoListBloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationListState>.empty());
    when(() => negoRepo.findMine()).thenAnswer((_) async => []);

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

    // Dépendances tirées par les onglets du nouveau EnvoyerHubScreen.
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
      () => ShipmentFilterCubit(analytics),
    );
    getIt.registerFactory<RequestFilterCubit>(() => RequestFilterCubit());
    getIt.registerFactory<NegotiationFilterCubit>(
      () => NegotiationFilterCubit(),
    );
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(
      () => EnvoisRefreshNotifier(),
    );
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
  });

  Widget wrap({required bool isTraveler}) {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_userWith(isTraveler: isTraveler)),
    );
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          // Fourni globalement par app.dart en prod ; requis ici car l'onglet
          // Envois (ShipmentListBody) écoute PaymentBloc.
          BlocProvider<PaymentBloc>.value(value: paymentBloc),
        ],
        child: const MatchingManagementScreen(),
      ),
    );
  }

  group('MatchingManagementScreen dispatch capacité-aware', () {
    testWidgets('sender (isTraveler=false) → EnvoyerHubScreen rendu', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(isTraveler: false));
      // pas de pumpAndSettle : l'onglet Envois affiche un spinner (BidInitial)
      // qui ne se stabilise jamais ; un pump suffit pour monter le hub.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
      expect(find.byType(AnnouncementListScreen), findsNothing);
    });

    testWidgets('traveler (isTraveler=true) → AnnouncementListScreen rendu', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(isTraveler: true));
      // `pumpAndSettle` évité — AnnouncementListScreen démarre un
      // auto-refresh qui ne se résout jamais en test. Le widget cible est
      // accessible dès le premier pump.
      await tester.pump();
      expect(find.byType(AnnouncementListScreen), findsOneWidget);
      expect(find.byType(EnvoyerHubScreen), findsNothing);
    });
  });
}
