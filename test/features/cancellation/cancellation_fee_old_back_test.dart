import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/cancellation_fee_flag.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_config/cancellation_fee_config_cubit.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/cancellation_fee_coverage.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_fee_config_builder.dart';
import 'package:dony/features/cancellation/presentation/widgets/sender_noshow_confirm_sheet.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'cancellation_fee_test_support.dart';

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

final _l = lookupAppLocalizations(AppL10n.fr);

/// Colis qui serait couvert si les frais étaient allumés : créé après la date
/// d'effet, payé par carte.
BidModel _bid({
  String status = 'ACCEPTED',
  DateTime? handoverDeadline,
  DateTime? departureAt,
  String? cancellationNoShowStatus,
}) => BidModel(
  id: 'bid-old',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 4,
  status: status,
  totalAmountEur: 182,
  totalSenderAmountEur: 200,
  handoverDeadline: handoverDeadline,
  departureAt: departureAt,
  cancellationNoShowStatus: cancellationNoShowStatus,
  contestationDeadline: cancellationNoShowStatus == null
      ? null
      : DateTime.now().add(const Duration(hours: 40)),
  createdAt: kCoveredCreatedAt,
  updatedAt: kCoveredCreatedAt,
);

/// Back antérieur à la fonction : `GET /config/cancellation-fee` répond 404
/// et le paiement n'a pas de `refundedAmount`. Chaque texte des frais reste
/// celui d'aujourd'hui, mot pour mot.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  late _MockCancellationBloc cancellationBloc;
  late _MockBidBloc bidBloc;
  late _MockConversationOpenBloc openBloc;
  late CancellationFeeConfigCubit config;

  setUp(() async {
    cancellationBloc = _MockCancellationBloc();
    bidBloc = _MockBidBloc();
    openBloc = _MockConversationOpenBloc();
    whenListen<CancellationState>(
      cancellationBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => openBloc.state).thenReturn(const ConversationOpenInitial());
    config = await registerFeeConfig();
  });

  tearDown(getIt.reset);

  Widget app(Widget home) => MaterialApp(
    theme: AppTheme.light(),
    locale: AppL10n.fr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<CancellationBloc>.value(value: cancellationBloc),
        BlocProvider<BidBloc>.value(value: bidBloc),
        BlocProvider<ConversationOpenBloc>.value(value: openBloc),
      ],
      child: Scaffold(body: home),
    ),
  );

  test('configuration : éteinte, drapeau baissé, aucun colis couvert', () {
    expect(config.state, isA<CancellationFeeConfigUnavailable>());
    expect(currentCancellationFeeConfig(), CancellationFeeConfigModel.inactive);
    expect(cancellationFeeActive, isFalse);
    expect(
      isCoveredByCancellationFee(_bid(), currentCancellationFeeConfig()),
      isFalse,
    );
  });

  testWidgets('A · carte « Fenêtre de remise dépassée » : « sans frais »', (
    tester,
  ) async {
    final bid = _bid(
      handoverDeadline: DateTime.now().subtract(const Duration(hours: 2)),
    );
    await tester.pumpWidget(app(SenderHeroCard(bid: bid)));
    await tester.pump();

    final window = _l.bidDetailUntil(
      DateFormat.MMMEd('fr').format(bid.handoverDeadline!.toLocal()),
    );
    expect(
      find.text(_l.bidDetailSenderWindowExpiredSubtitle(window)),
      findsOneWidget,
    );
  });

  Future<void> openOptions(WidgetTester tester, BidModel bid) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSenderOptionsSheet(context, bid),
            child: const Text('open-options'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-options'));
    await tester.pumpAndSettle();
  }

  testWidgets('C · menu ⋮ avant remise : remboursement automatique', (
    tester,
  ) async {
    await openOptions(tester, _bid());
    expect(find.text(_l.bidDetailCancelRefundAutoSubtitle), findsOneWidget);
  });

  testWidgets('B · menu ⋮ après remise : remboursement intégral', (
    tester,
  ) async {
    await openOptions(
      tester,
      _bid(
        status: 'HANDED_OVER',
        departureAt: DateTime.now().add(const Duration(days: 4)),
      ),
    );
    expect(
      find.text(_l.bidDetailCancelAfterHandoverOptionSubtitle),
      findsOneWidget,
    );
  });

  testWidgets('E · « Confirmer votre absence » : « vous ne serez pas '
      'débité »', (tester) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSenderNoShowConfirmSheet(
              context,
              bid: _bid(cancellationNoShowStatus: 'PENDING_CONFIRMATION'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(_l.bidDetailSenderConfirmSheetBody), findsOneWidget);
    expect(find.byKey(const Key('cancel-fee-notice')), findsNothing);
  });

  testWidgets('G · carte Paiement d\'un colis annulé : total payé', (
    tester,
  ) async {
    // Réponse de `GET /payments/bid/{id}` d'un back antérieur.
    final payment = PaymentModel.fromJson(const {
      'id': 'pay-1',
      'bidId': 'bid-old',
      'amount': 200,
      'commissionAmount': 18,
      'currency': 'eur',
      'status': 'REFUNDED',
    });
    expect(payment.refundedAmount, isNull);
    for (final status in ['CANCELLED', 'NO_SHOW']) {
      await tester.pumpWidget(
        app(
          PaiementCard(
            bid: _bid(status: status),
            existingPayment: payment,
          ),
        ),
      );
      expect(
        find.text(_l.bidDetailAmountRefundedLabel(formatPriceIn(200, 'EUR'))),
        findsOneWidget,
      );
    }
  });

  test('H · paiement validé pendant l\'annulation : « vous serez '
      'remboursé »', () {
    final p = ErrorCatalog.lookup(
      const ConflictException('x', code: 'payment-already-authorized'),
      l10n: _l,
    );
    expect(p.message, _l.errorPaymentAlreadyAuthorizedMessage);
  });

  test('F et I · textes globaux : la configuration reste éteinte', () {
    // F (snackbar) lit currentCancellationFeeConfig(), I (FAQ) le drapeau :
    // tous deux éteints, donc les textes d'aujourd'hui (tests dédiés dans
    // bid_detail_screen_listeners_test.dart et faq_screen_test.dart).
    expect(
      isCoveredByCancellationFee(_bid(), currentCancellationFeeConfig()),
      isFalse,
    );
    expect(cancellationFeeActiveListenable.value, isFalse);
  });
}
