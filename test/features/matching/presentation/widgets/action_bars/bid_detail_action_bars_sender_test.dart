import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_request_cubit.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
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

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

final _l = lookupAppLocalizations(AppL10n.fr);

BidModel _bid({
  String status = 'PENDING',
  BidPaymentMethod method = BidPaymentMethod.stripe,
  String? trackingToken,
  bool amendmentAllowed = false,
}) => BidModel(
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

PaymentModel _payment(PaymentStatus status) => PaymentModel(
  id: 'pay-1',
  bidId: 'bid-42',
  amount: 40,
  commissionAmount: 4.8,
  status: status,
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
  late List<String> pushed;

  setUp(() {
    bidBloc = _MockBidBloc();
    cancellationBloc = _MockCancellationBloc();
    openBloc = _MockConversationOpenBloc();
    pushed = [];
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => cancellationBloc.state).thenReturn(CancellationInitial());
    when(() => openBloc.state).thenReturn(const ConversationOpenInitial());
  });

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
        GoRoute(
          path: '/payments/pay',
          builder: (_, state) {
            pushed.add('/payments/pay:${(state.extra! as BidModel).id}');
            return const Scaffold(body: Text('PAY'));
          },
        ),
      ],
    ),
  );

  Widget optionsHost(BidModel bid) => wrap(
    (context) =>
        SenderActionBar(bid: bid, isLoading: false, paymentLoaded: true),
  );

  Future<void> openOptions(WidgetTester tester, BidModel bid) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(optionsHost(bid));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
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

  group('TravelerRejectedBar', () {
    testWidgets(
      'Supprimer puis confirmer dispatch BidTravelerDismissRequested',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            (_) => TravelerRejectedBar(
              bid: _bid(status: 'REJECTED'),
              isLoading: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DonyButton));
        await tester.pumpAndSettle();
        expect(find.text(_l.bidDetailDeleteRejectedBody), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, _l.commonDelete));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verify(
          () => bidBloc.add(any(that: isA<BidTravelerDismissRequested>())),
        ).called(1);
      },
    );

    testWidgets('Annuler ferme la boîte sans événement', (tester) async {
      await tester.pumpWidget(
        wrap(
          (_) => TravelerRejectedBar(
            bid: _bid(status: 'REJECTED'),
            isLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DonyButton));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, _l.commonCancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => bidBloc.add(any()));
    });
  });

  group('SenderActionBar — zone de paiement', () {
    testWidgets('carte, paiement pas encore chargé : indicateur', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap((_) => SenderActionBar(bid: _bid(), isLoading: false)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_l.bidDetailPayMyShipment), findsNothing);
    });

    testWidgets(
      'carte, aucun paiement : « Payer mon envoi » pousse /payments/pay',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            (_) => SenderActionBar(
              bid: _bid(status: 'ACCEPTED'),
              isLoading: false,
              paymentLoaded: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_l.bidDetailPayMyShipment));
        await tester.pumpAndSettle();

        expect(find.text('PAY'), findsOneWidget);
        expect(pushed, ['/payments/pay:bid-42']);
      },
    );

    final amount = formatPriceIn(40, 'EUR');
    final cases = <(PaymentStatus, String, String)>[
      (
        PaymentStatus.released,
        'ACCEPTED',
        _l.bidDetailEscrowReleasedLabel(amount),
      ),
      (
        PaymentStatus.refunded,
        'ACCEPTED',
        _l.bidDetailEscrowRefundedLabel(amount),
      ),
      (PaymentStatus.failed, 'ACCEPTED', _l.bidDetailEscrowFailedLabel),
      (PaymentStatus.escrow, 'PENDING', _l.bidDetailEscrowSecuredPendingLabel),
      (
        PaymentStatus.escrow,
        'ACCEPTED',
        _l.bidDetailEscrowSecuredLabel(amount),
      ),
    ];
    for (final (status, bidStatus, label) in cases) {
      testWidgets('paiement $status sur bid $bidStatus : $label', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            (_) => SenderActionBar(
              bid: _bid(status: bidStatus),
              isLoading: false,
              paymentLoaded: true,
              existingPayment: _payment(status),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EscrowBadge), findsOneWidget);
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('EscrowBadge hors PENDING/ACCEPTED : libellé « sécurisé »', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          (_) => EscrowBadge(
            payment: _payment(PaymentStatus.escrow),
            bidStatus: 'HANDED_OVER',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l.bidDetailEscrowSecuredLabel(amount)), findsOneWidget);
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

        expect(find.text(_l.bidDetailCancelAfterHandoverTitle), findsOneWidget);
        expect(find.text(_l.bidDetailCancelAfterHandoverBody), findsOneWidget);
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

    for (final status in ['COMPLETED', 'REJECTED', 'CANCELLED']) {
      testWidgets('$status : Supprimer puis confirmer → BidDeleteRequested', (
        tester,
      ) async {
        await openOptions(tester, _bid(status: status));
        await tester.tap(find.text(_l.bidDetailRemoveFromHistorySubtitle));
        await tester.pumpAndSettle();

        expect(find.text(_l.bidDetailDeleteConfirmBody), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, _l.commonDelete));
        await tester.pumpAndSettle();

        verify(
          () => bidBloc.add(any(that: isA<BidDeleteRequested>())),
        ).called(1);
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
