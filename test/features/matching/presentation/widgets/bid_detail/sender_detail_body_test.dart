import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'ACCEPTED',
  String? travelerName = 'Mamadou',
  String? travelerPhone = '+33600000000',
  double? travelerAverageRating = 4.7,
  int? travelerTotalTrips = 8,
  String? recipientName = 'Fatou',
  String? recipientPhone = '+221700000000',
  double? weightKg = 5.0,
  String? contentCategory = 'Vêtements',
  double? declaredValueEur = 120.0,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  double? totalAmountEur = 56.0,
  String? trackingToken = 'tok-abc123',
  String? departureCity = 'Paris',
  String? arrivalCity = 'Dakar',
  bool senderHasRated = false,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  travelerId: 'traveler-001',
  travelerName: travelerName,
  travelerPhone: travelerPhone,
  travelerAverageRating: travelerAverageRating,
  travelerTotalTrips: travelerTotalTrips,
  recipientName: recipientName,
  recipientPhone: recipientPhone,
  weightKg: weightKg,
  contentCategory: contentCategory,
  declaredValueEur: declaredValueEur,
  paymentMethod: paymentMethod,
  totalAmountEur: totalAmountEur,
  trackingToken: trackingToken,
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  senderHasRated: senderHasRated,
);

// ── Host widget ───────────────────────────────────────────────────────────────

Widget _host(
  BidModel bid,
  _MockCancellationBloc cancellationBloc,
  _MockConversationOpenBloc conversationOpenBloc,
) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<CancellationBloc>.value(value: cancellationBloc),
          BlocProvider<ConversationOpenBloc>.value(value: conversationOpenBloc),
        ],
        child: SenderDetailBody(bid: bid),
      ),
    ),
  );
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  late _MockCancellationBloc cancellationBloc;
  late _MockConversationOpenBloc conversationOpenBloc;

  setUp(() {
    cancellationBloc = _MockCancellationBloc();
    whenListen<CancellationState>(
      cancellationBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
    conversationOpenBloc = _MockConversationOpenBloc();
    whenListen<ConversationOpenState>(
      conversationOpenBloc,
      const Stream<ConversationOpenState>.empty(),
      initialState: const ConversationOpenInitial(),
    );
  });

  // Large surface so the staggered column doesn't overflow.
  void sizeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // ── Test 1: ACCEPTED → toutes les cartes présentes ─────────────────────────
  testWidgets(
    '1 · ACCEPTED → ColisBillet, SenderHeroCard, VoyageurContactCard, '
    'ColisDestinataireCard, PaiementCard, QuickActionsRow, DetailsAccordion',
    (tester) async {
      sizeView(tester);
      final bid = _bid(status: 'ACCEPTED');

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      // Laisse les staggers (60ms × index + 300ms fadeIn) se terminer.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ColisBillet), findsOneWidget);
      expect(find.byType(SenderHeroCard), findsOneWidget);
      expect(find.byType(VoyageurContactCard), findsOneWidget);
      expect(find.byType(ColisDestinataireCard), findsOneWidget);
      expect(find.byType(PaiementCard), findsOneWidget);
      expect(find.byType(QuickActionsRow), findsOneWidget);
      expect(find.byType(DetailsAccordion), findsOneWidget);
    },
  );

  // ── Test 2: PENDING → pas de voyageur ni d'actions de suivi ─────────────────
  testWidgets(
    '2 · PENDING → VoyageurContactCard absent, QuickActionsRow absent, '
    'ColisDestinataireCard présent',
    (tester) async {
      sizeView(tester);
      final bid = _bid(status: 'PENDING');

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(VoyageurContactCard), findsNothing);
      expect(find.byType(QuickActionsRow), findsNothing);
      expect(find.byType(ColisDestinataireCard), findsOneWidget);
    },
  );

  // ── Test 3: CANCELLED → voyageur absent, hero shrink ────────────────────────
  testWidgets(
    '3 · CANCELLED → VoyageurContactCard absent (la hero rend shrink)',
    (tester) async {
      sizeView(tester);
      final bid = _bid(status: 'CANCELLED');

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(VoyageurContactCard), findsNothing);
      // Le billet et la carte colis restent toujours présents.
      expect(find.byType(ColisBillet), findsOneWidget);
      expect(find.byType(ColisDestinataireCard), findsOneWidget);
    },
  );
}
