import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockNegotiationRepository extends Mock implements NegotiationRepository {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPackageRequestFormBloc
    extends MockBloc<PackageRequestFormEvent, PackageRequestFormState>
    implements PackageRequestFormBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockPackageRequestBloc packageBloc;
  late _MockBidBloc bidBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockNegotiationRepository negoRepo;
  late _MockPaymentBloc paymentBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() {
    registerFallbackValue(const FetchMyRequests());
    registerFallbackValue(const BidMyListAutoRefreshRequested());
    registerFallbackValue(const NegotiationListFetchRequested());
  });

  setUp(() {
    packageBloc = _MockPackageRequestBloc();
    bidBloc = _MockBidBloc();
    negoListBloc = _MockNegotiationListBloc();
    negoRepo = _MockNegotiationRepository();
    paymentBloc = _MockPaymentBloc();
    analytics = _MockAnalyticsService();

    when(() => packageBloc.state).thenReturn(PackageRequestState());
    when(() => packageBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestState>.empty());
    whenListen<BidState>(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidInitial(),
    );
    when(() => negoListBloc.state).thenReturn(NegotiationListState());
    when(() => negoListBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationListState>.empty());
    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentInitial(),
    );
    when(() => negoRepo.findMine()).thenAnswer((_) async => []);

    when(() => analytics.logScreen(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});

    // Unregister and re-register all needed dependencies
    _unregister<PackageRequestBloc>();
    _unregister<BidBloc>();
    _unregister<NegotiationListBloc>();
    _unregister<NegotiationRepository>();
    _unregister<PackageRequestFormBloc>();
    _unregister<AnalyticsService>();
    _unregister<ShipmentFilterCubit>();
    _unregister<RequestFilterCubit>();
    _unregister<NegotiationFilterCubit>();
    _unregister<EnvoisRefreshNotifier>();

    getIt.registerFactory<PackageRequestBloc>(() => packageBloc);
    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerFactory<NegotiationListBloc>(() => negoListBloc);
    getIt.registerLazySingleton<NegotiationRepository>(() => negoRepo);
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerFactory<ShipmentFilterCubit>(() => ShipmentFilterCubit(analytics));
    getIt.registerFactory<RequestFilterCubit>(() => RequestFilterCubit());
    getIt.registerFactory<NegotiationFilterCubit>(() => NegotiationFilterCubit());
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(() => EnvoisRefreshNotifier());

    final formBloc = _MockPackageRequestFormBloc();
    when(() => formBloc.state).thenReturn(const PackageRequestFormState());
    when(() => formBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestFormState>.empty());
    getIt.registerFactory<PackageRequestFormBloc>(() => formBloc);
  });

  tearDown(() async {
    _unregister<PackageRequestBloc>();
    _unregister<BidBloc>();
    _unregister<NegotiationListBloc>();
    _unregister<NegotiationRepository>();
    _unregister<PackageRequestFormBloc>();
    _unregister<AnalyticsService>();
    _unregister<ShipmentFilterCubit>();
    _unregister<RequestFilterCubit>();
    _unregister<NegotiationFilterCubit>();
    _unregister<EnvoisRefreshNotifier>();
  });

  Widget wrap({String kycStatus = 'NOT_STARTED'}) {
    final authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(
      AuthAuthenticated(
        UserModel(
          id: 'u1',
          roles: const ['SENDER'],
          kycStatus: kycStatus,
          status: 'ACTIVE',
        ),
      ),
    );
    when(() => authBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());

    final kycBloc = _MockKycBloc();
    when(() => kycBloc.state).thenReturn(const KycInitial());
    when(() => kycBloc.stream)
        .thenAnswer((_) => const Stream<KycState>.empty());

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<KycBloc>.value(value: kycBloc),
        BlocProvider<PaymentBloc>.value(value: paymentBloc),
      ],
      child: const MaterialApp(home: EnvoyerHubScreen()),
    );
  }

  group('EnvoyerHubScreen', () {
    testWidgets('rend le titre "Envoyer"', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Envoyer'), findsOneWidget);
    });

    testWidgets('rend les 3 onglets Demandes / Envois / Négos', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Demandes'), findsWidgets);
      expect(find.textContaining('Envois'), findsWidgets);
      expect(find.textContaining('Négos'), findsWidgets);
    });

    testWidgets('rend le bouton Publier (icône +)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });

    testWidgets(
        'tap "+Nouveau" affiche le portail KYC si kycStatus=NOT_STARTED',
        (tester) async {
      await tester.pumpWidget(wrap(kycStatus: 'NOT_STARTED'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vérification requise'), findsOneWidget);
      // Drain any remaining animation timers before widget disposal
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets(
        'tap "+Nouveau" affiche le portail KYC si kycStatus=REJECTED',
        (tester) async {
      await tester.pumpWidget(wrap(kycStatus: 'REJECTED'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vérification requise'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets(
        'tap "+Nouveau" affiche le portail KYC si kycStatus=PENDING',
        (tester) async {
      await tester.pumpWidget(wrap(kycStatus: 'PENDING'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vérification requise'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets(
        'tap "+Nouveau" ne montre pas le portail KYC si kycStatus=VERIFIED',
        (tester) async {
      await tester.pumpWidget(wrap(kycStatus: 'VERIFIED'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      // Ne pas pumpAndSettle : le wizard (VERIFIED path) tente de résoudre
      // CitySearchBloc non enregistré dans ce test.
      expect(find.text('Vérification requise'), findsNothing);
    });

    testWidgets(
        'tap "+Nouveau" ne montre pas le portail KYC si AuthProfileUpdated VERIFIED',
        (tester) async {
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(
        AuthProfileUpdated(
          UserModel(
            id: 'u1',
            roles: const ['SENDER'],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
          ),
        ),
      );
      when(() => authBloc.stream)
          .thenAnswer((_) => const Stream<AuthState>.empty());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<PaymentBloc>.value(value: paymentBloc),
          ],
          child: const MaterialApp(home: EnvoyerHubScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      expect(find.text('Vérification requise'), findsNothing);
    });
  });
}

void _unregister<T extends Object>() {
  if (getIt.isRegistered<T>()) {
    getIt.unregister<T>();
  }
}
