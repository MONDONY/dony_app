import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_payment_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_pay_button.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/error_reporting_test_doubles.dart';
import '../../../../../helpers/mock_analytics_backend.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

BidSupplement _supplement({
  BidSupplementStatus status = BidSupplementStatus.proposed,
  String? rail = 'STRIPE',
}) => BidSupplement(
  id: 'sup-1',
  status: status,
  rail: rail,
  grossAmount: 16.8,
  blocksHandover: status.isOpen,
);

BidModel _bid(
  BidSupplement? supplement, {
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  paymentMethod: paymentMethod,
  supplement: supplement,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _checkout = SupplementCheckout(
  rail: 'STRIPE',
  clientSecret: 'pi_1_secret_2',
  paymentMethodTypes: ['card', 'paypal'],
  amount: 16.8,
  currency: 'EUR',
);

Matcher _reloadOf(String bidId) =>
    isA<BidDetailRequested>().having((e) => e.bidId, 'bidId', bidId);

/// Texte affiché, espaces insécables du format monétaire lues comme des
/// espaces simples.
Finder _txt(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText())?.replaceAll(
            RegExp('[\\u00A0\\u202F]'),
            ' ',
          ) ==
          text,
);

/// Feuille de paiement simulée : enregistre la configuration, puis paie
/// ([pay]) ou se ferme sans payer.
class _FakeSheet {
  _FakeSheet({this.pay = true});

  final bool pay;
  PaymentSheetConfig? config;
  String? contextLabel;
  int calls = 0;

  Future<void> present(
    BuildContext context, {
    required PaymentSheetConfig config,
    required String contextLabel,
    required VoidCallback onSuccess,
  }) async {
    calls++;
    this.config = config;
    this.contextLabel = contextLabel;
    // Même ordre que la vraie feuille : `pop`, puis `onSuccess`, puis la
    // future de la feuille se termine.
    if (pay) onSuccess();
  }
}

void main() {
  late _MockRepository repository;
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() async {
    DonySnackbar.clearDedup();
    repository = _MockRepository();
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    registerNoopErrorReporting();
    getIt.registerFactory<SupplementPaymentCubit>(
      () => SupplementPaymentCubit(
        repository,
        analytics,
        errorReporter: getIt<ErrorReportingService>(),
      ),
    );
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(
    WidgetTester tester,
    BidModel bid, {
    Future<bool> Function(BuildContext)? authorize,
    SupplementPaymentSheetPresenter? presentSheet,
    SupplementMobileMoneyOpener? openMobileMoney,
    bool withBidBloc = true,
  }) async {
    final button = SupplementPayButton(
      bid: bid,
      authorize: authorize ?? (_) async => true,
      presentSheet: presentSheet,
      openMobileMoney: openMobileMoney,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: withBidBloc
                ? BlocProvider<BidBloc>.value(value: bidBloc, child: button)
                : button,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('canPay', () {
    test('supplément carte en attente ou en paiement', () {
      expect(SupplementPayButton.canPay(_bid(_supplement())), isTrue);
      expect(
        SupplementPayButton.canPay(
          _bid(_supplement(status: BidSupplementStatus.paymentPending)),
        ),
        isTrue,
      );
    });

    test('rail absent : déduit du moyen de paiement du colis', () {
      expect(SupplementPayButton.canPay(_bid(_supplement(rail: null))), isTrue);
      expect(
        SupplementPayButton.canPay(
          _bid(
            _supplement(rail: null),
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
        isTrue,
      );
      expect(
        SupplementPayButton.canPay(
          _bid(_supplement(rail: null), paymentMethod: BidPaymentMethod.cash),
        ),
        isFalse,
      );
    });

    test('mobile money : bouton (PR A3) ; espèces : pas encore (PR A4)', () {
      expect(
        SupplementPayButton.canPay(_bid(_supplement(rail: 'PAWAPAY'))),
        isTrue,
      );
      expect(
        SupplementPayButton.canPay(_bid(_supplement(rail: 'CASH'))),
        isFalse,
      );
    });

    test('railOf : rail du back, sinon celui du moyen du colis', () {
      expect(
        SupplementPayButton.railOf(_bid(_supplement(rail: 'PAWAPAY'))),
        'PAWAPAY',
      );
      expect(
        SupplementPayButton.railOf(
          _bid(
            _supplement(rail: null),
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
        'PAWAPAY',
      );
      expect(SupplementPayButton.railOf(_bid(null)), 'STRIPE');
      expect(
        SupplementPayButton.railOf(
          _bid(null, paymentMethod: BidPaymentMethod.wave),
        ),
        isNull,
      );
    });

    test('rien sans supplément ni pour un supplément clos ou payé', () {
      expect(SupplementPayButton.canPay(_bid(null)), isFalse);
      for (final status in BidSupplementStatus.values) {
        if (status == BidSupplementStatus.proposed ||
            status == BidSupplementStatus.paymentPending) {
          continue;
        }
        expect(
          SupplementPayButton.canPay(_bid(_supplement(status: status))),
          isFalse,
          reason: status.name,
        );
      }
    });
  });

  testWidgets('libellé « Payer {brut} »', (tester) async {
    await pump(tester, _bid(_supplement()));
    expect(_txt('Payer 16,80 €'), findsOneWidget);
  });

  testWidgets('vérification refusée : rien ne part, message affiché', (
    tester,
  ) async {
    await pump(tester, _bid(_supplement()), authorize: (_) async => false);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();

    expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
    verifyNever(() => repository.accept(any(), any()));
  });

  testWidgets('parcours carte : accept, feuille bid_supplement, confirmation '
      'attendue, relecture du colis', (tester) async {
    final sheet = _FakeSheet();
    when(
      () => repository.accept('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _checkout);
    when(
      () => repository.confirmPayment('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _supplement(status: BidSupplementStatus.paid));
    await pump(tester, _bid(_supplement()), presentSheet: sheet.present);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();
    await tester.pump();

    expect(sheet.calls, 1);
    expect(
      sheet.config,
      const PaymentSheetConfig(
        clientSecret: 'pi_1_secret_2',
        amountEur: 16.8,
        paymentMethodTypes: ['card', 'paypal'],
        analyticsContext: 'bid_supplement',
      ),
    );
    expect(sheet.contextLabel, 'Supplément de prix du colis');
    verify(
      () => backend.capture(AnalyticsEvents.bidSupplementPaymentStarted, {
        'method': 'card',
        'currency': 'EUR',
        'amount_bracket': '<20',
      }),
    ).called(1);
    verify(() => repository.confirmPayment('bid-1', 'sup-1')).called(1);
    verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
    expect(find.text('Supplément payé'), findsOneWidget);
    // Jamais de payment_succeeded en dehors de la feuille.
    verifyNever(() => backend.capture(AnalyticsEvents.paymentSucceeded, any()));
  });

  testWidgets('feuille fermée sans payer : le bouton « Payer » revient, '
      'rien n\'est relu', (tester) async {
    final sheet = _FakeSheet(pay: false);
    when(
      () => repository.accept(any(), any()),
    ).thenAnswer((_) async => _checkout);
    await pump(tester, _bid(_supplement()), presentSheet: sheet.present);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();
    await tester.pump();

    expect(sheet.calls, 1);
    verifyNever(() => repository.confirmPayment(any(), any()));
    verifyNever(() => bidBloc.add(any()));
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('supplement-pay-btn')),
    );
    expect(button.isLoading, isFalse);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('confirmation encore en attente : message neutre, jamais '
      '« payé », colis relu', (tester) async {
    final sheet = _FakeSheet();
    when(
      () => repository.accept(any(), any()),
    ).thenAnswer((_) async => _checkout);
    when(() => repository.confirmPayment(any(), any())).thenAnswer(
      (_) async => _supplement(status: BidSupplementStatus.paymentPending),
    );
    await pump(tester, _bid(_supplement()), presentSheet: sheet.present);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Paiement reçu, confirmation en cours. Le colis se met à jour '
        'dans un instant.',
      ),
      findsOneWidget,
    );
    expect(find.text('Supplément payé'), findsNothing);
    verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
  });

  testWidgets('confirmation en échec : même message neutre, jamais « payé »', (
    tester,
  ) async {
    final sheet = _FakeSheet();
    when(
      () => repository.accept(any(), any()),
    ).thenAnswer((_) async => _checkout);
    when(
      () => repository.confirmPayment(any(), any()),
    ).thenThrow(const ConflictException('d', code: 'payment-busy'));
    await pump(tester, _bid(_supplement()), presentSheet: sheet.present);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Paiement reçu, confirmation en cours. Le colis se met à jour '
        'dans un instant.',
      ),
      findsOneWidget,
    );
    expect(find.text('Supplément payé'), findsNothing);
    verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
  });

  testWidgets('invite d\'autorisation ouverte : bouton désactivé, un double '
      'tap n\'ouvre qu\'une invite ; refus : bouton réactivé', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await pump(
      tester,
      _bid(_supplement()),
      authorize: (_) {
        calls++;
        return pending.future;
      },
    );

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('supplement-pay-btn')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(calls, 1);
    var button = tester.widget<DonyButton>(
      find.byKey(const Key('supplement-pay-btn')),
    );
    expect(button.isLoading, isTrue);
    expect(button.onPressed, isNull);

    pending.complete(false);
    await tester.pump();
    await tester.pump();

    button = tester.widget<DonyButton>(
      find.byKey(const Key('supplement-pay-btn')),
    );
    expect(button.isLoading, isFalse);
    expect(button.onPressed, isNotNull);
    verifyNever(() => repository.accept(any(), any()));
  });

  testWidgets('déjà payé : relecture directe, sans feuille', (tester) async {
    final sheet = _FakeSheet();
    when(() => repository.accept(any(), any())).thenAnswer(
      (_) async => const SupplementCheckout(amount: 16.8, currency: 'EUR'),
    );
    await pump(tester, _bid(_supplement()), presentSheet: sheet.present);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();

    expect(sheet.calls, 0);
    verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
    expect(find.text('Supplément payé'), findsOneWidget);
  });

  testWidgets('erreur du serveur : message du catalogue et relecture', (
    tester,
  ) async {
    final sheet = _FakeSheet();
    when(() => repository.accept(any(), any())).thenThrow(
      const ConflictException('d', code: 'supplement-payment-processing'),
    );
    await pump(tester, _bid(_supplement()), presentSheet: sheet.present);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();

    expect(sheet.calls, 0);
    expect(find.text('Paiement en cours'), findsOneWidget);
    verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
  });

  testWidgets('hors de l\'écran de détail : pas de BidBloc, rien ne plante', (
    tester,
  ) async {
    when(() => repository.accept(any(), any())).thenAnswer(
      (_) async => const SupplementCheckout(amount: 16.8, currency: 'EUR'),
    );
    await pump(tester, _bid(_supplement()), withBidBloc: false);

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Supplément payé'), findsOneWidget);
  });

  testWidgets('autorisation par défaut : requirePaymentAuth (ni biométrie '
      'ni PIN, le paiement suit son cours)', (tester) async {
    final auth = _MockLocalAuthService();
    final hive = MockHiveService();
    final box = MockBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => box.get(HiveService.kBiometricEnabled, defaultValue: false),
    ).thenReturn(false);
    when(() => auth.isPinSet()).thenAnswer((_) async => false);
    getIt
      ..registerSingleton<LocalAuthService>(auth)
      ..registerSingleton<HiveService>(hive);
    when(() => repository.accept(any(), any())).thenAnswer(
      (_) async => const SupplementCheckout(amount: 16.8, currency: 'EUR'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<BidBloc>.value(
            value: bidBloc,
            child: SupplementPayButton(bid: _bid(_supplement())),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('supplement-pay-btn')));
    await tester.pump();
    await tester.pump();

    verify(() => auth.isPinSet()).called(1);
    verify(() => repository.accept('bid-1', 'sup-1')).called(1);
  });

  group('avec la vraie feuille de paiement', () {
    late _MockPaymentGateway gateway;
    late _MockPaymentRepository paymentRepository;

    setUp(() {
      gateway = _MockPaymentGateway();
      paymentRepository = _MockPaymentRepository();
      when(
        () => gateway.isPlatformPaySupported(),
      ).thenAnswer((_) async => false);
      when(
        () => gateway.initPaymentSheet(
          clientSecret: any(named: 'clientSecret'),
          customerId: any(named: 'customerId'),
          customerEphemeralKeySecret: any(named: 'customerEphemeralKeySecret'),
        ),
      ).thenAnswer((_) async {});
      when(() => gateway.presentPaymentSheet()).thenAnswer((_) async {});
      when(() => paymentRepository.createEphemeralKey()).thenAnswer(
        (_) async => const EphemeralKeyModel(
          ephemeralKeySecret: 'ek_test',
          customerId: 'cus_test',
        ),
      );
      getIt
        ..registerFactory<PaymentGateway>(() => gateway)
        ..registerFactory<PaymentRepository>(() => paymentRepository)
        ..registerSingleton<AnalyticsService>(analytics);
      when(
        () => repository.accept(any(), any()),
      ).thenAnswer((_) async => _checkout);
      when(
        () => repository.confirmPayment(any(), any()),
      ).thenAnswer((_) async => _supplement(status: BidSupplementStatus.paid));
    });

    testWidgets('carte payée : confirmation attendue, paiement tracé une '
        'seule fois avec context bid_supplement', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, _bid(_supplement()));

      await tester.tap(find.byKey(const Key('supplement-pay-btn')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byKey(const Key('paymentSheetCardButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('paymentSheetCardButton')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      verify(() => repository.confirmPayment('bid-1', 'sup-1')).called(1);
      verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
      final captured = verify(
        () => backend.capture(AnalyticsEvents.paymentSucceeded, captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      expect(
        captured.single as Map<String, Object>,
        allOf(
          containsPair('context', 'bid_supplement'),
          containsPair('currency', 'EUR'),
        ),
      );
    });
  });

  group('mobile money (PR A3)', () {
    final mmBid = _bid(
      _supplement(rail: 'PAWAPAY'),
      paymentMethod: BidPaymentMethod.mobileMoney,
    );
    const route = '/bids/bid-1/supplements/sup-1/mobile-money/awaiting';
    SupplementCheckout mmCheckout({
      BidSupplementStatus status = BidSupplementStatus.paymentPending,
    }) => SupplementCheckout(
      supplement: _supplement(rail: 'PAWAPAY', status: status),
      rail: 'PAWAPAY',
      amount: 16.8,
      currency: 'EUR',
    );

    testWidgets('icône téléphone et libellé « Payer {brut} »', (tester) async {
      await pump(tester, mmBid);
      expect(_txt('Payer 16,80 €'), findsOneWidget);
      final button = tester.widget<DonyButton>(
        find.byKey(const Key('supplement-pay-btn')),
      );
      expect(button.iconAsset, 'smartphone');
    });

    testWidgets('requirePaymentAuth, puis accept, puis l\'écran d\'attente '
        'du supplément ; payé : colis relu, pas de second message', (
      tester,
    ) async {
      final order = <String>[];
      when(() => repository.accept('bid-1', 'sup-1')).thenAnswer((_) async {
        order.add('accept');
        return mmCheckout();
      });
      String? opened;
      await pump(
        tester,
        mmBid,
        authorize: (_) async {
          order.add('auth');
          return true;
        },
        openMobileMoney: (_, r) async {
          order.add('open');
          opened = r;
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('supplement-pay-btn')));
      await tester.pump();
      await tester.pump();

      expect(order, ['auth', 'accept', 'open']);
      expect(opened, route);
      verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
      // L'écran d'attente a déjà annoncé « Supplément payé » en se fermant.
      expect(find.text('Supplément payé'), findsNothing);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementPaymentStarted, {
          'method': 'mobile_money',
          'currency': 'EUR',
          'amount_bracket': '<20',
        }),
      ).called(1);
      // Le paiement lui-même est tracé par MobileMoneyPaymentBloc.
      verifyNever(
        () => backend.capture(AnalyticsEvents.paymentSucceeded, any()),
      );
      verifyNever(() => repository.confirmPayment(any(), any()));
    });

    testWidgets('retour sans paiement : message neutre, colis relu, bouton '
        'réactivé', (tester) async {
      when(
        () => repository.accept(any(), any()),
      ).thenAnswer((_) async => mmCheckout());
      await pump(tester, mmBid, openMobileMoney: (_, _) async => null);

      await tester.tap(find.byKey(const Key('supplement-pay-btn')));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Paiement du supplément pas encore confirmé.'),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
      final button = tester.widget<DonyButton>(
        find.byKey(const Key('supplement-pay-btn')),
      );
      expect(button.isLoading, isFalse);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('vérification refusée : ni accept ni écran d\'attente', (
      tester,
    ) async {
      var opened = false;
      await pump(
        tester,
        mmBid,
        authorize: (_) async => false,
        openMobileMoney: (_, _) async {
          opened = true;
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('supplement-pay-btn')));
      await tester.pump();

      verifyNever(() => repository.accept(any(), any()));
      expect(opened, isFalse);
    });

    testWidgets('déjà payé à l\'acceptation : relecture, pas d\'écran '
        'd\'attente', (tester) async {
      when(
        () => repository.accept(any(), any()),
      ).thenAnswer((_) async => mmCheckout(status: BidSupplementStatus.paid));
      var opened = false;
      await pump(
        tester,
        mmBid,
        openMobileMoney: (_, _) async {
          opened = true;
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('supplement-pay-btn')));
      await tester.pump();

      expect(opened, isFalse);
      verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
    });

    testWidgets('ouverture par défaut : GoRouter pousse la route d\'attente '
        'du supplément et lit son résultat', (tester) async {
      when(
        () => repository.accept(any(), any()),
      ).thenAnswer((_) async => mmCheckout());
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: BlocProvider<BidBloc>.value(
                value: bidBloc,
                child: SupplementPayButton(
                  bid: mmBid,
                  authorize: (_) async => true,
                ),
              ),
            ),
          ),
          GoRoute(
            path:
                '/bids/:bidId/supplements/:supplementId/mobile-money/awaiting',
            builder: (context, state) => Scaffold(
              body: TextButton(
                key: const Key('fake-awaiting-paid'),
                onPressed: () => context.pop(true),
                child: Text(
                  '${state.pathParameters['bidId']}/'
                  '${state.pathParameters['supplementId']}',
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      await tester.tap(find.byKey(const Key('supplement-pay-btn')));
      await tester.pumpAndSettle();

      expect(find.text('bid-1/sup-1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fake-awaiting-paid')));
      await tester.pumpAndSettle();

      verify(() => bidBloc.add(any(that: _reloadOf('bid-1')))).called(1);
      expect(find.byKey(const Key('supplement-pay-btn')), findsOneWidget);
    });
  });
}
