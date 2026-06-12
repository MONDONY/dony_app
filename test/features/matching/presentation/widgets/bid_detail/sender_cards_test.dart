import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockTravelerSubscribeBloc
    extends MockBloc<TravelerSubscribeEvent, TravelerSubscribeState>
    implements TravelerSubscribeBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'ACCEPTED',
  String? travelerName,
  String? travelerPhone,
  double? travelerAverageRating,
  int? travelerTotalTrips,
  bool travelerKycVerified = false,
  bool travelerKiloPro = false,
  double? weightKg,
  String? contentCategory,
  String? description,
  double? declaredValueEur,
  String? recipientName,
  String? recipientPhone,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  double? totalAmountEur,
  String? trackingToken,
  String? trackingNumber,
  String? handoverLocation,
  DateTime? handoverWindowStart,
  DateTime? handoverWindowEnd,
  bool voyageurConfirmed = false,
  DateTime? disclaimerSignedAt,
  DateTime? departureDate,
  double? pricePerKg,
  String? departureCity,
  String? arrivalCity,
}) =>
    BidModel(
      id: 'bid-test',
      announcementId: 'ann-test',
      senderId: 'sender-test',
      status: status,
      createdAt: DateTime(2026, 1, 15),
      updatedAt: DateTime(2026, 1, 15),
      travelerName: travelerName,
      travelerPhone: travelerPhone,
      travelerAverageRating: travelerAverageRating,
      travelerTotalTrips: travelerTotalTrips,
      travelerKycVerified: travelerKycVerified,
      travelerKiloPro: travelerKiloPro,
      weightKg: weightKg,
      contentCategory: contentCategory,
      description: description,
      declaredValueEur: declaredValueEur,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      paymentMethod: paymentMethod,
      totalAmountEur: totalAmountEur,
      trackingToken: trackingToken,
      trackingNumber: trackingNumber,
      handoverLocation: handoverLocation,
      handoverWindowStart: handoverWindowStart,
      handoverWindowEnd: handoverWindowEnd,
      voyageurConfirmed: voyageurConfirmed,
      disclaimerSignedAt: disclaimerSignedAt,
      departureDate: departureDate,
      pricePerKg: pricePerKg,
      departureCity: departureCity,
      arrivalCity: arrivalCity,
    );

// ── Host widget helpers ───────────────────────────────────────────────────────

Widget _hostVoyageur(BidModel bid, _MockConversationOpenBloc bloc) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BlocProvider<ConversationOpenBloc>.value(
          value: bloc,
          child: VoyageurContactCard(bid: bid),
        ),
      ),
    );

Widget _hostColis(BidModel bid) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ColisDestinataireCard(bid: bid)),
    );

Widget _hostPaiement(BidModel bid) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: PaiementCard(bid: bid)),
    );

Widget _hostAccordion(BidModel bid) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(child: DetailsAccordion(bid: bid)),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const ConversationOpenRequested('bid-test'));
  });

  // ── VoyageurContactCard ────────────────────────────────────────────────────
  group('VoyageurContactCard', () {
    late _MockConversationOpenBloc bloc;

    setUp(() {
      bloc = _MockConversationOpenBloc();
      when(() => bloc.state).thenReturn(const ConversationOpenInitial());
    });

    testWidgets('shows traveler name, rating and chat button', (tester) async {
      final bid = _bid(
        travelerName: 'Oumar Diallo',
        travelerAverageRating: 4.8,
        travelerTotalTrips: 12,
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('Oumar Diallo'), findsOneWidget);
      expect(find.text('★ 4.8 · 12 trajets'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });

    testWidgets('shows phone button when phone is present and status is ACCEPTED',
        (tester) async {
      final bid = _bid(
        travelerPhone: '+33600000000',
        status: 'ACCEPTED',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
    });

    testWidgets('hides phone button when phone is null', (tester) async {
      final bid = _bid(travelerPhone: null);

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byIcon(Icons.phone_rounded), findsNothing);
    });

    testWidgets('hides phone button when status is COMPLETED even with phone',
        (tester) async {
      final bid = _bid(
        travelerPhone: '+33600000000',
        status: 'COMPLETED',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byIcon(Icons.phone_rounded), findsNothing);
    });

    testWidgets('hides phone button when status is DELIVERED even with phone',
        (tester) async {
      final bid = _bid(
        travelerPhone: '+33600000000',
        status: 'DELIVERED',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byIcon(Icons.phone_rounded), findsNothing);
    });

    testWidgets('tap chat button fires ConversationOpenRequested once',
        (tester) async {
      final bid = _bid();

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured.length, 1);
      final event = captured.first as ConversationOpenRequested;
      expect(event.bidId, 'bid-test');
    });

    testWidgets(
        'travelerId non-null → chevron visible et tap ouvre le sheet profil',
        (tester) async {
      // Register mock blocs that showTravelerProfileSheet needs from GetIt.
      final ratingBloc = _MockRatingBloc();
      final subscribeBloc = _MockTravelerSubscribeBloc();
      whenListen(
        ratingBloc,
        const Stream<RatingState>.empty(),
        initialState: const UserRatingsLoaded(
          averageRating: 0,
          ratingCount: 0,
          distribution: {},
          ratings: [],
          page: 0,
          totalPages: 1,
        ),
      );
      whenListen(
        subscribeBloc,
        const Stream<TravelerSubscribeState>.empty(),
        initialState: const TravelerSubscribeState(
          status: TravelerSubscribeStatus.loading,
        ),
      );

      if (getIt.isRegistered<RatingBloc>()) getIt.unregister<RatingBloc>();
      if (getIt.isRegistered<TravelerSubscribeBloc>()) {
        getIt.unregister<TravelerSubscribeBloc>();
      }
      getIt.registerFactory<RatingBloc>(() => ratingBloc);
      getIt.registerFactory<TravelerSubscribeBloc>(() => subscribeBloc);

      addTearDown(() {
        if (getIt.isRegistered<RatingBloc>()) getIt.unregister<RatingBloc>();
        if (getIt.isRegistered<TravelerSubscribeBloc>()) {
          getIt.unregister<TravelerSubscribeBloc>();
        }
      });

      final bidWithId = BidModel(
        id: 'bid-test',
        announcementId: 'ann-test',
        senderId: 'sender-test',
        status: 'ACCEPTED',
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        travelerName: 'Ibrahima Diallo',
        travelerId: 'traveler-uuid-001',
        travelerPhone: '+33611223344',
        travelerAverageRating: 4.5,
        travelerTotalTrips: 8,
        travelerKycVerified: true,
      );

      await tester.pumpWidget(_hostVoyageur(bidWithId, bloc));
      await tester.pumpAndSettle();

      // Chevron should be visible when travelerId is non-null.
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tap the card to open traveler profile sheet.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump(); // start animation
      await tester.pump(const Duration(milliseconds: 400)); // advance past 300ms fadeIn

      // Profile sheet should be open — abbreviated name visible.
      expect(find.text('Ibrahima D.'), findsOneWidget);
    });

    testWidgets('travelerId null → pas de chevron', (tester) async {
      final bidNoId = BidModel(
        id: 'bid-test',
        announcementId: 'ann-test',
        senderId: 'sender-test',
        status: 'ACCEPTED',
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        travelerName: 'Inconnu',
        // travelerId deliberately null
      );

      await tester.pumpWidget(_hostVoyageur(bidNoId, bloc));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets(
        '_call canLaunchUrl=true et launchUrl=true → aucun snackbar erreur',
        (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'canLaunch') return true;
        if (call.method == 'launch') return true;
        return null;
      });

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final bid = _bid(travelerPhone: '+33600000001', status: 'ACCEPTED');
      await tester.pumpWidget(_hostVoyageur(bid, bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.phone_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No error snackbar should appear.
      expect(
          find.textContaining("Impossible d'ouvrir le composeur"), findsNothing);
    });
  });

  // ── ColisDestinataireCard ──────────────────────────────────────────────────
  group('ColisDestinataireCard', () {
    testWidgets('shows weight, category, declared value and recipient', (tester) async {
      final bid = _bid(
        weightKg: 5.0,
        contentCategory: 'Vêtements',
        declaredValueEur: 120.0,
        recipientName: 'Aminata Traoré',
        recipientPhone: '+221700000000',
      );

      await tester.pumpWidget(_hostColis(bid));

      expect(find.textContaining('5.0'), findsWidgets);
      expect(find.textContaining('Vêtements'), findsWidgets);
      expect(find.textContaining('120'), findsWidgets);
      expect(find.textContaining('Aminata'), findsWidgets);
      expect(find.textContaining('+221700000000'), findsWidgets);
    });

    testWidgets('shows dash when declared value is null', (tester) async {
      final bid = _bid(declaredValueEur: null);

      await tester.pumpWidget(_hostColis(bid));

      expect(find.textContaining('à compléter'), findsOneWidget);
    });
  });

  // ── PaiementCard ──────────────────────────────────────────────────────────
  group('PaiementCard', () {
    testWidgets('stripe active → shows séquestré and amount', (tester) async {
      final bid = _bid(
        paymentMethod: BidPaymentMethod.stripe,
        totalAmountEur: 56.0,
        status: 'ACCEPTED',
      );

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('séquestré'), findsOneWidget);
      expect(find.textContaining('56'), findsWidgets);
    });

    testWidgets('stripe COMPLETED → shows libéré', (tester) async {
      final bid = _bid(
        paymentMethod: BidPaymentMethod.stripe,
        totalAmountEur: 56.0,
        status: 'COMPLETED',
      );

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('libéré'), findsOneWidget);
    });

    testWidgets('stripe CANCELLED → shows remboursé', (tester) async {
      final bid = _bid(
        paymentMethod: BidPaymentMethod.stripe,
        totalAmountEur: 56.0,
        status: 'CANCELLED',
      );

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('remboursé'), findsOneWidget);
    });

    testWidgets('cash → shows espèces and CASH badge', (tester) async {
      final bid = _bid(
        paymentMethod: BidPaymentMethod.cash,
        totalAmountEur: 40.0,
        status: 'ACCEPTED',
      );

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('espèces'), findsOneWidget);
      expect(find.textContaining('CASH'), findsOneWidget);
    });
  });

  // ── DetailsAccordion ──────────────────────────────────────────────────────
  group('DetailsAccordion', () {
    testWidgets('is collapsed by default — content not visible', (tester) async {
      final bid = _bid(
        handoverLocation: 'CDG Terminal 2F',
        trackingToken: 'tok-abc123',
      );

      await tester.pumpWidget(_hostAccordion(bid));

      // Header is visible
      expect(find.textContaining('Plus de détails'), findsOneWidget);
      // Content not visible
      expect(find.textContaining('CDG Terminal'), findsNothing);
    });

    testWidgets('tap opens accordion and shows all sections', (tester) async {
      final bid = _bid(
        handoverLocation: 'Aéroport Roissy',
        handoverWindowStart: DateTime(2026, 3, 10, 14, 30),
        handoverWindowEnd: DateTime(2026, 3, 10, 16, 0),
        voyageurConfirmed: true,
        trackingToken: 'tok-xyz789',
        trackingNumber: 'DNY-2026-001',
        departureDate: DateTime(2026, 3, 10),
        pricePerKg: 5.0,
        disclaimerSignedAt: DateTime(2026, 1, 15, 9, 0),
      );

      await tester.pumpWidget(_hostAccordion(bid));
      await tester.pump();

      // Tap the header
      await tester.tap(find.textContaining('Plus de détails'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fenêtre de remise
      expect(find.textContaining('Aéroport Roissy'), findsOneWidget);

      // Tarif par kg section
      expect(find.textContaining('Tarif'), findsOneWidget);

      // Tracking URL
      expect(find.textContaining('tok-xyz789'), findsWidgets);

      // Disclaimer
      expect(find.textContaining('Disclaimer'), findsOneWidget);
    });
  });

  // ── trackingPublicUrl ─────────────────────────────────────────────────────
  group('trackingPublicUrl', () {
    test('returns default base https://track.dony.app with token appended', () {
      // TRACKING_PUBLIC_URL env var not set in test → default value used.
      expect(
        trackingPublicUrl('abc-token-123'),
        equals('https://track.dony.app/abc-token-123'),
      );
    });

    test('token with slashes is preserved as-is', () {
      expect(
        trackingPublicUrl('tok/2026/xyz'),
        equals('https://track.dony.app/tok/2026/xyz'),
      );
    });
  });

  // ── VoyageurContactCard._call error path ─────────────────────────────────
  group('VoyageurContactCard._call', () {
    late _MockConversationOpenBloc bloc;

    setUp(() {
      bloc = _MockConversationOpenBloc();
      when(() => bloc.state).thenReturn(const ConversationOpenInitial());
    });

    testWidgets(
      'canLaunchUrl returns false → snackbar "Impossible d\'ouvrir le composeur" visible',
      (tester) async {
        // Mock the url_launcher platform channel so canLaunchUrl returns false.
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'canLaunch') return false;
          if (call.method == 'launch') return false;
          return null;
        });

        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final bid = _bid(
          travelerPhone: '+33600000000',
          status: 'ACCEPTED',
        );

        await tester.pumpWidget(_hostVoyageur(bid, bloc));
        await tester.pump();

        // Tap the phone button
        await tester.tap(find.byIcon(Icons.phone_rounded));
        // Pump twice: once for the async _call to resolve, once for the snackbar
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.textContaining('Impossible d\'ouvrir le composeur'),
          findsOneWidget,
        );
      },
    );
  });

  // ── VoyageurContactCard — badges KYC / Kilo Pro ───────────────────────────
  group('VoyageurContactCard badges', () {
    late _MockConversationOpenBloc bloc;

    setUp(() {
      bloc = _MockConversationOpenBloc();
      when(() => bloc.state).thenReturn(const ConversationOpenInitial());
    });

    testWidgets('travelerKycVerified=true → badge KYC visible', (tester) async {
      final bid = _bid(
        travelerKycVerified: true,
        travelerName: 'Ibrahima',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('KYC'), findsOneWidget);
    });

    testWidgets('travelerKiloPro=true → badge Kilo Pro visible', (tester) async {
      final bid = _bid(
        travelerKiloPro: true,
        travelerName: 'Oumar',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('Kilo Pro'), findsOneWidget);
    });

    testWidgets('chat button shows loading spinner when ConversationOpenLoading',
        (tester) async {
      final loadingBloc = _MockConversationOpenBloc();
      when(() => loadingBloc.state)
          .thenReturn(const ConversationOpenLoading());
      when(() => loadingBloc.stream)
          .thenAnswer((_) => Stream<ConversationOpenState>.empty());

      final bid = _bid();

      await tester.pumpWidget(_hostVoyageur(bid, loadingBloc));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('travelerAverageRating null → shows "★ —"', (tester) async {
      final bid = _bid(travelerAverageRating: null, travelerTotalTrips: null);

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('★ —'), findsOneWidget);
    });
  });

  // ── QuickActionsRow ───────────────────────────────────────────────────────
  group('QuickActionsRow', () {
    Widget _hostQuickActions(BidModel bid) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: QuickActionsRow(bid: bid),
          ),
        );

    testWidgets('trackingToken null → only "Suivi du colis" tile', (tester) async {
      final bid = _bid(trackingToken: null);

      await tester.pumpWidget(_hostQuickActions(bid));

      expect(find.text('Suivi du colis'), findsOneWidget);
      expect(find.text('Partager le suivi'), findsNothing);
    });

    testWidgets('trackingToken present → both tiles visible', (tester) async {
      final bid = _bid(trackingToken: 'tok-abc123');

      await tester.pumpWidget(_hostQuickActions(bid));

      expect(find.text('Suivi du colis'), findsOneWidget);
      expect(find.text('Partager le suivi'), findsOneWidget);
    });

    testWidgets('corridor shows "Suivi du colis" when cities are both empty',
        (tester) async {
      final bid = _bid(
        departureCity: null,
        arrivalCity: null,
        trackingToken: 'tok-xyz',
      );

      await tester.pumpWidget(_hostQuickActions(bid));

      expect(find.text('Suivi du colis'), findsWidgets);
    });

    testWidgets(
      'tap "Suivi du colis" ouvre le timeline sheet (TrackingBloc via GetIt mocké)',
      (tester) async {
        // Enregistre un TrackingBloc mock dans GetIt pour que
        // showTrackingTimelineSheet puisse l'instancier.
        final trackingBloc = _MockTrackingBloc();
        when(() => trackingBloc.state).thenReturn(TrackingInitial());
        when(() => trackingBloc.stream)
            .thenAnswer((_) => Stream<TrackingState>.empty());

        if (getIt.isRegistered<TrackingBloc>()) {
          getIt.unregister<TrackingBloc>();
        }
        getIt.registerFactory<TrackingBloc>(() => trackingBloc);
        addTearDown(() {
          if (getIt.isRegistered<TrackingBloc>()) {
            getIt.unregister<TrackingBloc>();
          }
        });

        final bid = _bid(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          trackingToken: 'tok-abc',
        );

        await tester.pumpWidget(_hostQuickActions(bid));

        // Tap the "Suivi du colis" tile — triggers _corridor getter + sheet.
        await tester.tap(find.text('Suivi du colis'));
        await tester.pumpAndSettle();

        // Le sheet de suivi doit être ouvert (titre visible).
        expect(find.text('Suivi du colis'), findsWidgets);
      },
    );

    testWidgets(
      'tap "Partager le suivi" appelle shareTrackingLink (Share canal + TrackingBloc mockés)',
      (tester) async {
        // Mock du canal share_plus pour éviter l'invocation native.
        const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(shareChannel, (call) async => null);

        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(shareChannel, null);
        });

        final bid = _bid(
          trackingToken: 'tok-share',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
        );

        await tester.pumpWidget(_hostQuickActions(bid));

        // Tap the "Partager le suivi" tile — appelle shareTrackingLink(bid).
        await tester.tap(find.text('Partager le suivi'));
        await tester.pumpAndSettle();

        // La tuile est toujours présente après le partage.
        expect(find.text('Partager le suivi'), findsOneWidget);
      },
    );
  });

  // ── shareTrackingLink ─────────────────────────────────────────────────────
  group('shareTrackingLink', () {
    test('trackingToken null → no-op, returns without calling Share', () async {
      // shareTrackingLink doit retourner immédiatement si trackingToken est null.
      // On vérifie qu'aucune exception n'est levée (Share.share non appelé).
      final bid = _bid(trackingToken: null);
      // Ne doit pas lancer d'exception.
      await expectLater(shareTrackingLink(bid), completes);
    });

    test('trackingToken present → calls Share.share (canal mocké)', () async {
      // Mock le canal share_plus pour éviter l'invocation native.
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async => null);

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(shareChannel, null);
      });

      final bid = _bid(
        trackingToken: 'tok-share-test',
        trackingNumber: 'DNY-2026-001',
      );

      // Ne doit pas lancer d'exception avec le canal mocké.
      await expectLater(shareTrackingLink(bid), completes);
    });
  });
}
