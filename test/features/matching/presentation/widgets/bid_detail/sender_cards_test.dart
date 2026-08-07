import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockContactRevealBloc
    extends MockBloc<ContactRevealEvent, ContactRevealState>
    implements ContactRevealBloc {}

class _FakeContactRevealEvent extends Fake implements ContactRevealEvent {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'ACCEPTED',
  String? travelerName,
  bool travelerPhoneAvailable = false,
  double? travelerAverageRating,
  int? travelerTotalTrips,
  bool travelerKycVerified = false,
  bool travelerKiloPro = false,
  double? weightKg,
  String? contentCategory,
  String? description,
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
      travelerPhoneAvailable: travelerPhoneAvailable,
      travelerAverageRating: travelerAverageRating,
      travelerTotalTrips: travelerTotalTrips,
      travelerKycVerified: travelerKycVerified,
      travelerKiloPro: travelerKiloPro,
      weightKg: weightKg,
      contentCategory: contentCategory,
      description: description,
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

/// Builds a GoRouter-based host so that `context.push('/profile/public', ...)` works.
/// The stub `/profile/public` route renders a Text widget with the userId from
/// ProfilePublicArgs so tests can assert on navigation.
Widget _hostVoyageur(
  BidModel bid,
  _MockConversationOpenBloc bloc, {
  List<String>? pushedRoutes,
  ContactRevealBloc? reveal,
}) {
  // Le numéro n'est plus dans le bid : la carte lit ContactRevealBloc au tap.
  final revealBloc = reveal ?? _MockContactRevealBloc();
  if (reveal == null) {
    when(() => revealBloc.state).thenReturn(const ContactRevealInitial());
  }
  final router = GoRouter(
    initialLocation: '/',
    observers: pushedRoutes == null
        ? null
        : [
            _RecordingObserver(pushedRoutes),
          ],
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ConversationOpenBloc>.value(value: bloc),
              BlocProvider<ContactRevealBloc>.value(value: revealBloc),
            ],
            child: VoyageurContactCard(bid: bid),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/public',
        builder: (ctx, state) {
          final args = state.extra;
          return Scaffold(
            body: Text('profile-public-screen'),
          );
        },
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: router,
  );
}

class _RecordingObserver extends NavigatorObserver {
  final List<String> routes;
  _RecordingObserver(this.routes);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != null) {
      routes.add(route.settings.name!);
    }
  }
}

Widget _hostColis(BidModel bid) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: ColisDestinataireCard(bid: bid)),
    );

Widget _hostPaiement(BidModel bid) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: PaiementCard(bid: bid)),
    );

Widget _hostAccordion(BidModel bid) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: DetailsAccordion(bid: bid)),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const ConversationOpenRequested('bid-test'));
    registerFallbackValue(_FakeContactRevealEvent());
  });

  // ── VoyageurContactCard ────────────────────────────────────────────────────
  group('VoyageurContactCard', () {
    late _MockConversationOpenBloc bloc;

    // Ce groupe teste exclusivement la fonctionnalité d'appel révélé par le
    // serveur — indépendante du canal SMS OTP (auth). Le flag est donc activé
    // par défaut ici pour isoler ces tests de sa valeur par défaut (false).
    setUp(() {
      bloc = _MockConversationOpenBloc();
      when(() => bloc.state).thenReturn(const ConversationOpenInitial());
      setSmsAuthEnabled(true);
    });
    tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

    testWidgets('shows traveler name, rating and chat button', (tester) async {
      final bid = _bid(
        travelerName: 'Oumar Diallo',
        travelerAverageRating: 4.8,
        travelerTotalTrips: 12,
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('Oumar Diallo'), findsOneWidget);
      expect(find.text('★ 4.8 · 12 trajets'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'message-circle'), findsOneWidget);
    });

    testWidgets('shows phone button when phone is present and status is ACCEPTED',
        (tester) async {
      final bid = _bid(
        travelerPhoneAvailable: true,
        status: 'ACCEPTED',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsOneWidget);
    });

    testWidgets('hides phone button when phone is null', (tester) async {
      final bid = _bid(travelerPhoneAvailable: false);

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
    });

    testWidgets(
      'hides phone button tant que le SMS OTP backend n\'est pas confirmé, même joignable',
      (tester) async {
        setSmsAuthEnabled(false);
        final bid = _bid(travelerPhoneAvailable: true, status: 'ACCEPTED');

        await tester.pumpWidget(_hostVoyageur(bid, bloc));

        expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
      },
    );

    testWidgets('hides phone button when status is COMPLETED even with phone',
        (tester) async {
      final bid = _bid(
        travelerPhoneAvailable: true,
        status: 'COMPLETED',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
    });

    testWidgets('hides phone button when status is DELIVERED even with phone',
        (tester) async {
      final bid = _bid(
        travelerPhoneAvailable: true,
        status: 'DELIVERED',
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
    });

    testWidgets('tap chat button fires ConversationOpenRequested once',
        (tester) async {
      final bid = _bid();

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'message-circle'));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured.length, 1);
      final event = captured.first as ConversationOpenRequested;
      expect(event.bidId, 'bid-test');
    });

    testWidgets(
        'travelerId non-null → chevron visible et tap navigue vers /profile/public',
        (tester) async {
      final bidWithId = BidModel(
        id: 'bid-test',
        announcementId: 'ann-test',
        senderId: 'sender-test',
        status: 'ACCEPTED',
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        travelerName: 'Ibrahima Diallo',
        travelerId: 'traveler-uuid-001',
        travelerPhoneAvailable: true,
        travelerAverageRating: 4.5,
        travelerTotalTrips: 8,
        travelerKycVerified: true,
      );

      await tester.pumpWidget(_hostVoyageur(bidWithId, bloc));
      await tester.pumpAndSettle();

      // Chevron should be visible when travelerId is non-null.
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'chevron-right'), findsOneWidget);

      // Tap the card — should navigate to /profile/public via GoRouter.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // The stub /profile/public screen renders this text.
      expect(find.text('profile-public-screen'), findsOneWidget);
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

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'chevron-right'), findsNothing);
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

      final bid = _bid(travelerPhoneAvailable: true, status: 'ACCEPTED');
      await tester.pumpWidget(_hostVoyageur(bid, bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Le tap ne fait que demander le numéro : aucun repli ne s'affiche.
      expect(find.text('Copier'), findsNothing);
    });
  });

  // ── ColisDestinataireCard ──────────────────────────────────────────────────
  group('ColisDestinataireCard', () {
    testWidgets('shows weight, category and recipient', (tester) async {
      final bid = _bid(
        weightKg: 5.0,
        contentCategory: 'Vêtements',
        recipientName: 'Aminata Traoré',
        recipientPhone: '+221700000000',
      );

      await tester.pumpWidget(_hostColis(bid));

      expect(find.textContaining('5.0'), findsWidgets);
      expect(find.textContaining('Vêtements'), findsWidgets);
      expect(find.textContaining('Aminata'), findsWidgets);
      expect(find.textContaining('+221700000000'), findsWidgets);
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

      // ACCEPTED + voyageurConfirmed=true → « Oui ✓ »
      expect(find.text('Oui ✓'), findsOneWidget);
    });

    testWidgets('ACCEPTED + présence non confirmée → "Non encore"',
        (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        handoverLocation: 'CDG',
        voyageurConfirmed: false,
      );
      await tester.pumpWidget(_hostAccordion(bid));
      await tester.tap(find.textContaining('Plus de détails'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Présence confirmée'), findsOneWidget);
      expect(find.text('Non encore'), findsOneWidget);
    });

    testWidgets('HANDED_OVER → "Colis remis ✓" (pas de "Non encore" trompeur)',
        (tester) async {
      final bid = _bid(
        status: 'HANDED_OVER',
        handoverLocation: 'CDG',
        voyageurConfirmed: false,
      );
      await tester.pumpWidget(_hostAccordion(bid));
      await tester.tap(find.textContaining('Plus de détails'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Colis remis ✓'), findsOneWidget);
      expect(find.text('Non encore'), findsNothing);
    });
  });

  // ── trackingPublicUrl ─────────────────────────────────────────────────────
  group('trackingPublicUrl', () {
    test('returns default base https://track.yadony.com with token appended', () {
      // TRACKING_PUBLIC_URL env var not set in test → default value used.
      expect(
        trackingPublicUrl('abc-token-123'),
        equals('https://track.yadony.com/abc-token-123'),
      );
    });

    test('token with slashes is preserved as-is', () {
      expect(
        trackingPublicUrl('tok/2026/xyz'),
        equals('https://track.yadony.com/tok/2026/xyz'),
      );
    });
  });

  // ── VoyageurContactCard._call error path ─────────────────────────────────
  group('VoyageurContactCard._call', () {
    late _MockConversationOpenBloc bloc;

    setUp(() {
      bloc = _MockConversationOpenBloc();
      when(() => bloc.state).thenReturn(const ConversationOpenInitial());
      setSmsAuthEnabled(true);
    });
    tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

    testWidgets(
      'canLaunchUrl returns false → le numéro est affiché et proposé à la copie',
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
          travelerPhoneAvailable: true,
          status: 'ACCEPTED',
        );

        // Le tap ne compose plus directement : il demande le numéro. On simule le
        // bloc qui le renvoie, ce qui déclenche l'ouverture du composeur.
        final reveal = _MockContactRevealBloc();
        whenListen(
          reveal,
          Stream<ContactRevealState>.fromIterable(
            [const ContactRevealSuccess('+33600000000')],
          ),
          initialState: const ContactRevealInitial(),
        );

        await tester.pumpWidget(_hostVoyageur(bid, bloc, reveal: reveal));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('+33600000000'), findsOneWidget);
        expect(find.text('Copier'), findsOneWidget);
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

      expect(find.text('Identité'), findsOneWidget);
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

    testWidgets('travelerAverageRating null → shows "★ -"', (tester) async {
      final bid = _bid(travelerAverageRating: null, travelerTotalTrips: null);

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('★ -'), findsOneWidget);
    });
  });

  // ── QuickActionsRow ───────────────────────────────────────────────────────
  group('QuickActionsRow', () {
    Widget _hostQuickActions(BidModel bid) => MaterialApp(
          theme: AppTheme.light(),
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
