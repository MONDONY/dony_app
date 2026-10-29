import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_details_content.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/tracking_actions.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'ACCEPTED',
  String? travelerName,
  bool travelerPhoneAvailable = false,
  bool? contactWindowOpen,
  double? travelerAverageRating,
  int? travelerTotalTrips,
  bool travelerKycVerified = false,
  bool travelerGpPro = false,
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
  DateTime? handoverDeadline,
  bool voyageurConfirmed = false,
  DateTime? disclaimerSignedAt,
  DateTime? departureDate,
  double? pricePerKg,
  String? departureCity,
  String? arrivalCity,
}) => BidModel(
  id: 'bid-test',
  announcementId: 'ann-test',
  senderId: 'sender-test',
  status: status,
  createdAt: DateTime(2026, 1, 15),
  updatedAt: DateTime(2026, 1, 15),
  travelerName: travelerName,
  travelerPhoneAvailable: travelerPhoneAvailable,
  contactWindowOpen: contactWindowOpen,
  travelerAverageRating: travelerAverageRating,
  travelerTotalTrips: travelerTotalTrips,
  travelerKycVerified: travelerKycVerified,
  travelerGpPro: travelerGpPro,
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
  handoverDeadline: handoverDeadline,
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
}) {
  final router = GoRouter(
    initialLocation: '/',
    observers: pushedRoutes == null ? null : [_RecordingObserver(pushedRoutes)],
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => Scaffold(
          body: MultiBlocProvider(
            providers: [BlocProvider<ConversationOpenBloc>.value(value: bloc)],
            child: VoyageurContactCard(bid: bid),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/public',
        builder: (ctx, state) =>
            const Scaffold(body: Text('profile-public-screen')),
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
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

Widget _hostDetails(BidModel bid) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(child: BidDetailsContent(bid: bid)),
  ),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    registerFallbackValue(const ConversationOpenRequested('bid-test'));
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

    // Un seul bouton « Contacter » : il ouvre la discussion. L'appel se lance
    // depuis la messagerie, plus depuis cette carte.
    Finder contactIcon() => find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'messages-square',
    );

    testWidgets('shows traveler name, rating and chat button', (tester) async {
      final bid = _bid(
        travelerName: 'Oumar Diallo',
        travelerAverageRating: 4.8,
        travelerTotalTrips: 12,
      );

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('Oumar Diallo'), findsOneWidget);
      expect(find.text('★ 4.8 · 12 trajets'), findsOneWidget);
      expect(contactIcon(), findsOneWidget);
      // Plus d'icônes d'appel et de message séparées sur la carte.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DonyIcon &&
              (w.name == 'message-circle' || w.name == 'phone'),
        ),
        findsNothing,
      );
    });

    testWidgets('plus de bouton d\'appel sur la carte, même joignable', (
      tester,
    ) async {
      final bid = _bid(travelerPhoneAvailable: true);

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(contactIcon(), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DonyIcon &&
              (w.name == 'phone' || w.name == 'message-circle'),
        ),
        findsNothing,
      );
    });

    testWidgets('tap chat button fires ConversationOpenRequested once', (
      tester,
    ) async {
      final bid = _bid();

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      await tester.tap(contactIcon());
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
        expect(
          find.byWidgetPredicate(
            (w) => w is DonyIcon && w.name == 'chevron-right',
          ),
          findsOneWidget,
        );

        // Tap the card — should navigate to /profile/public via GoRouter.
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        // The stub /profile/public screen renders this text.
        expect(find.text('profile-public-screen'), findsOneWidget);
      },
    );

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

      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsNothing,
      );
    });
  });

  // ── ColisDestinataireCard ──────────────────────────────────────────────────
  group('ColisDestinataireCard', () {
    Widget hostAs(BidModel bid, {required bool isSender}) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ColisDestinataireCard(bid: bid, isSender: isSender),
      ),
    );

    testWidgets(
      'voyageur, demande en attente : téléphone du destinataire masqué',
      (tester) async {
        final bid = _bid(
          status: 'PENDING',
          recipientName: 'Aminata Traoré',
          recipientPhone: '+221700000000',
        );
        await tester.pumpWidget(hostAs(bid, isSender: false));

        expect(find.textContaining('Aminata'), findsWidgets);
        expect(find.textContaining('+221700000000'), findsNothing);
      },
    );

    // FLUTTER-JT : le voyageur ne voit le numéro du destinataire qu'après le
    // retrait du colis, même si un ancien serveur le sert dès l'acceptation.
    testWidgets(
      'voyageur, demande acceptée : téléphone du destinataire encore masqué',
      (tester) async {
        final bid = _bid(recipientPhone: '+221700000000');
        await tester.pumpWidget(hostAs(bid, isSender: false));

        expect(find.textContaining('+221700000000'), findsNothing);
      },
    );

    testWidgets('voyageur, colis retiré : téléphone du destinataire visible', (
      tester,
    ) async {
      final bid = _bid(status: 'HANDED_OVER', recipientPhone: '+221700000000');
      await tester.pumpWidget(hostAs(bid, isSender: false));

      expect(find.textContaining('+221700000000'), findsWidgets);
    });

    testWidgets('expéditeur, demande en attente : téléphone visible', (
      tester,
    ) async {
      final bid = _bid(status: 'PENDING', recipientPhone: '+221700000000');
      await tester.pumpWidget(hostAs(bid, isSender: true));

      expect(find.textContaining('+221700000000'), findsWidgets);
    });

    for (final status in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
      testWidgets('expéditeur, $status : bouton « Modifier » présent', (
        tester,
      ) async {
        final bid = _bid(status: status, recipientPhone: '+221700000000');
        await tester.pumpWidget(hostAs(bid, isSender: true));

        expect(find.text('Modifier'), findsOneWidget);
        expect(find.byTooltip('Modifier le destinataire'), findsOneWidget);
      });
    }

    for (final status in ['PENDING', 'COMPLETED', 'CANCELLED']) {
      testWidgets('expéditeur, $status : pas de bouton « Modifier »', (
        tester,
      ) async {
        final bid = _bid(status: status, recipientPhone: '+221700000000');
        await tester.pumpWidget(hostAs(bid, isSender: true));

        expect(find.text('Modifier'), findsNothing);
      });
    }

    testWidgets('voyageur : jamais de bouton « Modifier »', (tester) async {
      final bid = _bid(status: 'IN_TRANSIT', recipientPhone: '+221700000000');
      await tester.pumpWidget(hostAs(bid, isSender: false));

      expect(find.text('Modifier'), findsNothing);
    });

    testWidgets('shows weight, category and recipient', (tester) async {
      final bid = _bid(
        weightKg: 5.0,
        contentCategory: 'Vêtements',
        recipientName: 'Aminata Traoré',
        recipientPhone: '+221700000000',
      );

      await tester.pumpWidget(_hostColis(bid));

      expect(find.textContaining('5 kg'), findsWidgets);
      expect(find.textContaining('Vêtements'), findsWidgets);
      expect(find.textContaining('Aminata'), findsWidgets);
      expect(find.textContaining('+221700000000'), findsWidgets);
    });

    testWidgets('anglais — titre et libellés traduits', (tester) async {
      useEnglish();
      final bid = _bid(
        weightKg: 5.0,
        recipientName: 'Aminata Traoré',
        recipientPhone: '+221700000000',
      );

      await tester.pumpWidget(_hostColis(bid));

      expect(find.text('Parcel & recipient'), findsOneWidget);
      expect(find.text('Parcel'), findsOneWidget);
      expect(find.text('Recipient'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
    });
  });

  // ── PaiementCard ──────────────────────────────────────────────────────────
  group('PaiementCard', () {
    testWidgets('stripe active → shows séquestré and amount', (tester) async {
      final bid = _bid(totalAmountEur: 56.0);

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('séquestré'), findsOneWidget);
      expect(find.textContaining('56'), findsWidgets);
    });

    testWidgets('stripe COMPLETED → shows libéré', (tester) async {
      final bid = _bid(totalAmountEur: 56.0, status: 'COMPLETED');

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('libéré'), findsOneWidget);
    });

    testWidgets('stripe CANCELLED → shows remboursé', (tester) async {
      final bid = _bid(totalAmountEur: 56.0, status: 'CANCELLED');

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('remboursé'), findsOneWidget);
    });

    testWidgets('cash → shows espèces and CASH badge', (tester) async {
      final bid = _bid(
        paymentMethod: BidPaymentMethod.cash,
        totalAmountEur: 40.0,
      );

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.textContaining('espèces'), findsOneWidget);
      expect(find.textContaining('CASH'), findsOneWidget);
    });

    testWidgets('anglais — titre et statut séquestre traduits', (tester) async {
      useEnglish();
      final bid = _bid(totalAmountEur: 56.0);

      await tester.pumpWidget(_hostPaiement(bid));

      expect(find.text('Payment'), findsOneWidget);
      expect(find.textContaining('on hold'), findsOneWidget);
    });
  });

  // ── BidDetailsContent (sheet « Plus de détails ») ─────────────────────────
  group('BidDetailsContent', () {
    testWidgets('shows all sections', (tester) async {
      final bid = _bid(
        handoverLocation: 'Aéroport Roissy',
        handoverDeadline: DateTime(2026, 3, 10, 16),
        voyageurConfirmed: true,
        trackingToken: 'tok-xyz789',
        trackingNumber: 'DNY-2026-001',
        departureDate: DateTime(2026, 3, 10),
        pricePerKg: 5.0,
        disclaimerSignedAt: DateTime(2026, 1, 15, 9),
      );

      await tester.pumpWidget(_hostDetails(bid));
      await tester.pump();

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

    testWidgets('ACCEPTED + présence non confirmée → "Non encore"', (
      tester,
    ) async {
      final bid = _bid(handoverLocation: 'CDG');
      await tester.pumpWidget(_hostDetails(bid));

      expect(find.text('Présence confirmée'), findsOneWidget);
      expect(find.text('Non encore'), findsOneWidget);
    });

    testWidgets(
      'HANDED_OVER → "Colis remis ✓" (pas de "Non encore" trompeur)',
      (tester) async {
        final bid = _bid(status: 'HANDED_OVER', handoverLocation: 'CDG');
        await tester.pumpWidget(_hostDetails(bid));

        expect(find.text('Colis remis ✓'), findsOneWidget);
        expect(find.text('Non encore'), findsNothing);
      },
    );

    // Régression : un colis ARRIVED est forcément passé par HANDED_OVER puis
    // IN_TRANSIT — afficher « Non encore » y était faux.
    testWidgets('ARRIVED → "Colis remis ✓" (jamais "Non encore")', (
      tester,
    ) async {
      final bid = _bid(status: 'ARRIVED', handoverLocation: 'CDG');
      await tester.pumpWidget(_hostDetails(bid));

      expect(find.text('Colis remis ✓'), findsOneWidget);
      expect(find.text('Non encore'), findsNothing);
    });

    testWidgets(
      'non-régression — Date limite (dd/MM/yyyy → DateFormat.yMd) : fr identique '
      'à l\'ancien motif, avec zéros de tête (5 mars)',
      (tester) async {
        final bid = _bid(
          handoverLocation: 'CDG',
          handoverDeadline: DateTime(2026, 3, 5, 16),
        );

        await tester.pumpWidget(_hostDetails(bid));

        // Ancien motif : DateFormat('dd/MM/yyyy').format(d) == '05/03/2026'.
        // Locale explicite ('fr') dans l'assertion : un DateFormat sans locale
        // pollue Intl.defaultLocale en test et casse les tests suivants.
        expect(
          find.text(
            DateFormat('dd/MM/yyyy', 'fr').format(DateTime(2026, 3, 5, 16)),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'anglais — Date limite (DateFormat.yMd) rendue à l\'anglo-saxonne',
      (tester) async {
        useEnglish();
        final bid = _bid(
          handoverLocation: 'CDG',
          handoverDeadline: DateTime(2026, 3, 5, 16),
        );

        await tester.pumpWidget(_hostDetails(bid));

        expect(
          find.text(DateFormat.yMd('en').format(DateTime(2026, 3, 5, 16))),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'anglais — sections et date de départ (DateFormat.yMMMEd) traduites',
      (tester) async {
        useEnglish();
        final bid = _bid(
          handoverLocation: 'CDG Terminal 2F',
          departureDate: DateTime(2026, 10, 6),
        );

        await tester.pumpWidget(_hostDetails(bid));

        expect(find.text('PARCEL DROP-OFF'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        expect(
          find.text(DateFormat.yMMMEd('en').format(DateTime(2026, 10, 6))),
          findsOneWidget,
        );
      },
    );
  });

  // ── trackingPublicUrl ─────────────────────────────────────────────────────
  group('trackingPublicUrl', () {
    test(
      'returns default base https://yadony.com/tracking with token appended',
      () {
        // TRACKING_PUBLIC_URL env var not set in test → default value used.
        expect(
          trackingPublicUrl('abc-token-123'),
          equals('https://yadony.com/tracking/abc-token-123'),
        );
      },
    );

    test('token with slashes is preserved as-is', () {
      expect(
        trackingPublicUrl('tok/2026/xyz'),
        equals('https://yadony.com/tracking/tok/2026/xyz'),
      );
    });
  });

  // ── VoyageurContactCard — badges KYC / GP Pro ───────────────────────────
  group('VoyageurContactCard badges', () {
    late _MockConversationOpenBloc bloc;

    setUp(() {
      bloc = _MockConversationOpenBloc();
      when(() => bloc.state).thenReturn(const ConversationOpenInitial());
    });

    testWidgets('travelerKycVerified=true → badge KYC visible', (tester) async {
      final bid = _bid(travelerKycVerified: true, travelerName: 'Ibrahima');

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('Identité'), findsOneWidget);
    });

    testWidgets('travelerGpPro=true → badge GP Pro visible', (tester) async {
      final bid = _bid(travelerGpPro: true, travelerName: 'Oumar');

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byType(GpProBadge), findsOneWidget);
    });

    testWidgets('travelerGpPro=false → pas de badge GP Pro', (tester) async {
      final bid = _bid(travelerName: 'Oumar');

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.byType(GpProBadge), findsNothing);
    });

    testWidgets(
      'chat button shows loading spinner when ConversationOpenLoading',
      (tester) async {
        final loadingBloc = _MockConversationOpenBloc();
        when(
          () => loadingBloc.state,
        ).thenReturn(const ConversationOpenLoading());
        when(
          () => loadingBloc.stream,
        ).thenAnswer((_) => const Stream<ConversationOpenState>.empty());

        final bid = _bid();

        await tester.pumpWidget(_hostVoyageur(bid, loadingBloc));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('travelerAverageRating null → shows "★ -"', (tester) async {
      final bid = _bid();

      await tester.pumpWidget(_hostVoyageur(bid, bloc));

      expect(find.text('★ -'), findsOneWidget);
    });

    testWidgets(
      'anglais — nom de repli, appel et compteur de trajets traduits',
      (tester) async {
        useEnglish();
        setSmsAuthEnabled(true);
        addTearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
        final bid = _bid(travelerTotalTrips: 3, travelerPhoneAvailable: true);

        await tester.pumpWidget(_hostVoyageur(bid, bloc));

        expect(find.text('Traveler'), findsOneWidget);
        expect(find.textContaining('3 trips'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Contact the traveler' &&
                w.properties.button == true,
          ),
          findsOneWidget,
        );
      },
    );
  });

  // ── openSenderTrackingTimeline ────────────────────────────────────────────
  group('openSenderTrackingTimeline', () {
    Widget hostTimelineOpener(BidModel bid) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openSenderTrackingTimeline(context, bid),
            child: const Text('open-timeline'),
          ),
        ),
      ),
    );

    testWidgets('ouvre le timeline sheet (TrackingBloc via GetIt mocké)', (
      tester,
    ) async {
      // Enregistre un TrackingBloc mock dans GetIt pour que
      // showTrackingTimelineSheet puisse l'instancier.
      final trackingBloc = _MockTrackingBloc();
      when(() => trackingBloc.state).thenReturn(TrackingInitial());
      when(
        () => trackingBloc.stream,
      ).thenAnswer((_) => const Stream<TrackingState>.empty());

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

      await tester.pumpWidget(hostTimelineOpener(bid));

      // Ouvre la feuille de suivi en lecture seule.
      await tester.tap(find.text('open-timeline'));
      await tester.pumpAndSettle();

      // La feuille de suivi en lecture seule est ouverte.
      expect(find.text('Suivi en lecture seule'), findsOneWidget);
    });

    testWidgets(
      'timeline sheet chargée avec token → bouton Partager le suivi, pas de placeholder',
      (tester) async {
        const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(shareChannel, (call) async => null);

        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(shareChannel, null);
        });

        final trackingBloc = _MockTrackingBloc();
        when(() => trackingBloc.state).thenReturn(TrackingEventsLoaded([]));
        when(
          () => trackingBloc.stream,
        ).thenAnswer((_) => const Stream<TrackingState>.empty());

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
          trackingToken: 'tok-share-sheet',
        );

        await tester.pumpWidget(hostTimelineOpener(bid));

        await tester.tap(find.text('open-timeline'));
        await tester.pumpAndSettle();

        expect(find.text("J'ouvre la confirmation"), findsNothing);
        expect(find.text('Partager le suivi'), findsWidgets);
      },
    );
  });

  // ── shareTrackingLink ─────────────────────────────────────────────────────
  group('shareTrackingLink', () {
    test('trackingToken null → no-op, returns without calling Share', () async {
      // shareTrackingLink doit retourner immédiatement si trackingToken est null.
      // On vérifie qu'aucune exception n'est levée (Share.share non appelé).
      final bid = _bid();
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
