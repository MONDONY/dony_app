import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_preview/cancellation_fee_preview_cubit.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_request_cubit.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_money_breakdown.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAmendmentRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockCancellationRepository extends Mock
    implements CancellationRepository {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

final _l = lookupAppLocalizations(AppL10n.fr);

/// Heure fixe du cubit de l'aperçu (raison « dans 2 jours » stable). Loin
/// dans le futur : la fiche juge « parti » sur l'heure réelle.
final _feeNow = DateTime.utc(2099, 6, 1, 10);

BidModel _bid({
  String status = 'PENDING',
  BidPaymentMethod method = BidPaymentMethod.stripe,
  String? trackingToken,
  bool amendmentAllowed = false,
  BidMoneyBreakdown? moneyBreakdown,
  DateTime? departureAt,
}) => BidModel(
  moneyBreakdown: moneyBreakdown,
  departureAt: departureAt,
  id: 'bid-42',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 4,
  status: status,
  paymentMethod: method,
  trackingToken: trackingToken,
  amendmentAllowed: amendmentAllowed,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() {
    registerFallbackValue(BidCancelRequested('x', actor: 'sender'));
    registerFallbackValue(const ConversationOpenRequested('x'));
    registerFallbackValue(CancelAfterHandoverRequested('x', actor: 'sender'));
  });

  late _MockBidBloc bidBloc;
  late _MockCancellationBloc cancellationBloc;
  late _MockConversationOpenBloc openBloc;
  late _MockCancellationRepository feeRepository;

  setUp(() {
    bidBloc = _MockBidBloc();
    cancellationBloc = _MockCancellationBloc();
    openBloc = _MockConversationOpenBloc();
    feeRepository = _MockCancellationRepository();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => cancellationBloc.state).thenReturn(CancellationInitial());
    when(() => openBloc.state).thenReturn(const ConversationOpenInitial());
    // Back antérieur à l'aperçu des frais : 404, le dialogue reste inchangé.
    when(() => feeRepository.getFeePreview(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/fee-preview'),
        error: const NotFoundException(),
      ),
    );
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<CancellationFeePreviewCubit>(
      () => CancellationFeePreviewCubit(
        feeRepository,
        analytics,
        clock: () => _feeNow,
      ),
    );
  });

  tearDown(getIt.reset);

  Widget wrap(Widget Function(BuildContext) bar) => MaterialApp.router(
    theme: AppTheme.light(),
    locale: AppL10n.fr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<CancellationBloc>.value(value: cancellationBloc),
              BlocProvider<ConversationOpenBloc>.value(value: openBloc),
            ],
            child: Builder(
              builder: (context) => Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: bar(context),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget optionsHost(BidModel bid) => wrap(
    (context) => TextButton(
      onPressed: () => showSenderOptionsSheet(context, bid),
      child: const Text('open-options'),
    ),
  );

  Future<void> openOptions(WidgetTester tester, BidModel bid) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(optionsHost(bid));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-options'));
    await tester.pumpAndSettle();
    expect(find.text(_l.bidDetailOptionsTitle), findsOneWidget);
  }

  group('ConfirmPresenceBar', () {
    testWidgets('tap dispatch BidConfirmPresenceRequested', (tester) async {
      await tester.pumpWidget(
        wrap((_) => ConfirmPresenceBar(bid: _bid(), isLoading: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l.bidDetailConfirmPresence), findsOneWidget);
      await tester.tap(find.byType(DonyButton));
      await tester.pump();

      verify(
        () => bidBloc.add(
          any(
            that: isA<BidConfirmPresenceRequested>().having(
              (e) => e.bidId,
              'bidId',
              'bid-42',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('chargement : aucun événement au tap', (tester) async {
      await tester.pumpWidget(
        wrap((_) => ConfirmPresenceBar(bid: _bid(), isLoading: true)),
      );
      await tester.pump();
      await tester.tap(find.byType(DonyButton), warnIfMissed: false);
      await tester.pump();
      verifyNever(() => bidBloc.add(any()));
    });
  });

  group('showSenderOptionsSheet — entrées et actions', () {
    testWidgets('Contacter le voyageur dispatch ConversationOpenRequested', (
      tester,
    ) async {
      await openOptions(tester, _bid());
      await tester.tap(find.text(_l.bidDetailContactTravelerLabel));
      await tester.pumpAndSettle();

      expect(find.text(_l.bidDetailOptionsTitle), findsNothing);
      verify(
        () => openBloc.add(
          any(
            that: isA<ConversationOpenRequested>().having(
              (e) => e.bidId,
              'bidId',
              'bid-42',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('Partager le suivi : visible avec un jeton, partage le lien', (
      tester,
    ) async {
      final shares = <Object?>[];
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            shares.add(call.arguments);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await openOptions(tester, _bid(trackingToken: 'tok-123'));
      expect(find.text(_l.bidDetailShareTrackingSubtitle), findsOneWidget);
      await tester.tap(find.text(_l.bidDetailShareTracking));
      await tester.pumpAndSettle();

      expect(find.text(_l.bidDetailOptionsTitle), findsNothing);
      expect(shares, hasLength(1));
      expect(shares.single.toString(), contains('tok-123'));
    });

    testWidgets(
      'Modifier mon colis : absent tant que le serveur ne l\'autorise pas',
      (tester) async {
        await openOptions(tester, _bid());
        expect(find.text(_l.amendmentSheetTitle), findsNothing);
      },
    );

    testWidgets(
      'Modifier mon colis : ouvre la feuille quand le serveur l\'autorise',
      (tester) async {
        final repository = _MockAmendmentRepository();
        final analytics = _MockAnalytics();
        when(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        ).thenAnswer((_) async {});
        when(() => repository.options('bid-42')).thenAnswer(
          (_) async => const AmendmentOptions(
            currency: 'EUR',
            availableKg: 6,
            pricePerKgDisplay: 5.13,
            paymentMethods: [BidPaymentMethod.cash],
            minAmount: 1,
            maxAmount: 300,
          ),
        );
        getIt.registerFactory<AmendmentRequestCubit>(
          () => AmendmentRequestCubit(repository, analytics),
        );
        addTearDown(getIt.reset);

        await openOptions(tester, _bid(amendmentAllowed: true));
        expect(find.text(_l.amendmentEntryButton), findsOneWidget);
        await tester.tap(find.text(_l.amendmentSheetTitle));
        await tester.pumpAndSettle();

        expect(find.text(_l.bidDetailOptionsTitle), findsNothing);
        expect(find.text(_l.amendmentSheetTitle), findsOneWidget);
        verify(() => repository.options('bid-42')).called(1);
      },
    );

    testWidgets('sans jeton : pas d\'entrée de partage', (tester) async {
      await openOptions(tester, _bid());
      expect(find.text(_l.bidDetailShareTracking), findsNothing);
    });

    testWidgets('Annuler avant remise : confirmation puis BidCancelRequested', (
      tester,
    ) async {
      await openOptions(tester, _bid(status: 'ACCEPTED'));
      await tester.tap(find.text(_l.bidDetailCancelRefundAutoSubtitle));
      await tester.pumpAndSettle();

      expect(find.text(_l.bidDetailCancelConfirmBody), findsOneWidget);
      await tester.tap(find.text(_l.bidDetailConfirmCancelButton));
      await tester.pumpAndSettle();

      verify(
        () => bidBloc.add(
          any(
            that: isA<BidCancelRequested>().having(
              (e) => e.actor,
              'actor',
              'sender',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('Annuler avant remise puis « Non » : aucun événement', (
      tester,
    ) async {
      await openOptions(tester, _bid());
      await tester.tap(find.text(_l.bidDetailCancelRefundAutoSubtitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l.bidDetailNo));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => bidBloc.add(any()));
    });

    testWidgets(
      'Annuler après remise : confirmation puis CancelAfterHandoverRequested',
      (tester) async {
        await openOptions(tester, _bid(status: 'HANDED_OVER'));
        await tester.tap(
          find.text(_l.bidDetailCancelAfterHandoverOptionSubtitle),
        );
        await tester.pumpAndSettle();

        // Aperçu indisponible (back antérieur, 404) : pas de promesse de
        // remboursement intégral, l'annulation reste possible.
        expect(find.text(_l.bidDetailCancelAfterHandoverTitle), findsOneWidget);
        expect(
          find.text(_l.bidDetailCancelAfterHandoverBodyUnknownFee),
          findsOneWidget,
        );
        expect(find.text(_l.bidDetailCancelAfterHandoverBody), findsNothing);
        await tester.tap(find.text(_l.bidDetailConfirmCancelButton));
        await tester.pumpAndSettle();

        verify(
          () => cancellationBloc.add(
            any(that: isA<CancelAfterHandoverRequested>()),
          ),
        ).called(1);
      },
    );

    testWidgets('Annuler après remise puis « Non » : aucun événement', (
      tester,
    ) async {
      await openOptions(tester, _bid(status: 'HANDED_OVER'));
      await tester.tap(
        find.text(_l.bidDetailCancelAfterHandoverOptionSubtitle),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l.bidDetailNo));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => cancellationBloc.add(any()));
    });

    group('frais d\'annulation', () {
      String eur(double v) =>
          CurrencyFormatter.format(v, SupportedCurrency.eur);
      final departure = _feeNow.add(const Duration(days: 2, hours: 6));

      setUp(() {
        when(() => feeRepository.getFeePreview('bid-42')).thenAnswer(
          (_) async => CancellationFeePreviewModel(
            rate: 0.2,
            fee: 20,
            refundAmount: 80,
            currency: 'EUR',
            nextTierAt: departure.subtract(const Duration(days: 1)),
          ),
        );
      });

      testWidgets(
        'avant remise : aperçu lu à l\'ouverture, bloc des frais, puis '
        'BidCancelRequested',
        (tester) async {
          await openOptions(
            tester,
            _bid(status: 'ACCEPTED', departureAt: departure),
          );
          await tester.tap(find.text(_l.bidDetailCancelRefundAutoSubtitle));
          await tester.pumpAndSettle();

          verify(() => feeRepository.getFeePreview('bid-42')).called(1);
          expect(find.text(_l.bidDetailCancelConfirmBody), findsOneWidget);
          expect(find.text(_l.cancelFeeRetained(eur(20))), findsOneWidget);
          expect(find.text(_l.cancelFeeRefunded(eur(80))), findsOneWidget);
          expect(find.text(_l.cancelFeeReasonDays(2, 20)), findsOneWidget);
          expect(find.text(_l.cancelFeeLaterCostsMore), findsOneWidget);

          await tester.tap(find.text(_l.bidDetailConfirmCancelButton));
          await tester.pumpAndSettle();

          verify(
            () => bidBloc.add(any(that: isA<BidCancelRequested>())),
          ).called(1);
        },
      );

      testWidgets(
        'après remise : plus de « remboursé intégralement », bloc des frais, '
        'puis CancelAfterHandoverRequested',
        (tester) async {
          await openOptions(
            tester,
            _bid(status: 'HANDED_OVER', departureAt: departure),
          );
          await tester.tap(
            find.text(_l.bidDetailCancelAfterHandoverOptionSubtitle),
          );
          await tester.pumpAndSettle();

          verify(() => feeRepository.getFeePreview('bid-42')).called(1);
          expect(
            find.text(_l.bidDetailCancelAfterHandoverTitle),
            findsOneWidget,
          );
          expect(find.text(_l.bidDetailCancelAfterHandoverBody), findsNothing);
          expect(
            find.text(_l.bidDetailCancelAfterHandoverBodyWithFee),
            findsOneWidget,
          );
          expect(find.text(_l.cancelFeeRetained(eur(20))), findsOneWidget);

          await tester.tap(find.text(_l.bidDetailConfirmCancelButton));
          await tester.pumpAndSettle();

          verify(
            () => cancellationBloc.add(
              any(that: isA<CancelAfterHandoverRequested>()),
            ),
          ).called(1);
        },
      );
    });

    // « Supprimer cette demande » a quitté le footer : le menu ⋮ la propose
    // pour ces six statuts. Liste explicite : le test échoue si la constante
    // kEnvoisPasses change sans qu'on l'ait décidé.
    for (final status in const [
      'COMPLETED',
      'REJECTED',
      'CANCELLED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
    ]) {
      testWidgets('$status : Supprimer puis confirmer → BidDeleteRequested', (
        tester,
      ) async {
        await openOptions(tester, _bid(status: status));
        await tester.tap(find.text(_l.bidDetailRemoveFromHistorySubtitle));
        await tester.pumpAndSettle();

        expect(find.text(_l.bidDetailDeleteRequestDefaultBody), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, _l.commonDelete));
        await tester.pumpAndSettle();

        verify(
          () => bidBloc.add(any(that: isA<BidDeleteRequested>())),
        ).called(1);
      });
    }

    for (final status in [
      'PENDING',
      'AWAITING_PAYMENT',
      'ACCEPTED',
      'IN_TRANSIT',
    ]) {
      testWidgets('$status : pas d\'entrée Supprimer', (tester) async {
        await openOptions(tester, _bid(status: status));
        expect(find.text(_l.bidDetailRemoveFromHistorySubtitle), findsNothing);
      });
    }

    testWidgets('Supprimer puis Annuler : aucun événement', (tester) async {
      await openOptions(tester, _bid(status: 'COMPLETED'));
      await tester.tap(find.text(_l.bidDetailRemoveFromHistorySubtitle));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, _l.commonCancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => bidBloc.add(any()));
    });
  });
}
