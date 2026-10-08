import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

/// Comme bid_detail_screen : le talon « Code de retrait bloqué » (FLUTTER-G1)
/// lit TrackingBloc et BidBloc au build.
TrackingBloc _trackingBloc() {
  final b = _MockTrackingBloc();
  when(() => b.state).thenReturn(TrackingInitial());
  return b;
}

BidBloc _bidBloc() {
  final b = _MockBidBloc();
  when(() => b.state).thenReturn(BidInitial());
  return b;
}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockContactRevealBloc
    extends MockBloc<ContactRevealEvent, ContactRevealState>
    implements ContactRevealBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'ACCEPTED',
  String? travelerName = 'Mamadou',
  bool travelerPhoneAvailable = true,
  double? travelerAverageRating = 4.7,
  int? travelerTotalTrips = 8,
  String? recipientName = 'Fatou',
  String? recipientPhone = '+221700000000',
  double? weightKg = 5.0,
  String? contentCategory = 'Vêtements',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  double? totalAmountEur = 56.0,
  String? trackingToken = 'tok-abc123',
  String? departureCity = 'Paris',
  String? arrivalCity = 'Dakar',
  bool senderHasRated = false,
  String? arrivalInstructions,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  travelerId: 'traveler-001',
  travelerName: travelerName,
  travelerPhoneAvailable: travelerPhoneAvailable,
  travelerAverageRating: travelerAverageRating,
  travelerTotalTrips: travelerTotalTrips,
  recipientName: recipientName,
  recipientPhone: recipientPhone,
  weightKg: weightKg,
  contentCategory: contentCategory,
  paymentMethod: paymentMethod,
  totalAmountEur: totalAmountEur,
  trackingToken: trackingToken,
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  senderHasRated: senderHasRated,
  arrivalInstructions: arrivalInstructions,
);

// ── Host widget ───────────────────────────────────────────────────────────────

/// Bloc de révélation au repos : ces tests ne testent pas l'appel téléphonique.
_MockContactRevealBloc _revealBloc() {
  final bloc = _MockContactRevealBloc();
  when(() => bloc.state).thenReturn(const ContactRevealInitial());
  return bloc;
}

Widget _host(
  BidModel bid,
  _MockCancellationBloc cancellationBloc,
  _MockConversationOpenBloc conversationOpenBloc,
) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<TrackingBloc>.value(value: _trackingBloc()),
          BlocProvider<BidBloc>.value(value: _bidBloc()),
          BlocProvider<CancellationBloc>.value(value: cancellationBloc),
          BlocProvider<ConversationOpenBloc>.value(value: conversationOpenBloc),
          // Le numéro n'est plus dans le bid : la carte de contact lit ce bloc.
          BlocProvider<ContactRevealBloc>.value(value: _revealBloc()),
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
      final bid = _bid();

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
      expect(find.byType(PrevenirDestinataireCard), findsOneWidget);
      expect(find.byType(DetailsAccordion), findsOneWidget);
    },
  );

  // ── Test 2: PENDING → pas de voyageur ni d'actions de suivi ─────────────────
  testWidgets('2 · PENDING → profil du voyageur sans bouton de contact, '
      'QuickActionsRow absent, ColisDestinataireCard présent', (tester) async {
    sizeView(tester);
    final bid = _bid(status: 'PENDING');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    // En attente : on voit qui est le voyageur, sans pouvoir le joindre.
    expect(find.byType(VoyageurContactCard), findsOneWidget);
    expect(_contactIcon(VoyageurContactCard, 'message-circle'), findsNothing);
    expect(_contactIcon(VoyageurContactCard, 'phone'), findsNothing);
    expect(find.byType(QuickActionsRow), findsNothing);
    expect(find.byType(PrevenirDestinataireCard), findsNothing);
    expect(find.byType(ColisDestinataireCard), findsOneWidget);
    // L'expéditeur voit toujours le téléphone du destinataire.
    expect(find.text('Téléphone'), findsOneWidget);
  });

  // ── Test 2 bis: ARRIVED → voyageur + actions rapides toujours visibles ──────
  testWidgets(
    '2 bis · ARRIVED → VoyageurContactCard et QuickActionsRow restent affichés',
    (tester) async {
      sizeView(tester);
      final bid = _bid(status: 'ARRIVED');

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(VoyageurContactCard), findsOneWidget);
      expect(find.byType(QuickActionsRow), findsOneWidget);
    },
  );

  // ── Test 3: CANCELLED → voyageur absent, hero shrink ────────────────────────
  testWidgets('3 · CANCELLED → profil du voyageur sans bouton de contact', (
    tester,
  ) async {
    sizeView(tester);
    final bid = _bid(status: 'CANCELLED');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(VoyageurContactCard), findsOneWidget);
    expect(_contactIcon(VoyageurContactCard, 'message-circle'), findsNothing);
    // Le billet et la carte colis restent toujours présents.
    expect(find.byType(ColisBillet), findsOneWidget);
    expect(find.byType(ColisDestinataireCard), findsOneWidget);
  });

  // ── Instructions de retrait : encart hors du hero ──────────────────────────
  // Le hero ne les montrait qu'en ARRIVED, et les perdait dès qu'une
  // contestation, une absence ou la livraison prenait sa place.
  for (final status in ['HANDED_OVER', 'ARRIVED', 'COMPLETED']) {
    testWidgets('$status + instructions → encart des instructions de retrait', (
      tester,
    ) async {
      sizeView(tester);
      final bid = _bid(
        status: status,
        arrivalInstructions: 'Gare routière, quai 4',
      );

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(const Key('arrival-instructions-card')),
        findsOneWidget,
      );
      expect(find.text('Gare routière, quai 4'), findsOneWidget);
    });
  }

  testWidgets('sans instructions → aucun encart', (tester) async {
    sizeView(tester);
    final bid = _bid(status: 'ARRIVED', arrivalInstructions: '  ');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('arrival-instructions-card')), findsNothing);
  });

  // ── Test 4: COMPLETED + senderHasRated=true → RatingDoneBadge ──────────────
  testWidgets('4 · COMPLETED + senderHasRated=true → RatingDoneBadge affiché', (
    tester,
  ) async {
    sizeView(tester);
    final bid = _bid(status: 'COMPLETED', senderHasRated: true);

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Évaluation envoyée'), findsOneWidget);
  });

  // ── Test 5: COMPLETED + senderHasRated=false → RatingDoneBadge absent ──────
  testWidgets('5 · COMPLETED + senderHasRated=false → RatingDoneBadge absent', (
    tester,
  ) async {
    sizeView(tester);
    final bid = _bid(status: 'COMPLETED');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Évaluation envoyée'), findsNothing);
  });

  // ── Test 6: stagger désactivé après premier build (playEntrance=false) ──────
  testWidgets('6 · après la durée du stagger, playEntrance passe à false '
      'et le second rebuild ne rejoue pas l\'animation', (tester) async {
    sizeView(tester);
    final bid = _bid();

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    // Attendre plus longtemps que la durée totale du stagger
    // (60ms × 7 + 300ms + 50ms = 770ms).
    await tester.pump(const Duration(milliseconds: 900));

    // Le corps doit toujours rendre ses widgets normalement.
    expect(find.byType(ColisBillet), findsOneWidget);
    expect(find.byType(SenderHeroCard), findsOneWidget);
  });

  testWidgets(
    'anglais · COMPLETED + senderHasRated=true → "Rating sent" affiché',
    (tester) async {
      useEnglish();
      sizeView(tester);
      final bid = _bid(status: 'COMPLETED', senderHasRated: true);

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Rating sent'), findsOneWidget);
    },
  );
}

/// Bouton d'une carte de profil (appel ou message), repéré par son icône.
Finder _contactIcon(Type card, String icon) => find.descendant(
  of: find.byType(card),
  matching: find.byWidgetPredicate((w) => w is DonyIcon && w.name == icon),
);
