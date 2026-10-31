// Fiche colis, vue voyageur, vrai écran (`BidDetailScreen`) : un scénario par
// statut du colis. Chacun monte l'écran avec ses vrais providers (BLoCs
// simulés) et vérifie, d'un seul coup, le billet (tampon, zone du talon, titre),
// les sections du corps, la carte Gain et le footer. Les détails de chaque
// carte sont testés dans leurs propres fichiers ; ici on vérifie que l'écran
// assemble un tout cohérent pour chaque statut de l'inventaire.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBidAcceptanceBloc
    extends MockBloc<BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockProcedureCubit extends MockCubit<DeliveryNoShowProcedureState>
    implements DeliveryNoShowProcedureCubit {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockNotificationService extends Mock implements NotificationService {}

// ── Fixtures ─────────────────────────────────────────────────────────────────

const _kSenderId = 'sender-001';
const _kTravelerId = 'traveler-001';

final _past = DateTime.now().subtract(const Duration(days: 1));

BidModel _bid(
  String status, {
  bool voyageurConfirmed = false,
  DateTime? departureAt,
  DateTime? handoverDeadline,
  String? cancellationNoShowStatus,
  String? trackingNumber,
  String? rejectionReason,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: _kSenderId,
  senderName: 'Mariama D.',
  recipientName: 'Awa',
  weightKg: 3,
  totalAmountEur: 48,
  status: status,
  voyageurConfirmed: voyageurConfirmed,
  departureAt: departureAt,
  handoverDeadline: handoverDeadline,
  cancellationNoShowStatus: cancellationNoShowStatus,
  trackingNumber: trackingNumber,
  rejectionReason: rejectionReason,
  paymentMethod: paymentMethod,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

UserModel _user(String id) => UserModel(
  id: id,
  roles: const ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

/// Noms des sections du corps, dans l'ordre du code.
const _sectionNames = [
  'billet',
  'hero',
  'todo',
  'info-awaiting-payment',
  'info-scan-blocked',
  'info-locked',
  'info-supplement',
  'info-amendment',
  'info-reschedule',
  'info-noshow',
  'expediteur',
  'gain',
  'transport',
  'rating',
];

Finder _section(String name) => find.byKey(ValueKey<String>(name));

List<String> _sections(WidgetTester tester) {
  final present = [
    for (final name in _sectionNames)
      if (_section(name).evaluate().isNotEmpty) name,
  ];
  double top(String name) => tester.getTopLeft(_section(name)).dy;
  return present..sort((a, b) => top(a).compareTo(top(b)));
}

/// Texte (ou widget) [what] dans la section [name].
Finder _in(String name, Finder what) =>
    find.descendant(of: _section(name), matching: what);

void main() {
  late _MockBidBloc bidBloc;
  late _MockAuthBloc authBloc;
  late _MockProcedureCubit procedure;

  setUpAll(() async {
    registerFallbackValue(BidDetailRequested('fallback'));
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('fr');
  });

  setUp(() async {
    DonySnackbar.clearDedup();
    bidBloc = _MockBidBloc();
    authBloc = _MockAuthBloc();
    procedure = _MockProcedureCubit();
    final acceptanceBloc = _MockBidAcceptanceBloc();
    final cancellationBloc = _MockCancellationBloc();
    final trackingBloc = _MockTrackingBloc();
    final conversationOpenBloc = _MockConversationOpenBloc();
    final ratingBloc = _MockRatingBloc();
    final paymentRepository = _MockPaymentRepository();
    final notificationService = _MockNotificationService();

    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => bidBloc.stream,
    ).thenAnswer((_) => const Stream<BidState>.empty());
    when(() => cancellationBloc.state).thenReturn(CancellationInitial());
    when(
      () => cancellationBloc.stream,
    ).thenAnswer((_) => const Stream<CancellationState>.empty());
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(
      () => trackingBloc.stream,
    ).thenAnswer((_) => const Stream<TrackingState>.empty());
    when(
      () => conversationOpenBloc.state,
    ).thenReturn(const ConversationOpenInitial());
    when(
      () => conversationOpenBloc.stream,
    ).thenAnswer((_) => const Stream<ConversationOpenState>.empty());
    when(() => ratingBloc.state).thenReturn(const RatingInitial());
    when(
      () => ratingBloc.stream,
    ).thenAnswer((_) => const Stream<RatingState>.empty());
    when(() => acceptanceBloc.state).thenReturn(acs.BidAcceptanceInitial());
    when(
      () => acceptanceBloc.stream,
    ).thenAnswer((_) => const Stream<acs.BidAcceptanceState>.empty());
    when(
      () => authBloc.state,
    ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
    when(
      () => authBloc.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    when(
      () => paymentRepository.getPaymentForBid(any()),
    ).thenAnswer((_) async => null);
    when(
      () => notificationService.foregroundPushStream,
    ).thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
    whenListen(
      procedure,
      const Stream<DeliveryNoShowProcedureState>.empty(),
      initialState: const DeliveryNoShowProcedureUnavailable(),
    );
    when(() => procedure.load(any())).thenAnswer((_) async {});

    final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
    await analytics.onConfigured();

    await getIt.reset();
    getIt
      ..registerFactory<BidBloc>(() => bidBloc)
      ..registerFactory<BidAcceptanceBloc>(() => acceptanceBloc)
      ..registerFactory<CancellationBloc>(() => cancellationBloc)
      ..registerFactory<TrackingBloc>(() => trackingBloc)
      ..registerFactory<ConversationOpenBloc>(() => conversationOpenBloc)
      ..registerFactory<RatingBloc>(() => ratingBloc)
      ..registerFactory<DeliveryNoShowProcedureCubit>(() => procedure)
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerLazySingleton<PaymentRepository>(() => paymentRepository)
      ..registerSingleton<NotificationService>(notificationService);
  });

  tearDown(() async => getIt.reset());

  Future<void> pumpScreen(WidgetTester tester, BidModel bid) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: BidDetailScreen(bid: bid),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    // Stagger d'entrée (flutter_animate) et chargement du paiement.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Un scénario : le statut du colis, ce que l'écran doit montrer.
  final scenarios = <String, _Scenario>{
    'PENDING': _Scenario(
      bid: _bid('PENDING'),
      stamp: 'À décider',
      title: '#BID-00',
      sections: ['billet', 'hero', 'expediteur', 'gain', 'transport'],
      footer: ['Refuser', 'Accepter'],
      gain: 'VOUS RECEVEZ',
      hero: 'vous demande de transporter son colis',
    ),
    'PAYMENT_ESCROWED': _Scenario(
      bid: _bid('PAYMENT_ESCROWED'),
      stamp: 'À décider',
      title: '#BID-00',
      sections: ['billet', 'hero', 'expediteur', 'gain', 'transport'],
      footer: ['Refuser', 'Accepter'],
      gain: 'VOUS RECEVEZ',
      hero: 'vous demande de transporter son colis',
    ),
    'AWAITING_PAYMENT': _Scenario(
      bid: _bid('AWAITING_PAYMENT'),
      stamp: 'Paiement en attente',
      title: '#BID-00',
      sections: ['billet', 'hero', 'expediteur', 'gain', 'transport'],
      talon: "En attente du paiement de l'expéditeur",
      gain: 'VOUS RECEVEZ',
    ),
    'ACCEPTED (présence à confirmer)': _Scenario(
      bid: _bid('ACCEPTED'),
      stamp: 'Confirmé',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      footer: ['Confirmer ma présence'],
      gain: 'VOUS RECEVEZ',
    ),
    'ACCEPTED (présence confirmée)': _Scenario(
      bid: _bid('ACCEPTED', voyageurConfirmed: true),
      stamp: 'Confirmé',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      footer: ['Lire le QR du colis'],
      gain: 'VOUS RECEVEZ',
    ),
    // Date limite dépassée, présence non confirmée × état de la déclaration
    // d'absence de l'expéditeur, table écrite à la main.
    // - Aucune : « Signaler l'absence de l'expéditeur » dans « À traiter »,
    //   le footer garde le scan du départ (le back n'expire pas un colis
    //   accepté).
    // - En attente : héros d'information sous le billet, et le scan reste
    //   proposé : le back lève la déclaration au scan de départ (RESOLVED).
    // - Contestée : héros « Absence contestée », pas de footer (le back
    //   refuserait le scan, 409 `handover-sender-noshow-pending`).
    // - Confirmée (colis pas encore relu en annulé) : ni héros ni footer.
    // - Levée : plus d'alerte, ni de « Signaler » (une seule déclaration par
    //   colis), le scan reste proposé.
    'ACCEPTED, date limite dépassée, aucune déclaration': _Scenario(
      bid: _bid('ACCEPTED', handoverDeadline: _past),
      stamp: 'Confirmé',
      title: '#BID-00',
      sections: ['billet', 'todo', 'expediteur', 'gain', 'transport'],
      footer: ['Lire le QR du colis'],
      gain: 'VOUS RECEVEZ',
      todo: "Signaler l'absence de l'expéditeur",
    ),
    'ACCEPTED, date limite dépassée, absence PENDING_CONFIRMATION': _Scenario(
      bid: _bid(
        'ACCEPTED',
        handoverDeadline: _past,
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      ),
      stamp: 'Confirmé',
      title: '#BID-00',
      sections: ['billet', 'hero', 'expediteur', 'gain', 'transport'],
      footer: ['Lire le QR du colis'],
      gain: 'VOUS RECEVEZ',
      hero: 'Absence signalée',
    ),
    'ACCEPTED, date limite dépassée, absence CONTESTED': _Scenario(
      bid: _bid(
        'ACCEPTED',
        handoverDeadline: _past,
        cancellationNoShowStatus: 'CONTESTED',
      ),
      stamp: 'Confirmé',
      title: '#BID-00',
      sections: ['billet', 'hero', 'expediteur', 'gain', 'transport'],
      gain: 'VOUS RECEVEZ',
      hero: 'Absence contestée',
    ),
    'ACCEPTED, date limite dépassée, absence CONFIRMED': _Scenario(
      bid: _bid(
        'ACCEPTED',
        handoverDeadline: _past,
        cancellationNoShowStatus: 'CONFIRMED',
      ),
      stamp: 'Confirmé',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      gain: 'VOUS RECEVEZ',
    ),
    'ACCEPTED, date limite dépassée, absence RESOLVED': _Scenario(
      bid: _bid(
        'ACCEPTED',
        handoverDeadline: _past,
        cancellationNoShowStatus: 'RESOLVED',
      ),
      stamp: 'Confirmé',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      footer: ['Lire le QR du colis'],
      gain: 'VOUS RECEVEZ',
    ),
    'HANDED_OVER': _Scenario(
      bid: _bid('HANDED_OVER', departureAt: _past, trackingNumber: 'YAD-0042'),
      stamp: 'En route',
      title: '#YAD-0042',
      sections: ['billet', 'info-noshow', 'expediteur', 'gain', 'transport'],
      footer: ['Valider la remise'],
      talon: 'NUMÉRO DE SUIVI',
      gain: 'VOUS RECEVEZ',
    ),
    'IN_TRANSIT': _Scenario(
      bid: _bid('IN_TRANSIT', departureAt: _past, trackingNumber: 'YAD-0042'),
      stamp: 'En transit',
      title: '#YAD-0042',
      sections: ['billet', 'info-noshow', 'expediteur', 'gain', 'transport'],
      footer: ['Valider la remise'],
      talon: 'NUMÉRO DE SUIVI',
      gain: 'VOUS RECEVEZ',
    ),
    'ARRIVED': _Scenario(
      bid: _bid('ARRIVED', departureAt: _past, trackingNumber: 'YAD-0042'),
      stamp: 'Arrivé',
      title: '#YAD-0042',
      sections: ['billet', 'info-noshow', 'expediteur', 'gain', 'transport'],
      footer: ['Valider la remise'],
      talon: 'NUMÉRO DE SUIVI',
      gain: 'VOUS RECEVEZ',
    ),
    'COMPLETED': _Scenario(
      bid: _bid('COMPLETED', trackingNumber: 'YAD-0042'),
      stamp: 'Livré',
      title: '#YAD-0042',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      talon: 'Colis livré',
      gain: 'VOUS AVEZ REÇU',
    ),
    'REJECTED': _Scenario(
      bid: _bid('REJECTED'),
      stamp: 'Refusé',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      talon: 'Cette demande est terminée.',
      gain: 'PAIEMENT',
    ),
    'CANCELLED': _Scenario(
      bid: _bid('CANCELLED'),
      stamp: 'Annulé',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      talon: 'Cette demande est terminée.',
      gain: 'PAIEMENT',
    ),
    'NO_SHOW': _Scenario(
      bid: _bid('NO_SHOW'),
      stamp: 'Absent',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      gain: 'PAIEMENT',
      talon: 'Cette demande est terminée.',
      talonReason: 'Absence constatée',
    ),
    'PARCEL_REFUSED': _Scenario(
      bid: _bid('PARCEL_REFUSED'),
      stamp: 'Colis refusé',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      gain: 'PAIEMENT',
      talon: 'Cette demande est terminée.',
      talonReason: 'Colis refusé à la remise',
    ),
    'EXPIRED (sans motif)': _Scenario(
      bid: _bid('EXPIRED'),
      stamp: 'Expiré',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      gain: 'PAIEMENT',
      talon: 'Cette demande est terminée.',
      talonReason: 'Demande expirée',
    ),
    'EXPIRED (date limite de dépôt passée)': _Scenario(
      bid: _bid('EXPIRED', rejectionReason: 'HANDOVER_DEADLINE_PASSED'),
      stamp: 'Expiré',
      title: '#BID-00',
      sections: ['billet', 'expediteur', 'gain', 'transport'],
      talon: 'Date limite de dépôt passée',
      gain: 'PAIEMENT',
    ),
  };

  group('un écran cohérent par statut', () {
    for (final MapEntry(key: name, value: s) in scenarios.entries) {
      testWidgets(name, (tester) async {
        await pumpScreen(tester, s.bid);

        // Billet : tampon, zone du talon, titre de l'app bar.
        expect(
          find.descendant(
            of: find.byType(BilletStatusStamp),
            matching: find.text(s.stamp),
          ),
          findsOneWidget,
        );
        expect(find.text(s.title), findsOneWidget);
        if (s.talon != null) {
          expect(_in('billet', find.text(s.talon!)), findsWidgets);
        }
        if (s.talonReason != null) {
          expect(_in('billet', find.text(s.talonReason!)), findsOneWidget);
        }
        // Plus de bouton « Lire les QR des étapes » dans le talon du voyageur
        // (le footer porte le scan) ; avant la remise, plus de talon du tout.
        expect(find.text('Lire les QR des étapes'), findsNothing);
        if (s.bid.status == 'ACCEPTED') {
          expect(find.byType(BilletTalon), findsNothing);
        }

        // Sections du corps, dans l'ordre.
        expect(find.byType(TravelerDetailBody), findsOneWidget);
        expect(_sections(tester), s.sections);
        expect(_in('transport', find.text('Votre transport')), findsOneWidget);
        if (s.hero != null) {
          expect(_in('hero', find.textContaining(s.hero!)), findsOneWidget);
        }
        if (s.todo != null) {
          expect(_in('todo', find.textContaining(s.todo!)), findsOneWidget);
        }
        // Une fois une déclaration faite, plus de « Signaler l'absence ».
        if (s.bid.cancellationNoShowStatus != null) {
          expect(
            find.textContaining("Signaler l'absence de l'expéditeur"),
            findsNothing,
          );
        }

        // Carte Gain.
        expect(_in('gain', find.text(s.gain)), findsOneWidget);

        // Footer : exactement les boutons attendus, ou aucun.
        if (s.footer.isEmpty) {
          expect(find.byType(TravelerStickyBar), findsNothing);
          expect(TravelerStickyBar.hasAction(s.bid), isFalse);
        } else {
          expect(find.byType(TravelerStickyBar), findsOneWidget);
          for (final label in s.footer) {
            expect(
              find.descendant(
                of: find.byType(TravelerStickyBar),
                matching: find.text(label),
              ),
              findsOneWidget,
              reason: label,
            );
          }
        }

        // Menu Options présent, jamais d'icône de partage du suivi dans la
        // barre d'application (réservée à l'expéditeur).
        final fr = AppLocalizationsFr();
        expect(find.byTooltip(fr.bidDetailOptionsTitle), findsOneWidget);
        expect(find.byTooltip(fr.bidDetailShareTracking), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    test('la table couvre tous les statuts de l\'inventaire', () {
      final covered = {for (final s in scenarios.values) s.bid.status};
      expect(
        covered,
        containsAll(<String>[
          'PENDING',
          'PAYMENT_ESCROWED',
          'AWAITING_PAYMENT',
          'ACCEPTED',
          'HANDED_OVER',
          'IN_TRANSIT',
          'ARRIVED',
          'COMPLETED',
          'REJECTED',
          'CANCELLED',
          'NO_SHOW',
          'EXPIRED',
          'PARCEL_REFUSED',
        ]),
      );
    });
  });

  group('colis payé en espèces', () {
    testWidgets('en cours : « VOUS ENCAISSEZ »', (tester) async {
      await pumpScreen(
        tester,
        _bid('ACCEPTED', paymentMethod: BidPaymentMethod.cash),
      );
      expect(_in('gain', find.text('VOUS ENCAISSEZ')), findsOneWidget);
    });

    for (final status in [
      'REJECTED',
      'CANCELLED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
    ]) {
      testWidgets('$status : « PAIEMENT » / « Paiement annulé. »', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          _bid(status, paymentMethod: BidPaymentMethod.cash),
        );
        expect(_in('gain', find.text('PAIEMENT')), findsOneWidget);
        expect(_in('gain', find.text('Paiement annulé.')), findsOneWidget);
        expect(find.text('VOUS ENCAISSEZ'), findsNothing);
      });
    }
  });

  group('en anglais', () {
    testWidgets('PENDING : tampon, footer et gain traduits', (tester) async {
      useEnglish();
      await pumpScreen(tester, _bid('PENDING'));
      expect(find.text('To decide'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TravelerStickyBar),
          matching: find.text('Accept'),
        ),
        findsOneWidget,
      );
      expect(find.text('Your trip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EXPIRED à la date limite : bloc traduit', (tester) async {
      useEnglish();
      await pumpScreen(
        tester,
        _bid('EXPIRED', rejectionReason: 'HANDOVER_DEADLINE_PASSED'),
      );
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Drop-off deadline passed'), findsOneWidget);
      expect(find.byType(TravelerStickyBar), findsNothing);
    });

    testWidgets('ACCEPTED, date limite dépassée : « Scan the parcel QR »', (
      tester,
    ) async {
      useEnglish();
      await pumpScreen(tester, _bid('ACCEPTED', handoverDeadline: _past));
      expect(
        find.descendant(
          of: find.byType(TravelerStickyBar),
          matching: find.text('Scan the parcel QR'),
        ),
        findsOneWidget,
      );
      expect(find.text('Confirm my presence'), findsNothing);
    });

    testWidgets('COMPLETED : colis livré', (tester) async {
      useEnglish();
      await pumpScreen(tester, _bid('COMPLETED'));
      expect(find.text('Parcel delivered'), findsOneWidget);
      expect(find.byType(TravelerStickyBar), findsNothing);
    });
  });

  // FLUTTER-XF : colis d'un ancien compte resté en cache après un changement
  // de compte. Le lecteur n'est ni l'expéditeur ni le voyageur : jamais la
  // vue voyageur et ses boutons Accepter / Refuser.
  group('lecteur étranger au colis', () {
    BidModel bidWithTraveler() => BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: _kSenderId,
      travelerId: _kTravelerId,
      senderName: 'Mariama D.',
      recipientName: 'Awa',
      weightKg: 3,
      totalAmountEur: 48,
      status: 'PENDING',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

    testWidgets('ni expéditeur ni voyageur → « demande indisponible »', (
      tester,
    ) async {
      when(
        () => authBloc.state,
      ).thenReturn(AuthAuthenticated(_user('compte-tiers')));
      await pumpScreen(tester, bidWithTraveler());

      expect(find.text("Cette demande n'existe plus"), findsOneWidget);
      expect(find.byType(TravelerStickyBar), findsNothing);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
    });

    testWidgets('le voyageur du colis garde sa vue et ses boutons', (
      tester,
    ) async {
      await pumpScreen(tester, bidWithTraveler());

      expect(find.text("Cette demande n'existe plus"), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TravelerStickyBar),
          matching: find.text('Accepter'),
        ),
        findsOneWidget,
      );
    });
  });
}

class _Scenario {
  const _Scenario({
    required this.bid,
    required this.stamp,
    required this.title,
    required this.sections,
    required this.gain,
    this.footer = const [],
    this.talon,
    this.hero,
    this.todo,
    this.talonReason,
  });

  final BidModel bid;
  final String stamp;
  final String title;
  final List<String> sections;
  final String gain;

  /// Libellés des boutons du footer (vide = pas de footer).
  final List<String> footer;

  /// Texte de la zone du talon (null = rien à vérifier).
  final String? talon;

  /// Fragment du titre du hero.
  final String? hero;

  /// Fragment attendu dans la section « À traiter » (null = rien à vérifier).
  final String? todo;

  /// Motif affiché au-dessus du message terminal (NO_SHOW, PARCEL_REFUSED,
  /// EXPIRED hors date limite).
  final String? talonReason;
}
