// Corps de la fiche colis, vue voyageur : billet, hero (demande à décider ou
// attente du paiement sous le billet, alerte à bouton dans « À traiter »),
// « À traiter », informations sans titre, expéditeur, gain,
// « Votre transport » et badge d'évaluation. Chaque section porte une clé
// (KeyedSubtree) : les tests lisent l'ordre des sections présentes.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_procedure_card.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_details_content.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart'
    show RatingDoneBadge;
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_info_cards.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_transport_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../helpers/mock_analytics_backend.dart';

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockAmendmentRepo extends Mock implements BidAmendmentRepository {}

class _MockSupplementRepo extends Mock implements BidSupplementRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockCancelBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockProcedureCubit extends MockCubit<DeliveryNoShowProcedureState>
    implements DeliveryNoShowProcedureCubit {}

BidModel _bid(
  String status, {
  String? trackingToken,
  String? recipientPhone,
  List<BidAmendment> amendments = const [],
  BidSupplement? supplement,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  bool voyageurConfirmed = false,
  DateTime? departureAt,
  DateTime? handoverDeadline,
  String? cancellationNoShowStatus,
  String? deliveryNoShowStatus,
  bool? deliveryNoShowReportedByTraveler,
  TripRescheduleInfo? reschedule,
  bool recipientDeclined = false,
  bool travelerHasRated = false,
}) => BidModel(
  amendments: amendments,
  supplement: supplement,
  paymentMethod: paymentMethod,
  voyageurConfirmed: voyageurConfirmed,
  departureAt: departureAt,
  handoverDeadline: handoverDeadline,
  cancellationNoShowStatus: cancellationNoShowStatus,
  deliveryNoShowStatus: deliveryNoShowStatus,
  deliveryNoShowReportedByTraveler: deliveryNoShowReportedByTraveler,
  reschedule: reschedule,
  recipientDeclined: recipientDeclined,
  travelerHasRated: travelerHasRated,
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  trackingToken: trackingToken,
  totalAmountEur: 48,
  senderName: 'Mariama D.',
  recipientName: 'Awa',
  recipientPhone: recipientPhone,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

final _past = DateTime.now().subtract(const Duration(days: 1));
final _future = DateTime.now().add(const Duration(days: 2));

TripRescheduleInfo _reschedule({required bool pending}) => TripRescheduleInfo(
  id: 'r1',
  reason: 'FLIGHT_CANCELLED',
  previousDepartureDate: DateTime(2026, 10, 9),
  newDepartureDate: DateTime(2026, 10, 13),
  decisionPending: pending,
  decisionDeadline: DateTime(2026, 10, 12, 18),
);

BidSupplement _supplement(BidSupplementStatus status, {bool cash = false}) =>
    BidSupplement(
      id: 'sup-1',
      status: status,
      rail: cash ? 'CASH' : 'STRIPE',
      netAmount: 15,
      commissionAmount: 2,
      grossAmount: 17,
      blocksHandover: status.isOpen,
      // Retirée en espèces : la carte ne parle que d'une commission prélevée.
      commissionStatus: cash ? SupplementCommissionStatus.charged : null,
    );

BidAmendment _amendment(BidAmendmentStatus status, {String id = 'am-1'}) =>
    BidAmendment(
      id: id,
      status: status,
      rail: 'CASH',
      addedWeightKg: 3,
      grossAmount: 26.8,
      netAmount: 23.5,
      commissionAmount: 3.3,
      blocksHandover: status.isOpen,
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

/// Sections présentes, triées de haut en bas.
List<String> _sections(WidgetTester tester) {
  final present = [
    for (final name in _sectionNames)
      if (_section(name).evaluate().isNotEmpty) name,
  ];
  double top(String name) => tester.getTopLeft(_section(name)).dy;
  return present..sort((a, b) => top(a).compareTo(top(b)));
}

/// [child] est-il dans la section [name] ?
Finder _inSection(String name, Finder child) =>
    find.descendant(of: _section(name), matching: child);

/// Tuile « Supplément de prix » de « À traiter ».
final _supplementTile = find.byKey(const Key('traveler-todo-supplement'));

/// Pied du sheet de cette tuile (« Valider le paiement »).
final _supplementSheetFooter = find.byKey(
  const Key('supplement-commission-confirm-btn'),
);

/// Colis payé en espèces dont les frais du supplément attendent le voyageur.
BidModel _commissionPending({String status = 'ACCEPTED'}) => _bid(
  status,
  paymentMethod: BidPaymentMethod.cash,
  supplement: _supplement(BidSupplementStatus.commissionPending, cash: true),
);

/// Si « À traiter » est affiché, il a du contenu sous son titre.
void _expectTodoNeverEmpty(WidgetTester tester) {
  final todo = _section('todo');
  if (todo.evaluate().isEmpty) return;
  final title = find.descendant(of: todo, matching: find.text('À traiter'));
  final titleHeight = tester.getSize(title).height;
  // Titre, espace sous le titre, puis au moins 20 px de contenu.
  expect(
    tester.getSize(todo).height,
    greaterThan(titleHeight + DonySpacing.md + 20),
  );
}

Future<void> _pump(
  WidgetTester tester,
  BidModel bid, {
  bool focusSupplement = false,
  bool focusAmendment = false,
  AuthBloc? authBloc,
  Size size = const Size(800, 4000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final conv = _MockConvBloc();
  final cancel = _MockCancelBloc();
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  when(() => cancel.state).thenReturn(CancellationInitial());
  Widget body = MultiBlocProvider(
    providers: [
      BlocProvider<ConversationOpenBloc>.value(value: conv),
      BlocProvider<CancellationBloc>.value(value: cancel),
    ],
    child: TravelerDetailBody(
      bid: bid,
      focusSupplement: focusSupplement,
      focusAmendment: focusAmendment,
    ),
  );
  if (authBloc != null) {
    body = BlocProvider<AuthBloc>.value(value: authBloc, child: body);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: body),
    ),
  );
  // Stagger d'entrée (flutter_animate) : laisse ses timers se terminer.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  late _MockProcedureCubit procedure;
  late MockAnalyticsBackend tileBackend;
  late _MockAnalytics analytics;

  setUp(() async {
    DonySnackbar.clearDedup();
    // Carte « destinataire absent » (FLUTTER-E2) d'un colis ARRIVED : procédure
    // indisponible, l'écran garde l'ancien signalement.
    procedure = _MockProcedureCubit();
    whenListen(
      procedure,
      const Stream<DeliveryNoShowProcedureState>.empty(),
      initialState: const DeliveryNoShowProcedureUnavailable(),
    );
    when(() => procedure.load(any())).thenAnswer((_) async {});

    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    final amendmentRepo = _MockAmendmentRepo();
    final supplementRepo = _MockSupplementRepo();
    tileBackend = MockAnalyticsBackend();
    final tileAnalytics = makeEnabledAnalytics(tileBackend);
    await tileAnalytics.onConfigured();

    await getIt.reset();
    getIt
      ..registerFactory<DeliveryNoShowProcedureCubit>(() => procedure)
      ..registerSingleton<AnalyticsService>(tileAnalytics)
      ..registerFactory<SupplementActionCubit>(
        () => SupplementActionCubit(supplementRepo, analytics),
      )
      ..registerFactory<SupplementCommissionCubit>(
        () => SupplementCommissionCubit(
          SupplementCommissionFlow(supplementRepo, analytics),
          analytics,
        ),
      )
      ..registerFactory<AmendmentActionCubit>(
        () => AmendmentActionCubit(amendmentRepo, analytics),
      )
      ..registerFactory<AmendmentAcceptCubit>(
        () => AmendmentAcceptCubit(
          amendmentRepo,
          analytics,
          AmendmentCommissionFlow(amendmentRepo, analytics),
        ),
      );
  });

  tearDown(() async => getIt.reset());

  // ── Ordre global, un scénario par statut ──────────────────────────────────
  group('ordre des sections par statut', () {
    const base = ['expediteur', 'gain', 'transport'];
    final cases = <String, (BidModel, List<String>)>{
      'PENDING': (_bid('PENDING'), ['billet', 'hero', ...base]),
      'PAYMENT_ESCROWED': (
        _bid('PAYMENT_ESCROWED'),
        ['billet', 'hero', ...base],
      ),
      'AWAITING_PAYMENT carte': (
        _bid('AWAITING_PAYMENT'),
        ['billet', 'hero', ...base],
      ),
      'AWAITING_PAYMENT mobile money': (
        _bid('AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.mobileMoney),
        ['billet', 'hero', 'info-awaiting-payment', ...base],
      ),
      // Plus de carte « prochaine étape » d'information pour les étapes du
      // transport (décision du propriétaire) : rien entre le billet et la
      // suite.
      'ACCEPTED présence non confirmée': (
        _bid('ACCEPTED', handoverDeadline: _future),
        ['billet', ...base],
      ),
      'ACCEPTED présence confirmée': (
        _bid('ACCEPTED', voyageurConfirmed: true, handoverDeadline: _future),
        ['billet', ...base],
      ),
      // « À traiter » ET informations dans le même scénario : la commission
      // à valider va sous « À traiter », le scan bloqué et le report décidé
      // restent des informations, dans cet ordre.
      'ACCEPTED confirmée, commission à valider, report décidé': (
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          handoverDeadline: _future,
          paymentMethod: BidPaymentMethod.cash,
          supplement: _supplement(
            BidSupplementStatus.commissionPending,
            cash: true,
          ),
          reschedule: _reschedule(pending: false),
        ),
        ['billet', 'todo', 'info-scan-blocked', 'info-reschedule', ...base],
      ),
      'ACCEPTED date limite dépassée': (
        _bid('ACCEPTED', handoverDeadline: _past),
        ['billet', 'todo', ...base],
      ),
      'ACCEPTED date limite dépassée, présence confirmée': (
        _bid('ACCEPTED', voyageurConfirmed: true, handoverDeadline: _past),
        ['billet', 'todo', ...base],
      ),
      'HANDED_OVER avant le départ': (
        _bid('HANDED_OVER', departureAt: _future),
        ['billet', 'info-locked', ...base],
      ),
      'HANDED_OVER départ passé': (
        _bid('HANDED_OVER', departureAt: _past),
        ['billet', 'info-noshow', ...base],
      ),
      'IN_TRANSIT avant le départ': (
        _bid('IN_TRANSIT', departureAt: _future),
        ['billet', 'info-locked', ...base],
      ),
      'IN_TRANSIT départ passé': (
        _bid('IN_TRANSIT', departureAt: _past),
        ['billet', 'info-noshow', ...base],
      ),
      'ARRIVED': (
        _bid('ARRIVED', departureAt: _past),
        ['billet', 'info-noshow', ...base],
      ),
      'COMPLETED noté': (
        _bid('COMPLETED', travelerHasRated: true),
        ['billet', ...base, 'rating'],
      ),
      'COMPLETED non noté': (_bid('COMPLETED'), ['billet', ...base]),
      // DELIVERED (alias hérité) : pas de badge, il exige COMPLETED.
      'DELIVERED noté': (
        _bid('DELIVERED', travelerHasRated: true),
        ['billet', ...base],
      ),
      'CANCELLED': (_bid('CANCELLED'), ['billet', ...base]),
      'REJECTED': (_bid('REJECTED'), ['billet', ...base]),
      'NO_SHOW': (_bid('NO_SHOW'), ['billet', ...base]),
      'EXPIRED': (_bid('EXPIRED'), ['billet', ...base]),
      'PARCEL_REFUSED': (_bid('PARCEL_REFUSED'), ['billet', ...base]),
    };
    for (final MapEntry(key: name, value: (bid, expected)) in cases.entries) {
      testWidgets(name, (tester) async {
        await _pump(tester, bid);

        expect(_sections(tester), expected);
        _expectTodoNeverEmpty(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('« À traiter » : titre seulement quand la section existe', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED'));
      expect(find.text('À traiter'), findsNothing);

      await _pump(tester, _bid('ACCEPTED', handoverDeadline: _past));
      expect(_inSection('todo', find.text('À traiter')), findsOneWidget);
    });

    testWidgets('« Votre transport » : la grille de la Tâche 1', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED'));
      expect(
        _inSection('transport', find.byType(TravelerTransportSection)),
        findsOneWidget,
      );
      expect(find.text('Votre transport'), findsOneWidget);
    });

    testWidgets('chaque section a sa carte', (tester) async {
      await _pump(tester, _bid('PENDING'));
      expect(_inSection('hero', find.byType(TravelerHeroCard)), findsOneWidget);

      await _pump(tester, _bid('COMPLETED', travelerHasRated: true));
      expect(_inSection('billet', find.byType(ColisBillet)), findsOneWidget);
      expect(find.byType(TravelerHeroCard), findsNothing);
      expect(
        _inSection('expediteur', find.byType(ExpediteurContactCard)),
        findsOneWidget,
      );
      expect(_inSection('gain', find.byType(TravelerGainCard)), findsOneWidget);
      expect(
        _inSection('rating', find.byType(RatingDoneBadge)),
        findsOneWidget,
      );
    });
  });

  // ── Hero : sous le billet, ou dans « À traiter » s'il attend le voyageur ──
  group('hero', () {
    testWidgets('sans action : sous le billet, sans titre', (tester) async {
      for (final status in [
        'PENDING',
        'PAYMENT_ESCROWED',
        'AWAITING_PAYMENT',
      ]) {
        await _pump(tester, _bid(status));
        expect(
          _inSection('hero', find.byType(TravelerHeroCard)),
          findsOneWidget,
          reason: status,
        );
        expect(find.text('À traiter'), findsNothing, reason: status);
      }
    });

    // Cartes « prochaine étape » d'information retirées : ni section hero, ni
    // espace vide entre le billet et la section suivante.
    for (final (label, bid) in [
      ('ACCEPTED', _bid('ACCEPTED', handoverDeadline: _future)),
      (
        'ACCEPTED présence confirmée',
        _bid('ACCEPTED', voyageurConfirmed: true, handoverDeadline: _future),
      ),
      ('HANDED_OVER', _bid('HANDED_OVER')),
      ('IN_TRANSIT', _bid('IN_TRANSIT')),
      ('ARRIVED', _bid('ARRIVED')),
      ('COMPLETED', _bid('COMPLETED')),
      ('DELIVERED', _bid('DELIVERED')),
    ]) {
      testWidgets('$label : plus de carte « prochaine étape », pas d\'espace '
          'vide sous le billet', (tester) async {
        await _pump(tester, bid);
        expect(_section('hero'), findsNothing);
        expect(find.byType(TravelerHeroCard), findsNothing);
        final order = _sections(tester);
        expect(order.first, 'billet');
        final gap =
            tester.getTopLeft(_section(order[1])).dy -
            tester.getBottomLeft(_section('billet')).dy;
        expect(gap, DonySpacing.base);
      });
    }

    testWidgets('date limite dépassée : dans « À traiter », avec son bouton', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED', handoverDeadline: _past));
      expect(_inSection('todo', find.byType(TravelerHeroCard)), findsOneWidget);
      expect(
        _inSection(
          'todo',
          find.textContaining("Signaler l'absence de l'expéditeur"),
        ),
        findsOneWidget,
      );
      expect(_section('hero'), findsNothing);
    });

    for (final ns in ['PENDING_CONFIRMATION', 'CONTESTED']) {
      testWidgets("absence de l'expéditeur $ns : sous le billet, même date "
          'limite passée', (tester) async {
        await _pump(
          tester,
          _bid(
            'ACCEPTED',
            handoverDeadline: _past,
            cancellationNoShowStatus: ns,
          ),
        );
        expect(
          _inSection('hero', find.byType(TravelerHeroCard)),
          findsOneWidget,
        );
        expect(_section('todo'), findsNothing);
      });
    }

    testWidgets('absence à la livraison signalée contre le voyageur : '
        '« Contester ce signalement » dans « À traiter »', (tester) async {
      await _pump(
        tester,
        _bid(
          'IN_TRANSIT',
          deliveryNoShowStatus: 'PENDING_CONFIRMATION',
          deliveryNoShowReportedByTraveler: false,
        ),
      );
      expect(_inSection('todo', find.byType(TravelerHeroCard)), findsOneWidget);
      expect(
        _inSection('todo', find.text('Contester ce signalement')),
        findsOneWidget,
      );
    });

    testWidgets('contestation envoyée : alerte sans bouton, sous le billet', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'IN_TRANSIT',
          deliveryNoShowStatus: 'CONTESTED',
          deliveryNoShowReportedByTraveler: false,
        ),
      );
      expect(_inSection('hero', find.byType(TravelerHeroCard)), findsOneWidget);
      expect(find.text('Contester ce signalement'), findsNothing);
      expect(_section('todo'), findsNothing);
    });

    for (final dns in ['PENDING_CONFIRMATION', 'CONTESTED']) {
      testWidgets('absence à la livraison signalée par le voyageur ($dns) : '
          'hero sous le billet, procédure en information', (tester) async {
        await _pump(
          tester,
          _bid(
            'ARRIVED',
            departureAt: _past,
            deliveryNoShowStatus: dns,
            deliveryNoShowReportedByTraveler: true,
          ),
        );
        expect(_sections(tester), [
          'billet',
          'hero',
          'info-noshow',
          'expediteur',
          'gain',
          'transport',
        ]);
        expect(
          _inSection('info-noshow', find.byType(DeliveryNoShowProcedureCard)),
          findsOneWidget,
        );
      });
    }
  });

  // ── Destinataire absent à la livraison (FLUTTER-E2) ────────────────────────
  // Toute la procédure (checklist comprise) est une information sans titre :
  // son contenu dépend d'un chargement, « À traiter » n'en dépend jamais.
  group('procédure « destinataire absent »', () {
    testWidgets('ARRIVED : la procédure est en information, sans titre', (
      tester,
    ) async {
      await _pump(tester, _bid('ARRIVED', departureAt: _past));
      expect(
        _inSection('info-noshow', find.byType(DeliveryNoShowProcedureCard)),
        findsOneWidget,
      );
      // Procédure indisponible (back ancien) : l'ancien signalement.
      expect(
        _inSection('info-noshow', find.byType(DeliveryNoShowCtaCell)),
        findsOneWidget,
      );
      expect(_section('todo'), findsNothing);
    });

    for (final status in ['HANDED_OVER', 'IN_TRANSIT']) {
      testWidgets('$status départ passé : cellule de signalement repliée en '
          'information', (tester) async {
        await _pump(tester, _bid(status, departureAt: _past));
        expect(
          _inSection(
            'info-noshow',
            find.text("Signaler l'absence du destinataire"),
          ),
          findsOneWidget,
        );
        expect(_section('todo'), findsNothing);
      });

      testWidgets('$status avant le départ : ni cellule ni section', (
        tester,
      ) async {
        await _pump(tester, _bid(status, departureAt: _future));
        expect(find.byType(DeliveryNoShowCtaCell), findsNothing);
        expect(_section('info-noshow'), findsNothing);
        expect(_section('todo'), findsNothing);
      });
    }

    testWidgets('signalement déjà en cours : plus de cellule', (tester) async {
      await _pump(
        tester,
        _bid(
          'IN_TRANSIT',
          departureAt: _past,
          deliveryNoShowStatus: 'PENDING_CONFIRMATION',
          deliveryNoShowReportedByTraveler: true,
        ),
      );
      // La procédure indisponible remonte la cellule, qui ne rend plus rien.
      expect(find.text("Signaler l'absence du destinataire"), findsNothing);
      expect(_section('todo'), findsNothing);
    });

    // « À traiter » n'est jamais affiché sans contenu, quel que soit l'état
    // de la procédure.
    group('« À traiter » jamais sans contenu', () {
      final now = DateTime.now();
      DeliveryNoShowProcedureModel model({
        bool reported = false,
        DateTime? holdUntil,
        DateTime? unclaimedAt,
      }) => DeliveryNoShowProcedureModel(
        bidId: 'b1',
        role: 'TRAVELER',
        bidStatus: 'ARRIVED',
        arrivedAt: now.subtract(const Duration(hours: 3)),
        reported: reported,
        holdUntil: holdUntil,
        unclaimedAt: unclaimedAt,
      );
      final states = <String, DeliveryNoShowProcedureState>{
        'Loading': const DeliveryNoShowProcedureLoading(),
        'Error': const DeliveryNoShowProcedureError(NetworkException('x')),
        'Unavailable': const DeliveryNoShowProcedureUnavailable(),
        'checklist': DeliveryNoShowProcedureLoaded(model(), now: now),
        'garde': DeliveryNoShowProcedureLoaded(
          model(reported: true, holdUntil: now.add(const Duration(days: 5))),
          now: now,
        ),
        'non réclamé': DeliveryNoShowProcedureLoaded(
          model(reported: true, unclaimedAt: now),
          now: now,
        ),
        'signalé, sans garde': DeliveryNoShowProcedureLoaded(
          model(reported: true),
          now: now,
        ),
      };
      final bids = <String, BidModel>{
        'arrivé': _bid('ARRIVED', departureAt: _past),
        'signalé par le voyageur': _bid(
          'ARRIVED',
          departureAt: _past,
          deliveryNoShowStatus: 'PENDING_CONFIRMATION',
          deliveryNoShowReportedByTraveler: true,
        ),
        // Le hero à bouton remplit « À traiter » ; la procédure n'y est pas.
        'signalé contre le voyageur': _bid(
          'ARRIVED',
          departureAt: _past,
          deliveryNoShowStatus: 'PENDING_CONFIRMATION',
          deliveryNoShowReportedByTraveler: false,
        ),
      };
      for (final MapEntry(key: stateName, value: state) in states.entries) {
        for (final MapEntry(key: bidName, value: bid) in bids.entries) {
          testWidgets('$stateName, $bidName', (tester) async {
            whenListen(
              procedure,
              const Stream<DeliveryNoShowProcedureState>.empty(),
              initialState: state,
            );
            await _pump(tester, bid);

            _expectTodoNeverEmpty(tester);
            expect(
              _inSection('todo', find.byType(DeliveryNoShowProcedureCard)),
              findsNothing,
            );
            expect(
              _inSection(
                'info-noshow',
                find.byType(DeliveryNoShowProcedureCard),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    });
  });

  // ── Supplément de prix, chaque statut ─────────────────────────────────────
  group('supplément de prix', () {
    testWidgets('commission à valider : tuile « Supplément de prix » dans '
        '« À traiter », plus de carte au corps', (tester) async {
      await _pump(tester, _commissionPending());
      expect(_inSection('todo', _supplementTile), findsOneWidget);
      expect(
        _inSection('todo', find.byKey(const ValueKey('todo-tiles'))),
        findsOneWidget,
      );
      expect(find.byType(SupplementTravelerCard), findsNothing);
      expect(_section('info-supplement'), findsNothing);
    });

    for (final s in [
      BidSupplementStatus.proposed,
      BidSupplementStatus.paymentPending,
      BidSupplementStatus.paid,
      BidSupplementStatus.payoutPending,
      BidSupplementStatus.paidOut,
      BidSupplementStatus.declined,
      BidSupplementStatus.expired,
      BidSupplementStatus.refundPending,
      BidSupplementStatus.refunded,
    ]) {
      testWidgets('${s.name} : information sans titre', (tester) async {
        await _pump(tester, _bid('ACCEPTED', supplement: _supplement(s)));
        expect(
          _inSection('info-supplement', find.byType(SupplementTravelerCard)),
          findsOneWidget,
        );
        expect(find.text('À traiter'), findsNothing);
      });
    }

    for (final s in [
      BidSupplementStatus.withdrawn,
      BidSupplementStatus.cancelled,
    ]) {
      testWidgets('${s.name} en espèces : information sans titre', (
        tester,
      ) async {
        await _pump(
          tester,
          _bid(
            'ACCEPTED',
            paymentMethod: BidPaymentMethod.cash,
            supplement: _supplement(s, cash: true),
          ),
        );
        expect(
          _inSection('info-supplement', find.byType(SupplementTravelerCard)),
          findsOneWidget,
        );
      });

      testWidgets('${s.name} en ligne : aucune carte', (tester) async {
        await _pump(tester, _bid('ACCEPTED', supplement: _supplement(s)));
        expect(find.byType(SupplementTravelerCard), findsNothing);
      });
    }

    testWidgets('supplément bloquant, présence confirmée : scan bloqué puis '
        'supplément, en informations', (tester) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          supplement: _supplement(BidSupplementStatus.proposed),
        ),
      );
      expect(_sections(tester), [
        'billet',
        'info-scan-blocked',
        'info-supplement',
        'expediteur',
        'gain',
        'transport',
      ]);
    });
  });

  // ── Une carte qui change de section garde son état (GlobalKey) ────────────
  group('une carte qui change de section n\'est pas remontée', () {
    Element innerStateful(WidgetTester tester, Type card) => tester.element(
      find
          .descendant(
            of: find.byType(card),
            matching: find.byWidgetPredicate((w) => w is StatefulWidget),
          )
          .first,
    );

    // Le supplément ne change plus de section : tuile tant que ses frais
    // attendent le voyageur, carte d'information ensuite.
    testWidgets('supplément : la tuile laisse place à la carte d\'information '
        'une fois les frais validés', (tester) async {
      await _pump(tester, _commissionPending());
      expect(_inSection('todo', _supplementTile), findsOneWidget);

      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          paymentMethod: BidPaymentMethod.cash,
          supplement: _supplement(BidSupplementStatus.proposed, cash: true),
        ),
      );
      expect(_section('todo'), findsNothing);
      expect(_supplementTile, findsNothing);
      expect(
        _inSection('info-supplement', find.byType(SupplementTravelerCard)),
        findsOneWidget,
      );
    });

    testWidgets('modification : « À traiter » → information, même élément', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.proposed)]),
      );
      expect(
        _inSection('todo', find.byType(AmendmentTravelerCard)),
        findsOneWidget,
      );
      final card = tester.element(find.byType(AmendmentTravelerCard));
      final inner = innerStateful(tester, AmendmentTravelerCard);

      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.accepted)]),
      );
      expect(_section('todo'), findsNothing);
      expect(
        _inSection('info-amendment', find.byType(AmendmentTravelerCard)),
        findsOneWidget,
      );
      expect(tester.element(find.byType(AmendmentTravelerCard)), same(card));
      expect(innerStateful(tester, AmendmentTravelerCard), same(inner));
    });
  });

  // ── Modification du colis, chaque statut ──────────────────────────────────
  group('modification du colis', () {
    for (final s in [
      BidAmendmentStatus.proposed,
      BidAmendmentStatus.commissionPending,
    ]) {
      testWidgets('${s.name} (ACCEPTED) : dans « À traiter »', (tester) async {
        await _pump(tester, _bid('ACCEPTED', amendments: [_amendment(s)]));
        expect(
          _inSection('todo', find.byType(AmendmentTravelerCard)),
          findsOneWidget,
        );
        expect(_section('info-amendment'), findsNothing);
      });
    }

    for (final s in [
      BidAmendmentStatus.authorizationPending,
      BidAmendmentStatus.paymentPending,
      // Acquise : « Les kilos en plus ne sont pas là » reste un geste
      // facultatif, porté par la carte d'information.
      BidAmendmentStatus.accepted,
      BidAmendmentStatus.payoutPending,
      BidAmendmentStatus.paidOut,
      BidAmendmentStatus.declined,
      BidAmendmentStatus.expired,
      BidAmendmentStatus.cancelled,
      BidAmendmentStatus.refundPending,
      BidAmendmentStatus.refunded,
    ]) {
      testWidgets('${s.name} : information sans titre', (tester) async {
        await _pump(tester, _bid('ACCEPTED', amendments: [_amendment(s)]));
        expect(
          _inSection('info-amendment', find.byType(AmendmentTravelerCard)),
          findsOneWidget,
        );
        expect(find.text('À traiter'), findsNothing);
      });
    }

    testWidgets('acquise après la remise : plus de carte', (tester) async {
      await _pump(
        tester,
        _bid(
          'HANDED_OVER',
          amendments: [_amendment(BidAmendmentStatus.accepted)],
        ),
      );
      expect(find.byType(AmendmentTravelerCard), findsNothing);
    });

    testWidgets(
      'demande ouverte : la carte reste entre le billet et le contact',
      (tester) async {
        await _pump(
          tester,
          _bid(
            'ACCEPTED',
            amendments: [_amendment(BidAmendmentStatus.proposed)],
          ),
        );
        final card = tester.getTopLeft(find.byType(AmendmentTravelerCard)).dy;
        expect(
          card,
          greaterThan(tester.getTopLeft(find.byType(ColisBillet)).dy),
        );
        expect(
          card,
          lessThan(tester.getTopLeft(find.byType(ExpediteurContactCard)).dy),
        );
      },
    );

    testWidgets('supplément à valider et modification proposée : les deux '
        'dans « À traiter », la carte de la modification puis la tuile', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          paymentMethod: BidPaymentMethod.cash,
          supplement: _supplement(
            BidSupplementStatus.commissionPending,
            cash: true,
          ),
          amendments: [_amendment(BidAmendmentStatus.proposed)],
        ),
      );
      final supplement = _inSection('todo', _supplementTile);
      final amendment = _inSection('todo', find.byType(AmendmentTravelerCard));
      expect(supplement, findsOneWidget);
      expect(amendment, findsOneWidget);
      expect(
        tester.getBottomLeft(amendment).dy,
        lessThan(tester.getTopLeft(supplement).dy),
      );
    });

    testWidgets('sans modification : aucune carte', (tester) async {
      await _pump(tester, _bid('ACCEPTED'));
      expect(find.byType(AmendmentTravelerCard), findsNothing);
    });
  });

  // ── Trajet reporté : jamais une action pour le voyageur ───────────────────
  group('trajet reporté', () {
    for (final pending in [true, false]) {
      testWidgets(
        '${pending ? 'décision en attente' : 'déjà décidé'} : information',
        (tester) async {
          await _pump(
            tester,
            _bid('ACCEPTED', reschedule: _reschedule(pending: pending)),
          );
          expect(
            _inSection('info-reschedule', find.byType(TripRescheduleCard)),
            findsOneWidget,
          );
          expect(find.text('À traiter'), findsNothing);
        },
      );
    }

    for (final status in ['PENDING', 'COMPLETED', 'CANCELLED']) {
      testWidgets('$status : la carte reste affichée', (tester) async {
        await _pump(
          tester,
          _bid(status, reschedule: _reschedule(pending: false)),
        );
        expect(find.byType(TripRescheduleCard), findsOneWidget);
      });
    }
  });

  // ── Destinataire refusé : pastille sur la tuile Colis (FLUTTER-E8) ────────
  testWidgets('destinataire refusé : pastille sur la tuile Colis, pas de '
      '« À traiter »', (tester) async {
    await _pump(tester, _bid('ACCEPTED', recipientDeclined: true));
    expect(
      find.descendant(
        of: find.byKey(const Key('traveler-tile-colis')),
        matching: find.byKey(const Key('tool-status-badge')),
      ),
      findsOneWidget,
    );
    expect(find.text('À traiter'), findsOneWidget); // pastille seule
    expect(_section('todo'), findsNothing);
  });

  // Phrases d'aide sorties du footer : elles vivent dans des cartes
  // d'information du corps, juste sous le hero.
  group("cartes d'information (phrases sorties du footer)", () {
    const awaiting = "En attente du paiement de l'expéditeur (mobile money).";
    const supplementBlocked =
        "Un supplément attend la réponse de l'expéditeur : le scan est bloqué.";
    const amendmentBlocked =
        'Une modification attend votre réponse : le scan est bloqué.';
    const amendmentBlockedSender =
        "Une modification attend l'expéditeur : le scan est bloqué.";

    testWidgets(
      'AWAITING_PAYMENT mobile money : carte d\'attente sous le hero',
      (tester) async {
        await _pump(
          tester,
          _bid('AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.mobileMoney),
        );
        expect(
          _inSection('info-awaiting-payment', find.text(awaiting)),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.text(awaiting)).dy,
          greaterThan(tester.getTopLeft(find.byType(TravelerHeroCard)).dy),
        );
      },
    );

    testWidgets('AWAITING_PAYMENT hors mobile money : pas de carte', (
      tester,
    ) async {
      await _pump(tester, _bid('AWAITING_PAYMENT'));
      expect(find.text(awaiting), findsNothing);
    });

    testWidgets('autre statut : pas de carte d\'attente', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED', paymentMethod: BidPaymentMethod.mobileMoney),
      );
      expect(find.text(awaiting), findsNothing);
    });

    testWidgets('supplément bloquant : phrase du scan bloqué', (tester) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          supplement: _supplement(BidSupplementStatus.proposed),
        ),
      );
      expect(
        _inSection('info-scan-blocked', find.text(supplementBlocked)),
        findsOneWidget,
      );
      expect(find.text(amendmentBlocked), findsNothing);
    });

    const commissionBlocked =
        "Le scan est bloqué tant que vous n'avez pas validé le paiement de "
        'votre commission.';
    final commissionPendingBid = _bid(
      'ACCEPTED',
      voyageurConfirmed: true,
      paymentMethod: BidPaymentMethod.cash,
      supplement: _supplement(
        BidSupplementStatus.commissionPending,
        cash: true,
      ),
    );

    testWidgets(
      'commission à valider : le scan bloqué parle de la commission, pas de '
      "l'expéditeur",
      (tester) async {
        await _pump(tester, commissionPendingBid);
        expect(
          _inSection('info-scan-blocked', find.text(commissionBlocked)),
          findsOneWidget,
        );
        expect(find.text(supplementBlocked), findsNothing);
        // « À traiter » demande bien de valider le paiement.
        expect(_inSection('todo', _supplementTile), findsOneWidget);
      },
    );

    testWidgets('commission à valider, en anglais', (tester) async {
      useEnglish();
      await _pump(tester, commissionPendingBid);
      expect(
        _inSection(
          'info-scan-blocked',
          find.text(
            'Scanning is blocked until you confirm payment of your commission.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "An extra charge is awaiting the sender's reply: scanning is "
          'blocked.',
        ),
        findsNothing,
      );
    });

    testWidgets('supplément proposé (attend l\'expéditeur), en anglais', (
      tester,
    ) async {
      useEnglish();
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          supplement: _supplement(BidSupplementStatus.proposed),
        ),
      );
      expect(
        _inSection(
          'info-scan-blocked',
          find.text(
            "An extra charge is awaiting the sender's reply: scanning is "
            'blocked.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('supplément paymentPending : texte « expéditeur » conservé', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          supplement: _supplement(BidSupplementStatus.paymentPending),
        ),
      );
      expect(
        _inSection('info-scan-blocked', find.text(supplementBlocked)),
        findsOneWidget,
      );
      expect(find.text(commissionBlocked), findsNothing);
    });

    testWidgets('modification bloquante : phrase du scan bloqué', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          amendments: [_amendment(BidAmendmentStatus.proposed)],
        ),
      );
      expect(
        _inSection('info-scan-blocked', find.text(amendmentBlocked)),
        findsOneWidget,
      );
      expect(find.text(supplementBlocked), findsNothing);
      // La modification sous « À traiter », puis l'information.
      expect(_sections(tester), [
        'billet',
        'todo',
        'info-scan-blocked',
        'expediteur',
        'gain',
        'transport',
      ]);
    });

    // La modification attend l'expéditeur (autorisation carte, dépôt mobile
    // money) : la carte ne doit pas dire que c'est au voyageur de répondre.
    for (final status in [
      BidAmendmentStatus.paymentPending,
      BidAmendmentStatus.authorizationPending,
    ]) {
      testWidgets('modification ${status.name} (attend l\'expéditeur) : '
          'phrase « expéditeur », FR', (tester) async {
        await _pump(
          tester,
          _bid(
            'ACCEPTED',
            voyageurConfirmed: true,
            amendments: [_amendment(status)],
          ),
        );
        expect(
          _inSection('info-scan-blocked', find.text(amendmentBlockedSender)),
          findsOneWidget,
        );
        expect(find.text(amendmentBlocked), findsNothing);
      });

      testWidgets('modification ${status.name} (attend l\'expéditeur) : '
          'phrase « expéditeur », EN', (tester) async {
        useEnglish();
        await _pump(
          tester,
          _bid(
            'ACCEPTED',
            voyageurConfirmed: true,
            amendments: [_amendment(status)],
          ),
        );
        expect(
          _inSection(
            'info-scan-blocked',
            find.text(
              'A change is waiting on the sender: scanning is on hold.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text('A change is waiting for your reply: scanning is blocked.'),
          findsNothing,
        );
      });
    }

    testWidgets('modification proposée, en anglais : texte « votre réponse »', (
      tester,
    ) async {
      useEnglish();
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          amendments: [_amendment(BidAmendmentStatus.proposed)],
        ),
      );
      expect(
        _inSection(
          'info-scan-blocked',
          find.text('A change is waiting for your reply: scanning is blocked.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('commission de la modification à finaliser : texte « votre '
        'réponse » (le voyageur doit agir)', (tester) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          amendments: [_amendment(BidAmendmentStatus.commissionPending)],
        ),
      );
      expect(
        _inSection('info-scan-blocked', find.text(amendmentBlocked)),
        findsOneWidget,
      );
    });

    testWidgets('rien ne bloque : aucune phrase de scan bloqué', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED', voyageurConfirmed: true));
      expect(find.text(supplementBlocked), findsNothing);
      expect(find.text(amendmentBlocked), findsNothing);
    });

    testWidgets('présence non confirmée : pas de phrase de scan bloqué', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.proposed)]),
      );
      expect(find.text(amendmentBlocked), findsNothing);
    });

    testWidgets('remise verrouillée avant le départ : carte avec la date et '
        'le code de retrait', (tester) async {
      await _pump(tester, _bid('HANDED_OVER', departureAt: _future));
      expect(
        _inSection(
          'info-locked',
          find.textContaining('Disponible après le départ du trajet (le'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'demandez au destinataire son code de retrait à 6 chiffres',
        ),
        findsOneWidget,
      );
    });

    for (final status in ['IN_TRANSIT', 'ARRIVED']) {
      testWidgets('$status verrouillé : même carte', (tester) async {
        await _pump(tester, _bid(status, departureAt: _future));
        expect(
          find.textContaining('Disponible après le départ du trajet (le'),
          findsOneWidget,
        );
      });
    }

    // Mode recette (FLUTTER-FA) : le verrou est levé pour un testeur.
    testWidgets('mode recette : pas de carte de verrou', (tester) async {
      final auth = _MockAuthBloc();
      when(() => auth.state).thenReturn(
        const AuthAuthenticated(
          UserModel(
            id: 'u1',
            roles: [],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
            recetteMode: true,
          ),
        ),
      );
      await _pump(
        tester,
        _bid('HANDED_OVER', departureAt: _future),
        authBloc: auth,
      );
      expect(find.byType(TravelerHandoverLockedCard), findsNothing);
      expect(_section('info-locked'), findsNothing);
    });

    testWidgets('départ passé : pas de carte de verrou', (tester) async {
      await _pump(
        tester,
        _bid(
          'HANDED_OVER',
          departureAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      expect(find.textContaining('Disponible après le départ'), findsNothing);
      expect(find.textContaining('code de retrait à 6 chiffres'), findsNothing);
    });

    testWidgets('départ inconnu : pas de carte de verrou', (tester) async {
      await _pump(tester, _bid('HANDED_OVER'));
      expect(find.textContaining('Disponible après le départ'), findsNothing);
    });

    // Le verrou tombe seul à l'heure du départ (même State, didUpdateWidget de
    // DeliveryDepartureGate) : la porte lit DateTime.now(), pas d'horloge à
    // avancer, on rejoue donc le même colis avec un départ désormais passé.
    testWidgets('le départ passe : la carte du verrou disparaît', (
      tester,
    ) async {
      await _pump(tester, _bid('HANDED_OVER', departureAt: _future));
      expect(
        find.textContaining('Disponible après le départ du trajet (le'),
        findsOneWidget,
      );
      final stateBefore = tester.state(find.byType(TravelerDetailBody));

      await _pump(
        tester,
        _bid(
          'HANDED_OVER',
          departureAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      expect(tester.state(find.byType(TravelerDetailBody)), same(stateBefore));
      expect(find.textContaining('Disponible après le départ'), findsNothing);
      expect(find.textContaining('code de retrait à 6 chiffres'), findsNothing);
    });

    // La porte enveloppe TOUJOURS le corps (sans fenêtre elle ne verrouille
    // jamais) : le passage de ACCEPTED à HANDED_OVER garde la même porte et le
    // même State, sans remonter la racine du corps.
    testWidgets('ACCEPTED -> HANDED_OVER : même porte, même State', (
      tester,
    ) async {
      final departure = DateTime.now().subtract(const Duration(hours: 1));
      await _pump(tester, _bid('ACCEPTED', departureAt: departure));
      final gateBefore = tester.state(find.byType(DeliveryDepartureGate));
      final bodyBefore = tester.state(find.byType(TravelerDetailBody));

      await _pump(tester, _bid('HANDED_OVER', departureAt: departure));

      expect(
        tester.state(find.byType(DeliveryDepartureGate)),
        same(gateBefore),
      );
      expect(tester.state(find.byType(TravelerDetailBody)), same(bodyBefore));
      expect(find.textContaining('Disponible après le départ'), findsNothing);
    });

    testWidgets(
      'ACCEPTED sans verrou -> HANDED_OVER avant le départ : la carte '
      'apparaît dans la même porte',
      (tester) async {
        await _pump(tester, _bid('ACCEPTED', departureAt: _future));
        final gateBefore = tester.state(find.byType(DeliveryDepartureGate));
        expect(find.textContaining('Disponible après le départ'), findsNothing);

        await _pump(tester, _bid('HANDED_OVER', departureAt: _future));

        expect(
          tester.state(find.byType(DeliveryDepartureGate)),
          same(gateBefore),
        );
        expect(
          find.textContaining('Disponible après le départ du trajet (le'),
          findsOneWidget,
        );
      },
    );

    testWidgets('statut sans remise (ACCEPTED) : pas de carte de verrou', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED', departureAt: _future));
      expect(find.textContaining('Disponible après le départ'), findsNothing);
    });
  });

  // ── Sections stables : une apparition ne remonte pas les suivantes ────────
  testWidgets('« À traiter » qui apparaît ne remonte ni l\'expéditeur, ni le '
      'gain, ni la grille', (tester) async {
    await _pump(tester, _bid('ACCEPTED', handoverDeadline: _future));
    // Le stagger d'entrée est fini : un premier rebuild retire ses enveloppes.
    await _pump(tester, _bid('ACCEPTED', handoverDeadline: _future));
    final contact = tester.element(find.byType(ExpediteurContactCard));
    final gain = tester.element(find.byType(TravelerGainCard));
    final grid = tester.element(find.byType(TravelerTransportSection));

    await _pump(
      tester,
      _bid(
        'ACCEPTED',
        handoverDeadline: _future,
        supplement: _supplement(
          BidSupplementStatus.commissionPending,
          cash: true,
        ),
      ),
    );

    expect(_section('todo'), findsOneWidget);
    expect(tester.element(find.byType(ExpediteurContactCard)), same(contact));
    expect(tester.element(find.byType(TravelerGainCard)), same(gain));
    expect(tester.element(find.byType(TravelerTransportSection)), same(grid));
  });

  testWidgets('stagger joué une seule fois : le rebuild suivant rend les '
      'cartes sans animation', (tester) async {
    await _pump(tester, _bid('ACCEPTED'));
    await tester.pump(const Duration(seconds: 1));
    await _pump(tester, _bid('ACCEPTED'));
    expect(
      find.ancestor(
        of: find.byType(ExpediteurContactCard),
        matching: find.byType(Animate),
      ),
      findsNothing,
    );
  });

  // ── Pas de double apparition corps / sheets ───────────────────────────────
  group('cartes portées par les sheets « Votre transport »', () {
    for (final status in ['PENDING', 'ACCEPTED', 'HANDED_OVER', 'COMPLETED']) {
      testWidgets('$status : ni carte colis, ni contact, ni détails au corps', (
        tester,
      ) async {
        await _pump(tester, _bid(status, recipientPhone: '+221700000000'));
        expect(find.byType(ColisDestinataireCard), findsNothing);
        expect(find.byType(TravelerRecipientContactCard), findsNothing);
        expect(find.byType(TravelerRecipientContactPendingNote), findsNothing);
        expect(find.byType(BidDetailsContent), findsNothing);
      });
    }

    testWidgets('HANDED_OVER : le contact du destinataire vit dans le sheet '
        'Colis, une seule fois', (tester) async {
      await _pump(tester, _bid('HANDED_OVER', recipientPhone: '+221700000000'));

      await tester.tap(find.byKey(const Key('traveler-tile-colis')));
      await tester.pumpAndSettle();

      expect(find.byType(ColisDestinataireCard), findsOneWidget);
      expect(find.byType(TravelerRecipientContactCard), findsOneWidget);
      expect(find.byKey(const Key('recipient-contact-sms-b1')), findsOneWidget);
    });

    testWidgets('ACCEPTED : la ligne d\'attente du contact vit dans le sheet', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED', recipientPhone: '+221700000000'));

      await tester.tap(find.byKey(const Key('traveler-tile-colis')));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerRecipientContactPendingNote), findsOneWidget);
      expect(find.text('+221700000000'), findsNothing);
    });
  });

  testWidgets('ACCEPTED → contact + gain présents, sans hero', (tester) async {
    await _pump(tester, _bid('ACCEPTED'));
    expect(find.byType(TravelerHeroCard), findsNothing);
    expect(find.byType(ExpediteurContactCard), findsOneWidget);
    expect(find.byType(TravelerGainCard), findsOneWidget);
  });

  // Régression : ARRIVED absent de _activeStatuses faisait disparaître la carte
  // expéditeur et les actions de suivi dès le marquage d'arrivée.
  testWidgets('ARRIVED → carte contact toujours là, mais aucune action suivi', (
    tester,
  ) async {
    await _pump(tester, _bid('ARRIVED'));
    expect(find.byType(ExpediteurContactCard), findsOneWidget);
    // Le suivi appartient à l'expéditeur : le voyageur détient le colis mais
    // n'en est pas propriétaire, il n'a donc jamais accès aux actions de suivi,
    // y compris une fois arrivé à destination.
    expect(find.text('Suivi du colis'), findsNothing);
    expect(find.text('Partager le suivi'), findsNothing);
  });

  testWidgets(
    'PENDING → profil de l\'expéditeur sans contact, téléphone du destinataire masqué',
    (tester) async {
      await _pump(tester, _bid('PENDING'));
      expect(find.byType(ExpediteurContactCard), findsOneWidget);
      expect(
        _contactIcon(ExpediteurContactCard, 'message-circle'),
        findsNothing,
      );
      expect(_contactIcon(ExpediteurContactCard, 'phone'), findsNothing);
      expect(find.text('Téléphone'), findsNothing);
      // Et on lui dit pourquoi (FLUTTER-4T).
      expect(
        find.text(
          "Vous pourrez contacter l'expéditeur une fois la demande acceptée.",
        ),
        findsOneWidget,
      );
      expect(find.byType(TravelerGainCard), findsOneWidget);
    },
  );

  testWidgets('trackingToken présent → pas de lien ni action suivi voyageur', (
    tester,
  ) async {
    await _pump(tester, _bid('ACCEPTED', trackingToken: 'public-token'));

    expect(find.text('Suivi du colis'), findsNothing);
    expect(find.text('Partager le suivi'), findsNothing);

    await tester.tap(find.byKey(const Key('traveler-tile-details')));
    await tester.pumpAndSettle();

    expect(find.byType(BidDetailsContent), findsOneWidget);
    expect(find.text('LIEN DE SUIVI'), findsNothing);
    expect(find.textContaining('public-token'), findsNothing);
  });

  // ── « À traiter » en tuiles : frais du supplément à valider ─────────────
  group('À traiter en tuiles', () {
    final fee = formatSupplementAmount(2, 'EUR');

    testWidgets(
      'tuile : titre, résumé et pastille ambre « Réponse attendue »',
      (tester) async {
        await _pump(tester, _commissionPending());
        expect(
          find.descendant(
            of: _supplementTile,
            matching: find.text('Supplément de prix'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _supplementTile,
            matching: find.text('$fee de frais à valider'),
          ),
          findsOneWidget,
        );
        final badge = tester.widget<ToolStatusBadge>(
          find.descendant(
            of: _supplementTile,
            matching: find.byType(ToolStatusBadge),
          ),
        );
        expect(badge.tone, ToolStatusTone.news);
        expect(badge.label, 'Réponse attendue');
        _expectTodoNeverEmpty(tester);
      },
    );

    testWidgets('en anglais', (tester) async {
      useEnglish();
      await _pump(tester, _commissionPending());
      for (final text in [
        'Extra charge',
        '$fee fee to confirm',
        'Reply needed',
      ]) {
        expect(
          find.descendant(of: _supplementTile, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets('les cartes d\'alerte d\'abord, puis la grille des tuiles', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          handoverDeadline: _past,
          paymentMethod: BidPaymentMethod.cash,
          supplement: _supplement(
            BidSupplementStatus.commissionPending,
            cash: true,
          ),
        ),
      );
      final hero = _inSection('todo', find.byType(TravelerHeroCard));
      final tile = _inSection('todo', _supplementTile);
      expect(hero, findsOneWidget);
      expect(tile, findsOneWidget);
      expect(
        tester.getBottomLeft(hero).dy,
        lessThan(tester.getTopLeft(tile).dy),
      );
    });

    testWidgets('le tap ouvre le sheet de la tuile et compte l\'ouverture', (
      tester,
    ) async {
      await _pump(tester, _commissionPending());
      await tester.tap(_supplementTile);
      await tester.pumpAndSettle();

      expect(_supplementSheetFooter, findsOneWidget);
      verify(
        () => tileBackend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'supplement',
          'role': 'traveler',
          'source': 'tile',
        }),
      ).called(1);
    });

    testWidgets('mesures à l\'affichage de la tuile, une seule fois malgré '
        'les relevés du colis', (tester) async {
      await _pump(tester, _commissionPending());
      await _pump(tester, _commissionPending());
      await _pump(tester, _commissionPending());

      verify(
        () => tileBackend.capture(AnalyticsEvents.bidDetailTodoTileShown, {
          'tile': 'supplement',
          'role': 'traveler',
          'status': 'ACCEPTED',
        }),
      ).called(1);
      verify(
        () => tileBackend.capture(AnalyticsEvents.bidSupplementViewed, {
          'role': 'traveler',
          'status': 'commissionPending',
          'surface': 'tile',
        }),
      ).called(1);
      // La carte n'est pas montée : pas de seconde mesure à son montage.
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementViewed,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets('supplément proposé (information) : mesure au montage de la '
        'carte, sans surface, pas de tuile', (tester) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          paymentMethod: BidPaymentMethod.cash,
          supplement: _supplement(BidSupplementStatus.proposed, cash: true),
        ),
      );
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementViewed,
          properties: {'role': 'traveler', 'status': 'proposed'},
        ),
      ).called(1);
      verifyNever(
        () =>
            tileBackend.capture(AnalyticsEvents.bidDetailTodoTileShown, any()),
      );
      expect(_supplementTile, findsNothing);
    });
  });

  // ── Points d'entrée : ?action=supplement et ?action=amendment ─────────────
  group('défilement vers la carte (notification)', () {
    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    Future<void> settleScroll(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Le haut de la carte visée est dans la fenêtre visible (écran de test de
    // 700 px de haut), pas seulement « ça a défilé ».
    void expectOnScreen(WidgetTester tester, Type card) {
      final top = tester.getTopLeft(find.byType(card)).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(700));
    }

    testWidgets('?action=supplement, frais à valider : le sheet de la tuile '
        's\'ouvre de lui-même, une seule fois, en source link', (tester) async {
      await _pump(
        tester,
        _commissionPending(),
        focusSupplement: true,
        size: const Size(800, 700),
      );
      await tester.pumpAndSettle();
      expect(_supplementSheetFooter, findsOneWidget);
      verify(
        () => tileBackend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'supplement',
          'role': 'traveler',
          'source': 'link',
        }),
      ).called(1);

      // Fermé à la main : un relevé du colis ne le rouvre pas.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
      expect(_supplementSheetFooter, findsNothing);
      await _pump(
        tester,
        _commissionPending(),
        focusSupplement: true,
        size: const Size(800, 700),
      );
      await tester.pumpAndSettle();
      expect(_supplementSheetFooter, findsNothing);
    });

    // Le corps ne reçoit jamais de squelette (l'écran affiche le sien) : le
    // paramètre est consommé au premier colis, qu'il ait un supplément ou non.
    // Une demande créée ensuite (menu ⋮) n'ouvre pas de sheet, et ne serait
    // pas attribuée à tort au lien de la notification.
    testWidgets('?action=supplement : premier colis sans supplément, demande '
        'créée plus tard : ni sheet ni mesure « link »', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED'),
        focusSupplement: true,
        size: const Size(800, 700),
      );
      await tester.pumpAndSettle();
      expect(_supplementSheetFooter, findsNothing);

      await _pump(
        tester,
        _commissionPending(),
        focusSupplement: true,
        size: const Size(800, 700),
      );
      await tester.pumpAndSettle();
      expect(_supplementSheetFooter, findsNothing);
      expect(_supplementTile, findsOneWidget);
      verifyNever(
        () => tileBackend.capture(AnalyticsEvents.bidDetailTileOpened, any()),
      );
    });

    testWidgets('?action=supplement sans paramètre : pas de sheet', (
      tester,
    ) async {
      await _pump(tester, _commissionPending(), size: const Size(800, 700));
      await tester.pumpAndSettle();
      expect(_supplementSheetFooter, findsNothing);
    });

    testWidgets('?action=supplement : supplément payé (information), la carte '
        'est amenée à l\'écran', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED', supplement: _supplement(BidSupplementStatus.paid)),
        focusSupplement: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), greaterThan(0));
      expectOnScreen(tester, SupplementTravelerCard);
    });

    testWidgets('?action=amendment : la carte de la modification est amenée '
        'à l\'écran', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.proposed)]),
        focusAmendment: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), greaterThan(0));
      expectOnScreen(tester, AmendmentTravelerCard);
    });

    testWidgets('?action=amendment : modification close (information), la '
        'carte est amenée à l\'écran', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.declined)]),
        focusAmendment: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), greaterThan(0));
      expectOnScreen(tester, AmendmentTravelerCard);
    });

    testWidgets('sans carte : pas de défilement', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED'),
        focusSupplement: true,
        focusAmendment: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), 0);
    });

    testWidgets('sans paramètre : pas de défilement', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.proposed)]),
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), 0);
    });

    // Même règle pour `?action=amendment` : consommé au premier colis.
    testWidgets('?action=amendment : modification apparue après le premier '
        'colis, pas de défilement', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED'),
        focusAmendment: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), 0);

      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.proposed)]),
        focusAmendment: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), 0);
    });

    testWidgets('?action=amendment : défilement une seule fois, un relevé ne '
        'redéfile pas', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.proposed)]),
        focusAmendment: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), greaterThan(0));
      expectOnScreen(tester, AmendmentTravelerCard);

      // Remonte à la main : un rafraîchissement ne redéfile pas.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await _pump(
        tester,
        _bid('ACCEPTED', amendments: [_amendment(BidAmendmentStatus.proposed)]),
        focusAmendment: true,
        size: const Size(800, 700),
      );
      await settleScroll(tester);
      expect(offset(tester), 0);
    });
  });
}

/// Bouton d'une carte de profil (appel ou message), repéré par son icône.
Finder _contactIcon(Type card, String icon) => find.descendant(
  of: find.byType(card),
  matching: find.byWidgetPredicate((w) => w is DonyIcon && w.name == icon),
);
