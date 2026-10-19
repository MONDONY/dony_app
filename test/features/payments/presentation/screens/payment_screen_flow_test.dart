import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockLocalAuth extends Mock implements LocalAuthService {}

class _MockBox extends Mock implements Box<dynamic> {}

class _MockGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockErrorReporting extends Mock implements ErrorReportingService {}

class _FakeBid extends Mock implements BidModel {}

const _helpJson = '{"schemaVersion": 1, "socialLinks": [], "tutorials": []}';

class _StaticSource implements HelpCenterConfigSource {
  const _StaticSource();

  @override
  String get activatedJson => _helpJson;

  @override
  Future<String?> fetchAndActivate() async => _helpJson;
}

final _l = lookupAppLocalizations(AppL10n.fr);

BidModel _bid({
  BidPricingMode pricingMode = BidPricingMode.kg,
  String? recipientName,
}) => BidModel(
  id: 'bid-9',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 5,
  pricePerKg: 6,
  pricingMode: pricingMode,
  recipientName: recipientName,
  status: 'ACCEPTED',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  late _MockPaymentBloc paymentBloc;
  late _MockLocalAuth auth;
  late _MockBox prefs;
  late _MockGateway gateway;
  late _MockBidRepository bidRepository;
  late List<String> routes;

  setUp(() {
    paymentBloc = _MockPaymentBloc();
    auth = _MockLocalAuth();
    prefs = _MockBox();
    gateway = _MockGateway();
    bidRepository = _MockBidRepository();
    routes = [];
    when(
      () => prefs.get(
        HiveService.kBiometricEnabled,
        defaultValue: any(named: 'defaultValue'),
      ),
    ).thenReturn(false);
    when(() => auth.isPinSet()).thenAnswer((_) async => false);
    when(() => gateway.isPlatformPaySupported()).thenAnswer((_) async => false);
    when(() => gateway.confirmPayPal(any())).thenAnswer((_) async {});
    when(
      () => bidRepository.confirmPayment(any()),
    ).thenAnswer((_) async => _FakeBid());
    getIt
      ..registerSingleton<AnalyticsService>(
        makeDisabledAnalytics(MockAnalyticsBackend()),
      )
      ..registerSingleton<PaymentGateway>(gateway)
      ..registerSingleton<PaymentRepository>(_MockPaymentRepository())
      ..registerSingleton<ErrorReportingService>(_MockErrorReporting())
      ..registerSingleton<BidRepository>(bidRepository);
  });

  tearDown(() async {
    await getIt.reset();
    await paymentBloc.close();
  });

  Widget host(BidModel bid) => MaterialApp.router(
    locale: AppL10n.fr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<PaymentBloc>.value(value: paymentBloc),
              BlocProvider<HelpCenterBloc>(
                create: (_) => HelpCenterBloc(
                  HelpCenterRepository(
                    const _StaticSource(),
                    fallbackJsonLoader: () async => _helpJson,
                  ),
                  makeDisabledAnalytics(MockAnalyticsBackend()),
                ),
              ),
            ],
            child: PaymentScreen(
              bid: bid,
              localAuthService: auth,
              userPrefs: prefs,
            ),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) {
            routes.add('/home');
            return const Scaffold(body: Text('HOME'));
          },
        ),
      ],
    ),
  );

  testWidgets('sans grille ni total serveur : taux unique courant', (
    tester,
  ) async {
    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentInitial(),
    );
    await tester.pumpWidget(host(_bid()));
    await tester.pumpAndSettle();

    // 30 € net × 1,12 = 33,60 €.
    expect(
      find.text(_l.paymentPayButtonLabel(formatPriceIn(33.6, 'EUR'))),
      findsOneWidget,
    );
  });

  testWidgets('erreur de paiement : bandeau avec le message traduit', (
    tester,
  ) async {
    const error = TimeoutException();
    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentError(error),
    );
    await tester.pumpWidget(host(_bid()));
    await tester.pumpAndSettle();

    expect(
      find.text(ErrorPresenter.resolve(error, l10n: _l).message),
      findsOneWidget,
    );
  });

  testWidgets('tarif forfaitaire (grille) : ligne « Type » forfait', (
    tester,
  ) async {
    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentInitial(),
    );
    await tester.pumpWidget(host(_bid(pricingMode: BidPricingMode.grid)));
    await tester.pumpAndSettle();

    expect(find.text(_l.paymentSummaryTypeLabel), findsOneWidget);
    expect(find.text(_l.paymentSummaryFlatRateValue), findsOneWidget);
    expect(find.text(_l.paymentSummaryWeightLabel), findsNothing);
  });

  testWidgets('escrow confirmé : le CTA ramène à l\'accueil', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentEscrowPending(33.6),
    );
    await tester.pumpWidget(host(_bid()));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text(_l.paymentEscrowCta));
    await tester.pumpAndSettle();
    expect(routes, ['/home']);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets(
    'feuille prête : DonyPaymentSheet au nom du destinataire, PayPal réussi '
    '→ confirmation backend puis PaymentSheetCompleted',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      whenListen<PaymentState>(
        paymentBloc,
        Stream.fromIterable([
          const PaymentSheetReady(
            clientSecret: 'pi_1_secret_x',
            amount: 30,
            commissionAmount: 3.6,
            paymentId: 'pay-1',
            paymentMethodTypes: ['paypal'],
          ),
        ]),
        initialState: const PaymentInitial(),
      );
      await tester.pumpWidget(host(_bid(recipientName: 'Awa Diop')));
      await tester.pumpAndSettle();

      expect(find.text(_l.paymentContextRecipient('Awa Diop')), findsOneWidget);

      await tester.tap(find.byKey(const Key('paymentSheetPayPalButton')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      verify(() => gateway.confirmPayPal('pi_1_secret_x')).called(1);
      verify(() => bidRepository.confirmPayment('bid-9')).called(1);
      verify(() => paymentBloc.add(const PaymentSheetCompleted())).called(1);
    },
  );

  testWidgets('feuille prête sans destinataire : libellé par défaut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen<PaymentState>(
      paymentBloc,
      Stream.fromIterable([
        const PaymentSheetReady(
          clientSecret: 'pi_2_secret_x',
          amount: 30,
          commissionAmount: 3.6,
          paymentId: 'pay-2',
          paymentMethodTypes: ['paypal'],
        ),
      ]),
      initialState: const PaymentInitial(),
    );
    await tester.pumpWidget(host(_bid(recipientName: '  ')));
    await tester.pumpAndSettle();

    expect(find.text(_l.paymentContextDefault), findsOneWidget);
  });
}
