import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
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

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

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

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Construit un [UserModel] avec les rôles souhaités.
/// Attention : [UserModel.isTraveler] vérifie [roles].contains('TRAVELER'),
/// donc utiliser 'TRAVELER' (sans préfixe ROLE_) pour déclencher le bon layout.
UserModel _makeUser({
  List<String> roles = const ['SENDER'],
  bool isProAccount = false,
}) =>
    UserModel(
      id: 'uid-test',
      phoneNumber: '+33600000000',
      firstName: 'Ibrahima',
      lastName: 'Diallo',
      roles: roles,
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
      isProAccount: isProAccount,
    );

void main() {
  late _MockAnnouncementBloc announcementBloc;
  late _MockBidBloc bidBloc;
  late _MockPackageRequestBloc packageBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockNegotiationRepository negoRepo;
  late _MockPaymentBloc paymentBloc;
  late _MockAnalytics analytics;

  setUp(() {
    announcementBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    packageBloc = _MockPackageRequestBloc();
    negoListBloc = _MockNegotiationListBloc();
    negoRepo = _MockNegotiationRepository();
    paymentBloc = _MockPaymentBloc();
    analytics = _MockAnalytics();

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

    // GetIt — réenregistre les dépendances nécessaires au widget tree.
    void _unregisterIfRegistered<T extends Object>() {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
    }

    _unregisterIfRegistered<AnnouncementBloc>();
    _unregisterIfRegistered<BidBloc>();
    _unregisterIfRegistered<PackageRequestBloc>();
    _unregisterIfRegistered<NegotiationListBloc>();
    _unregisterIfRegistered<NegotiationRepository>();
    _unregisterIfRegistered<AnalyticsService>();
    _unregisterIfRegistered<ShipmentFilterCubit>();
    _unregisterIfRegistered<RequestFilterCubit>();
    _unregisterIfRegistered<NegotiationFilterCubit>();
    _unregisterIfRegistered<EnvoisRefreshNotifier>();

    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerFactory<PackageRequestBloc>(() => packageBloc);
    getIt.registerFactory<NegotiationListBloc>(() => negoListBloc);
    getIt.registerLazySingleton<NegotiationRepository>(() => negoRepo);
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerFactory<ShipmentFilterCubit>(
        () => ShipmentFilterCubit(analytics));
    getIt.registerFactory<RequestFilterCubit>(() => RequestFilterCubit());
    getIt.registerFactory<NegotiationFilterCubit>(
        () => NegotiationFilterCubit());
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(
        () => EnvoisRefreshNotifier());
  });

  tearDown(() {
    void _unregisterIfRegistered<T extends Object>() {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
    }

    _unregisterIfRegistered<AnnouncementBloc>();
    _unregisterIfRegistered<BidBloc>();
    _unregisterIfRegistered<PackageRequestBloc>();
    _unregisterIfRegistered<NegotiationListBloc>();
    _unregisterIfRegistered<NegotiationRepository>();
    _unregisterIfRegistered<AnalyticsService>();
    _unregisterIfRegistered<ShipmentFilterCubit>();
    _unregisterIfRegistered<RequestFilterCubit>();
    _unregisterIfRegistered<NegotiationFilterCubit>();
    _unregisterIfRegistered<EnvoisRefreshNotifier>();
  });

  /// Construit le widget sous test avec un AuthBloc configuré pour [user].
  /// ActiveRoleCubit est fourni pour ne pas casser les widgets qui en ont
  /// besoin dans le sous-arbre (maintenu pour la compatibilité Phases 2-4).
  Widget wrap(UserModel user) {
    final authBloc = _MockAuthBloc();
    final roleCubit = _MockActiveRoleCubit();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    when(() => authBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => roleCubit.state).thenReturn(ActiveRole.sender);
    when(() => roleCubit.stream)
        .thenAnswer((_) => const Stream<ActiveRole>.empty());
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
          // PaymentBloc requis par ShipmentListBody dans l'onglet Envois.
          BlocProvider<PaymentBloc>.value(value: paymentBloc),
        ],
        child: const MatchingManagementScreen(),
      ),
    );
  }

  group('MatchingManagementScreen — modèle additif (Phase 1)', () {
    testWidgets('pur expéditeur → EnvoyerHubScreen, sans bouton Mes trajets',
        (tester) async {
      await tester.pumpWidget(wrap(_makeUser()));
      // Un pump suffit pour monter le hub ; pas de pumpAndSettle car
      // l'onglet Envois affiche un spinner (BidInitial) qui ne se stabilise
      // jamais en test.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
      expect(find.byType(AnnouncementListScreen), findsNothing);
      // Pas de bouton « Mes trajets » pour un expéditeur pur
      expect(find.text('Mes trajets'), findsNothing);
    });

    testWidgets(
        'voyageur occasionnel → EnvoyerHubScreen avec bouton Mes trajets',
        (tester) async {
      await tester.pumpWidget(
        wrap(_makeUser(roles: const ['SENDER', 'TRAVELER'])),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
      expect(find.byType(AnnouncementListScreen), findsNothing);
      // Le bouton « Mes trajets » doit apparaître dans le header
      expect(find.text('Mes trajets'), findsOneWidget);
    });

    testWidgets(
        'voyageur PRO → AnnouncementListScreen avec bouton Envoyer',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          _makeUser(
            roles: const ['SENDER', 'TRAVELER'],
            isProAccount: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AnnouncementListScreen), findsOneWidget);
      expect(find.byType(EnvoyerHubScreen), findsNothing);
      // Le bouton « Envoyer » doit apparaître dans l'AppBar
      expect(find.byKey(const Key('send-parcel-btn')), findsOneWidget);
    });

    testWidgets('ActiveRoleCubit non consommé (pas de régression)', (
      tester,
    ) async {
      // La vue expéditeur est montée même avec ActiveRoleCubit.sender.
      // MatchingManagementScreen lit AuthBloc — pas ActiveRoleCubit.
      await tester.pumpWidget(wrap(_makeUser()));
      await tester.pump();
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
    });
  });
}
