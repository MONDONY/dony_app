import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../helpers/tracking_consent_test_helpers.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAcceptance
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockCancellation extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockTracking extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockConversationOpen
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockRating extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockAuth extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockNotificationService extends Mock implements NotificationService {}

final _l = lookupAppLocalizations(AppL10n.fr);

const _senderId = 'sender-001';

BidModel _bid({
  String status = 'ACCEPTED',
  String senderId = _senderId,
  BidPaymentMethod method = BidPaymentMethod.cash,
  String? trackingToken,
  bool isSkeleton = false,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: isSkeleton ? '' : senderId,
  weightKg: 3,
  status: status,
  paymentMethod: method,
  trackingToken: trackingToken,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

void main() {
  setUpAll(() {
    registerFallbackValue(BidDetailRequested('x'));
    registerFallbackValue(ace.BidAcceptRequested('x'));
  });

  late _MockBidBloc bidBloc;
  late _MockAcceptance acceptance;
  late _MockCancellation cancellation;
  late _MockConversationOpen conversationOpen;
  late _MockAuth auth;
  late _MockPaymentRepository payments;
  late _MockNotificationService notifications;
  late StreamController<BidState> bidStates;
  late StreamController<acs.BidAcceptanceState> acceptanceStates;
  late StreamController<CancellationState> cancellationStates;
  late StreamController<ConversationOpenState> openStates;
  late StreamController<Map<String, dynamic>> pushes;
  late List<String> visited;

  setUp(() {
    useTrackingConsent();
    DonySnackbar.clearDedup();
    bidBloc = _MockBidBloc();
    acceptance = _MockAcceptance();
    cancellation = _MockCancellation();
    conversationOpen = _MockConversationOpen();
    auth = _MockAuth();
    payments = _MockPaymentRepository();
    notifications = _MockNotificationService();
    bidStates = StreamController.broadcast();
    acceptanceStates = StreamController.broadcast();
    cancellationStates = StreamController.broadcast();
    openStates = StreamController.broadcast();
    pushes = StreamController.broadcast();
    visited = [];

    whenListen(bidBloc, bidStates.stream, initialState: BidInitial());
    whenListen(
      acceptance,
      acceptanceStates.stream,
      initialState: acs.BidAcceptanceInitial(),
    );
    whenListen(
      cancellation,
      cancellationStates.stream,
      initialState: CancellationInitial(),
    );
    whenListen(
      conversationOpen,
      openStates.stream,
      initialState: const ConversationOpenInitial(),
    );
    final tracking = _MockTracking();
    whenListen(
      tracking,
      const Stream<TrackingState>.empty(),
      initialState: TrackingInitial(),
    );
    final rating = _MockRating();
    whenListen(
      rating,
      const Stream<RatingState>.empty(),
      initialState: const RatingInitial(),
    );
    whenListen(
      auth,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(
        UserModel(
          id: _senderId,
          roles: ['SENDER'],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        ),
      ),
    );
    when(() => payments.getPaymentForBid(any())).thenAnswer((_) async => null);
    when(
      () => notifications.foregroundPushStream,
    ).thenAnswer((_) => pushes.stream);

    getIt
      ..registerFactory<BidBloc>(() => bidBloc)
      ..registerFactory<BidAcceptanceBloc>(() => acceptance)
      ..registerFactory<CancellationBloc>(() => cancellation)
      ..registerFactory<TrackingBloc>(() => tracking)
      ..registerFactory<ConversationOpenBloc>(() => conversationOpen)
      ..registerFactory<RatingBloc>(() => rating)
      ..registerSingleton<PaymentRepository>(payments)
      ..registerSingleton<NotificationService>(notifications);
  });

  tearDown(() async {
    await getIt.reset();
    await bidStates.close();
    await acceptanceStates.close();
    await cancellationStates.close();
    await openStates.close();
    await pushes.close();
  });

  /// [pushed] : la fiche est poussée par-dessus `/start` (retour possible).
  Future<void> pump(
    WidgetTester tester,
    BidModel bid, {
    bool pushed = true,
    bool fromPayment = false,
  }) async {
    await initializeDateFormatting('fr_FR');
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    GoRoute stub(String path, {Object? popWith}) => GoRoute(
      path: path,
      builder: (context, state) {
        visited.add(state.uri.path);
        return Scaffold(
          body: TextButton(
            onPressed: () => context.pop(popWith),
            child: Text('stub $path'),
          ),
        );
      },
    );

    final router = GoRouter(
      initialLocation: pushed ? '/start' : '/detail',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/detail'),
              child: const Text('start'),
            ),
          ),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: auth,
            child: BidDetailScreen(bid: bid, fromPayment: fromPayment),
          ),
        ),
        stub('/home'),
        stub('/tracking'),
        stub('/conversations/:id'),
        stub('/payments/commission-method'),
        stub('/payments/wallet/topup/method', popWith: true),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pump();
    if (pushed) {
      await tester.tap(find.text('start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  int detailRequests() =>
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).callCount;

  group('écouteur CancellationBloc : message puis relecture du colis', () {
    final cases = <(String, CancellationState Function(), String)>[
      (
        'no-show signalé',
        NoShowReported.new,
        _l.bidDetailNoShowReportedSnackbar,
      ),
      (
        'no-show du voyageur signalé',
        TravelerNoShowReported.new,
        _l.bidDetailTravelerNoShowReportedSnackbar,
      ),
      (
        'no-show à la livraison',
        DeliveryNoShowReported.new,
        _l.bidDetailDeliveryNoShowReportedSnackbar,
      ),
      (
        'contestation livraison',
        DeliveryNoShowContested.new,
        _l.bidDetailContestSentSnackbar,
      ),
      ('contestation', NoShowContested.new, _l.bidDetailContestSentSnackbar),
      (
        'no-show confirmé',
        NoShowConfirmed.new,
        _l.bidDetailNoShowConfirmedSnackbar,
      ),
      (
        'annulé après remise',
        CancelledAfterHandover.new,
        _l.bidDetailCancelledAfterHandoverSnackbar,
      ),
      ('report gardé', RescheduleKept.new, _l.bidRescheduleKeptSnackbar),
      (
        'report retiré',
        RescheduleWithdrawn.new,
        _l.bidRescheduleWithdrawnSnackbar,
      ),
      (
        'retour confirmé',
        () => ReturnConfirmed(ReturnCodeModel(returnedAt: DateTime(2026, 6))),
        _l.bidDetailReturnConfirmedSnackbar,
      ),
    ];
    for (final (name, make, message) in cases) {
      testWidgets(name, (tester) async {
        await pump(tester, _bid(status: 'COMPLETED'));
        final before = detailRequests();

        cancellationStates.add(make());
        await settle(tester);

        expect(find.text(message), findsOneWidget);
        expect(before, 1);
        expect(detailRequests(), 1);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });
    }

    testWidgets('erreur : message traduit', (tester) async {
      await pump(tester, _bid(status: 'COMPLETED'));
      const error = TimeoutException();
      cancellationStates.add(CancellationError(error));
      await settle(tester);

      expect(
        find.text(ErrorPresenter.resolve(error, l10n: _l).message),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('écouteur ConversationOpenBloc', () {
    testWidgets('succès : ouvre la conversation', (tester) async {
      await pump(tester, _bid(status: 'COMPLETED'));
      openStates.add(
        const ConversationOpenSuccess(
          ConversationModel(
            id: 'conv-1',
            bidId: 'bid-001',
            firestoreConversationId: 'fc-1',
            otherParticipant: ParticipantModel(id: 'u', name: 'Ibrahima'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(visited, ['/conversations/conv-1']);
    });

    testWidgets('erreur : message traduit', (tester) async {
      await pump(tester, _bid(status: 'COMPLETED'));
      const error = TimeoutException();
      openStates.add(const ConversationOpenError(error));
      await settle(tester);
      expect(
        find.text(ErrorPresenter.resolve(error, l10n: _l).message),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('écouteur BidAcceptanceBloc (vue voyageur)', () {
    BidModel travelerBid() => _bid(status: 'PENDING', senderId: 'other');

    testWidgets('acceptation : message et relecture du colis', (tester) async {
      await pump(tester, travelerBid());
      acceptanceStates.add(acs.BidAccepted());
      await settle(tester);

      expect(find.text(_l.bidDetailAcceptedSetHandoverWindow), findsOneWidget);
      expect(detailRequests(), 2);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('échec simple : snackbar d\'erreur', (tester) async {
      await pump(tester, travelerBid());
      acceptanceStates.add(
        acs.BidFailed(reason: acs.BidFailureReason.confirmFailed),
      );
      await settle(tester);
      expect(find.text(_l.bidAcceptConfirmFailed), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('carte refusée : feuille puis changement de carte', (
      tester,
    ) async {
      await pump(tester, travelerBid());
      acceptanceStates.add(
        acs.BidFailed(
          reason: acs.BidFailureReason.confirmFailed,
          cardDeclined: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l.bidDetailCardDeclinedTitle), findsOneWidget);
      expect(find.text(_l.bidDetailCardDeclinedHint), findsOneWidget);
      await tester.tap(find.text(_l.bidDetailChangeCommissionCard));
      await tester.pumpAndSettle();
      expect(visited, ['/payments/commission-method']);
    });

    acs.BidWalletInsufficient shortfall({required bool hasCard}) =>
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: hasCard,
          bidId: 'bid-001',
        );

    testWidgets('solde insuffisant : recharge réussie → acceptation relancée', (
      tester,
    ) async {
      await pump(tester, travelerBid());
      acceptanceStates.add(shortfall(hasCard: false));
      await tester.pumpAndSettle();

      expect(find.text(_l.bidDetailInsufficientBalanceTitle), findsOneWidget);
      expect(find.text(_l.bidDetailInsufficientBalanceHint), findsOneWidget);
      await tester.tap(find.text(_l.bidDetailTopupWallet));
      await tester.pumpAndSettle();
      await tester.tap(find.text('stub /payments/wallet/topup/method'));
      await tester.pumpAndSettle();

      verify(
        () => acceptance.add(any(that: isA<ace.BidAcceptRequested>())),
      ).called(1);
    });

    testWidgets('solde insuffisant avec carte : payer par carte', (
      tester,
    ) async {
      await pump(tester, travelerBid());
      acceptanceStates.add(shortfall(hasCard: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_l.bidDetailPayByCard));
      await tester.pumpAndSettle();
      verify(
        () => acceptance.add(any(that: isA<ace.BidAcceptWithCardRequested>())),
      ).called(1);
    });

    testWidgets('solde insuffisant sans carte : ajouter une carte', (
      tester,
    ) async {
      await pump(tester, travelerBid());
      acceptanceStates.add(shortfall(hasCard: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_l.bidDetailAddCard));
      await tester.pumpAndSettle();
      expect(visited, ['/payments/commission-method']);
    });

    testWidgets('menu ⋮ voyageur : feuille d\'options', (tester) async {
      await pump(tester, travelerBid());
      await tester.tap(find.byTooltip(_l.bidDetailOptionsTitle));
      await tester.pumpAndSettle();
      expect(find.text(_l.bidDetailOptionsTitle), findsWidgets);
    });
  });

  group('écouteur BidBloc', () {
    testWidgets('acceptée : message de succès', (tester) async {
      await pump(tester, _bid(status: 'PENDING', senderId: 'other'));
      bidStates.add(BidAccepted(_bid(senderId: 'other')));
      await settle(tester);
      expect(find.text(_l.bidDetailAcceptedSnackbar), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('présence confirmée : message de succès', (tester) async {
      await pump(tester, _bid());
      bidStates.add(BidPresenceConfirmed(_bid()));
      await settle(tester);
      expect(find.text(_l.bidDetailPresenceConfirmedSnackbar), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    final exits = <(String, BidState Function(), String)>[
      (
        'refusée',
        () => BidRejected(_bid(status: 'REJECTED')),
        _l.bidDetailRejectedSnackbar,
      ),
      (
        'annulée',
        () => BidCancelled(_bid(status: 'CANCELLED')),
        _l.bidDetailCancelledSnackbar,
      ),
      ('supprimée', BidDeleted.new, _l.bidDetailDeletedSnackbar),
      (
        'annulée avant paiement',
        BidCancelledBeforePayment.new,
        _l.bidCancelBeforePaymentSuccessSnackbar,
      ),
    ];
    for (final (name, make, message) in exits) {
      testWidgets('$name, fiche poussée : message et retour', (tester) async {
        await pump(tester, _bid());
        bidStates.add(make());
        await settle(tester);

        expect(find.text(message), findsOneWidget);
        expect(find.text('start'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('$name, fiche racine : redirection /home', (tester) async {
        await pump(tester, _bid(), pushed: false);
        bidStates.add(make());
        await tester.pumpAndSettle(const Duration(seconds: 5));
        expect(visited, ['/home']);
      });
    }

    testWidgets('erreur au chargement du squelette : sortie de la fiche', (
      tester,
    ) async {
      await pump(tester, _bid(isSkeleton: true));
      expect(find.byType(DonyDetailSkeleton), findsOneWidget);

      const error = TimeoutException();
      bidStates.add(BidError(error));
      await settle(tester);

      expect(find.text('start'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('erreur au chargement du squelette, fiche racine : /home', (
      tester,
    ) async {
      await pump(tester, _bid(isSkeleton: true), pushed: false);
      bidStates.add(BidError(const TimeoutException()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(visited, ['/home']);
    });

    testWidgets('colis introuvable : vue dédiée, accès au suivi', (
      tester,
    ) async {
      await pump(tester, _bid());
      bidStates.add(BidNotFound());
      await settle(tester);

      expect(find.byKey(const Key('bid-detail-gone')), findsOneWidget);
      expect(find.text(_l.bidDetailGoneTitle), findsOneWidget);
      await tester.tap(find.text(_l.bidDetailGoneAction));
      await tester.pumpAndSettle();
      expect(visited, ['/tracking']);
    });

    testWidgets('colis introuvable : le retour quitte la fiche', (
      tester,
    ) async {
      await pump(tester, _bid());
      bidStates.add(BidNotFound());
      await settle(tester);

      await tester.tap(find.byType(DonyAppBarBackButton).first);
      await tester.pumpAndSettle();
      expect(find.text('start'), findsOneWidget);
    });

    testWidgets('colis introuvable, fiche racine : retour vers /home', (
      tester,
    ) async {
      await pump(tester, _bid(), pushed: false);
      bidStates.add(BidNotFound());
      await settle(tester);

      await tester.tap(find.byType(DonyAppBarBackButton).first);
      await tester.pumpAndSettle();
      expect(visited, ['/home']);
    });

    testWidgets('colis passé à un statut terminal : relevé arrêté', (
      tester,
    ) async {
      await pump(tester, _bid());
      bidStates.add(BidDetailLoaded(_bid(status: 'COMPLETED')));
      await settle(tester);
      final before = detailRequests();
      await tester.pump(const Duration(seconds: 31));
      expect(before, 1);
      verifyNever(() => bidBloc.add(any(that: isA<BidDetailRequested>())));
    });
  });

  group('barre d\'application', () {
    testWidgets('après un paiement, le retour mène à /home', (tester) async {
      await pump(tester, _bid(status: 'COMPLETED'), fromPayment: true);
      await tester.tap(find.byType(DonyAppBarBackButton).first);
      await tester.pumpAndSettle();
      expect(visited, ['/home']);
    });

    testWidgets('fiche racine : le retour mène à /home', (tester) async {
      await pump(tester, _bid(status: 'COMPLETED'), pushed: false);
      await tester.tap(find.byType(DonyAppBarBackButton).first);
      await tester.pumpAndSettle();
      expect(visited, ['/home']);
    });

    testWidgets('expéditeur avec jeton : partage du lien de suivi', (
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

      await pump(tester, _bid(status: 'COMPLETED', trackingToken: 'tok-9'));
      await tester.tap(find.byTooltip(_l.bidDetailShareTracking));
      await tester.pump();
      expect(shares.single.toString(), contains('tok-9'));
    });

    testWidgets('expéditeur : menu ⋮ ouvre ses options', (tester) async {
      await pump(tester, _bid(status: 'COMPLETED'));
      await tester.tap(find.byTooltip(_l.bidDetailOptionsTitle));
      await tester.pumpAndSettle();
      expect(find.text(_l.bidDetailReportTripLabel), findsOneWidget);
    });
  });

  group('relectures externes', () {
    testWidgets('push reçue au premier plan : changement signalé au bloc', (
      tester,
    ) async {
      await pump(tester, _bid(status: 'COMPLETED'));
      pushes.add({'bidId': 'bid-001'});
      await tester.pump();
      verify(
        () => bidBloc.add(any(that: isA<BidDetailExternalChangeDetected>())),
      ).called(1);
    });

    testWidgets('retour au premier plan : changement signalé au bloc', (
      tester,
    ) async {
      await pump(tester, _bid(status: 'COMPLETED'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      verify(
        () => bidBloc.add(any(that: isA<BidDetailExternalChangeDetected>())),
      ).called(1);
    });

    testWidgets('lecture du paiement en échec : la fiche reste affichée', (
      tester,
    ) async {
      when(
        () => payments.getPaymentForBid(any()),
      ).thenThrow(const TimeoutException());
      await pump(tester, _bid(method: BidPaymentMethod.stripe));
      expect(find.byType(DonyAppBar), findsOneWidget);
    });
  });
}
