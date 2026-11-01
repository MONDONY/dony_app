// Pied collant de l'écran du trajet vu par son voyageur : règle pure
// (`tripFooterFor`, statut × demandes × colis × action « À traiter » en
// tête, priorités), libellés FR / EN,
// actions de chaque bouton, disposition (deux boutons sur une ligne ou
// empilés) et libellés à taille nominale à 360 dp × 1,3 avec les vraies
// polices.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_labels.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';
import 'trip_owner_harness.dart';

/// Situation des colis d'un trajet, pour la table de `tripFooterFor`.
enum _Parcels {
  none,
  pending,
  escrowed,
  accepted,
  handedOver,
  inTransit,
  arrived,
  arrivedAndHandedOver,
  arrivedAndPending,
  handedOverAndPending,
  notLoadedWithPending,
  notLoaded,
}

List<BidModel>? _bidsFor(_Parcels p) => switch (p) {
  _Parcels.none => const [],
  _Parcels.pending => [ownerBid('b1', 'PENDING'), ownerBid('b2', 'REJECTED')],
  _Parcels.escrowed => [ownerBid('b1', 'PAYMENT_ESCROWED')],
  _Parcels.accepted => [ownerBid('b1', 'ACCEPTED')],
  _Parcels.handedOver => [ownerBid('b1', 'HANDED_OVER')],
  _Parcels.inTransit => [ownerBid('b1', 'IN_TRANSIT')],
  _Parcels.arrived => [ownerBid('b1', 'ARRIVED'), ownerBid('b2', 'COMPLETED')],
  _Parcels.arrivedAndHandedOver => [
    ownerBid('b1', 'ARRIVED'),
    ownerBid('b2', 'HANDED_OVER'),
  ],
  _Parcels.arrivedAndPending => [
    ownerBid('b1', 'ARRIVED'),
    ownerBid('b2', 'PENDING'),
  ],
  _Parcels.handedOverAndPending => [
    ownerBid('b1', 'HANDED_OVER'),
    ownerBid('b2', 'PENDING'),
  ],
  _Parcels.notLoadedWithPending || _Parcels.notLoaded => null,
};

AnnouncementModel _tripFor(String status, _Parcels p) => ownerTrip(
  status: status,
  pendingBidCount: p == _Parcels.notLoadedWithPending ? 2 : 0,
);

/// Horloge figée des tests : avant le départ du trajet de test (12 nov.).
final _now = DateTime(2026, 11, 1, 12);

const _requests = (primary: TripFooterButton.seeRequests, secondary: null);
const _posterEdit = (
  primary: TripFooterButton.sharePoster,
  secondary: TripFooterButton.edit,
);
const _poster = (primary: TripFooterButton.sharePoster, secondary: null);
const _todo = (primary: TripFooterButton.todo, secondary: null);
const _todoEdit = (
  primary: TripFooterButton.todo,
  secondary: TripFooterButton.edit,
);

List<TripTodoItem> _todoFor(AnnouncementModel trip, List<BidModel>? bids) =>
    tripTodoFor(
      trip: trip,
      bids: bids,
      isOwner: true,
      now: _now,
      departed: false,
      stripe: const StripeAccountInitial(),
    );

TripFooter? _footer(String status, _Parcels p) {
  final trip = _tripFor(status, p);
  final bids = _bidsFor(p);
  return tripFooterFor(
    trip: trip,
    bids: bids,
    isOwner: true,
    todo: _todoFor(trip, bids),
  );
}

/// Pied attendu pour un trajet [status] dont les colis sont [p] : l'action
/// « À traiter » en tête quand il y en a une (« Modifier » à côté seulement
/// sur un brouillon ou un trajet ouvert sans demande, jamais pendant
/// l'arrivée), sinon les règles d'avant (« Voir les demandes » pour des
/// demandes qui ne sont pas une action, l'affiche sur un trajet ouvert).
TripFooter? _expected(String status, _Parcels p) {
  const travelling = {'ACTIVE', 'FULL', 'IN_PROGRESS'};
  const onBoard = {
    _Parcels.handedOver,
    _Parcels.inTransit,
    _Parcels.arrivedAndHandedOver,
    _Parcels.handedOverAndPending,
  };
  final arrivalStep =
      (status == 'IN_PROGRESS' && onBoard.contains(p)) ||
      (travelling.contains(status) &&
          (p == _Parcels.arrived || p == _Parcels.arrivedAndPending));
  final pending = const {
    _Parcels.pending,
    _Parcels.escrowed,
    _Parcels.arrivedAndPending,
    _Parcels.handedOverAndPending,
    _Parcels.notLoadedWithPending,
  }.contains(p);
  final requestsWaiting = (status == 'ACTIVE' || status == 'FULL') && pending;
  final empty = p == _Parcels.none || p == _Parcels.notLoaded;
  if (tripFooterTodo(_todoFor(_tripFor(status, p), _bidsFor(p))) != null) {
    final keepsEdit =
        empty &&
        !arrivalStep &&
        (status == 'DRAFT' || (!requestsWaiting && status == 'ACTIVE'));
    return keepsEdit ? _todoEdit : _todo;
  }
  if (requestsWaiting) return _requests;
  if (status == 'ACTIVE') return empty ? _posterEdit : _poster;
  return null;
}

void main() {
  setUp(() => tripTodoNow = () => _now);
  tearDown(() => tripTodoNow = DateTime.now);

  group('tripFooterFor', () {
    for (final status in kTripStatuses) {
      for (final p in _Parcels.values) {
        test('$status × ${p.name}', () {
          expect(_footer(status, p), _expected(status, p));
        });
      }
    }

    test('table : cas clés écrits en clair', () {
      TripTodoKind? first(String s, _Parcels p) {
        final todo = _todoFor(_tripFor(s, p), _bidsFor(p));
        return todo.isEmpty ? null : todo.first.kind;
      }

      // Brouillon : « Publier » est l'action, « Modifier » reste à côté.
      expect(_footer('DRAFT', _Parcels.none), _todoEdit);
      expect(first('DRAFT', _Parcels.none), TripTodoKind.publish);
      expect(first('DRAFT', _Parcels.notLoaded), TripTodoKind.publish);
      // Demande à traiter : le pied suit l'action, sans « Modifier ».
      expect(_footer('ACTIVE', _Parcels.escrowed), _todo);
      expect(first('ACTIVE', _Parcels.escrowed), TripTodoKind.requests);
      expect(first('FULL', _Parcels.escrowed), TripTodoKind.requests);
      // Carte pas encore payée (PENDING carte) : pas une action, le pied
      // garde « Voir les demandes (N) » ; idem pour le compteur du modèle.
      expect(_footer('ACTIVE', _Parcels.pending), _requests);
      expect(_footer('FULL', _Parcels.pending), _requests);
      expect(_footer('ACTIVE', _Parcels.notLoadedWithPending), _requests);
      // Trajet parti avec des colis à bord : « Arrivé à destination » en tête.
      expect(_footer('IN_PROGRESS', _Parcels.handedOver), _todo);
      expect(first('IN_PROGRESS', _Parcels.handedOver), TripTodoKind.arrive);
      expect(first('IN_PROGRESS', _Parcels.inTransit), TripTodoKind.arrive);
      expect(
        first('IN_PROGRESS', _Parcels.handedOverAndPending),
        TripTodoKind.arrive,
      );
      // Étape de remise avant le départ : jamais « Arrivé à destination ».
      for (final s in ['ACTIVE', 'FULL']) {
        for (final p in [_Parcels.handedOver, _Parcels.inTransit]) {
          expect(first(s, p), isNot(TripTodoKind.arrive), reason: '$s $p');
        }
      }
      // Colis accepté : confirmer sa présence (urgent).
      expect(first('FULL', _Parcels.accepted), TripTodoKind.presence);
      // Trajets sans rien à traiter : aucun pied.
      for (final s in ['COMPLETED', 'CANCELLED', 'REMOVED_BY_ADMIN', 'FULL']) {
        expect(_footer(s, _Parcels.none), isNull, reason: s);
      }
      expect(_footer('IN_PROGRESS', _Parcels.none), isNull);
      // Ouvert sans rien : « Modifier » | « Partager l'affiche ».
      expect(_footer('ACTIVE', _Parcels.none), _posterEdit);
    });

    test('sans file : les règles d\'avant (affiche, demandes)', () {
      expect(
        tripFooterFor(
          trip: ownerTrip(),
          bids: [ownerBid('b1', 'ACCEPTED')],
          isOwner: true,
        ),
        _poster,
      );
      expect(
        tripFooterFor(trip: ownerTrip(bidsCount: 1), bids: null, isOwner: true),
        _poster,
      );
      expect(
        tripFooterFor(
          trip: ownerTrip(pendingBidCount: 3),
          bids: const [],
          isOwner: true,
        ),
        _posterEdit,
      );
      expect(
        tripFooterFor(
          trip: ownerTrip(status: 'DRAFT'),
          bids: const [],
          isOwner: true,
        ),
        isNull,
        reason: 'un brouillon a toujours son action « Publier »',
      );
    });

    test('suggestions facultatives (carte, notation) : jamais au pied', () {
      const ready = StripeAccountReady(
        ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
      );
      // Trajet espèces seules tout juste publié : « Ajouter la carte » est
      // en tête de « À traiter », le pied garde « Modifier » | « Partager
      // l'affiche ».
      final cashOnly = ownerTrip(methods: const {BidPaymentMethod.cash});
      final todo = tripTodoFor(
        trip: cashOnly,
        bids: const [],
        isOwner: true,
        now: _now,
        departed: false,
        stripe: ready,
      );
      expect(todo.map((i) => i.kind), [TripTodoKind.addCard]);
      expect(
        tripFooterFor(
          trip: cashOnly,
          bids: const [],
          isOwner: true,
          todo: todo,
        ),
        _posterEdit,
      );
      // Trajet terminé, seulement des notes à donner : aucun pied.
      expect(
        tripFooterFor(
          trip: ownerTrip(status: 'COMPLETED'),
          bids: const [],
          isOwner: true,
          todo: const [TripTodoItem(kind: TripTodoKind.rate, count: 2)],
        ),
        isNull,
      );
    });

    test('demandes traitées depuis l\'écran : plus comptées', () {
      final bids = [ownerBid('b1', 'PENDING')];
      expect(
        tripFooterFor(trip: ownerTrip(), bids: bids, isOwner: true),
        _requests,
      );
      expect(
        tripFooterFor(
          trip: ownerTrip(),
          bids: bids,
          isOwner: true,
          answered: {'b1'},
        ),
        _poster,
      );
    });

    test('visiteur : aucun pied, quel que soit le trajet', () {
      for (final status in kTripStatuses) {
        for (final p in _Parcels.values) {
          final trip = _tripFor(status, p);
          expect(
            tripFooterFor(
              trip: trip,
              bids: _bidsFor(p),
              isOwner: false,
              todo: _todoFor(trip, _bidsFor(p)),
            ),
            isNull,
          );
        }
      }
    });
  });

  group('barre', () {
    late MockAnnouncementBloc annBloc;
    late MockBidBloc bidBloc;
    late MockAnalyticsBackend backend;

    setUpAll(() async {
      registerFallbackValue(AnnouncementDetailRequested('fallback'));
      registerFallbackValue(BidListRequested('fallback'));
      await loadAppFonts();
    });

    setUp(() async {
      annBloc = MockAnnouncementBloc();
      bidBloc = MockBidBloc();
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementInitial(),
      );
      whenListen(
        bidBloc,
        const Stream<BidState>.empty(),
        initialState: BidInitial(),
      );
      backend = MockAnalyticsBackend();
      final analytics = makeEnabledAnalytics(backend);
      await analytics.onConfigured();
      await getIt.reset();
      getIt.registerSingleton<AnalyticsService>(analytics);
      DonySnackbar.clearDedup();
    });

    tearDown(() async => getIt.reset());

    Future<List<PushedRoute>> pumpBar(
      WidgetTester tester, {
      required AnnouncementModel trip,
      required List<BidModel>? bids,
      bool isOwner = true,
      Locale locale = const Locale('fr'),
      double textScale = 1,
      Size size = const Size(360, 800),
    }) => pumpTripOwnerScreen(
      tester,
      bottomBar: TripOwnerStickyBar(trip: trip, bids: bids, isOwner: isOwner),
      announcement: annBloc,
      bids: bidBloc,
      locale: locale,
      textScale: textScale,
      size: size,
    );

    Finder key(TripFooterButton b) => find.byKey(Key('trip-footer-${b.name}'));

    testWidgets('aucun pied : rien n’est rendu', (tester) async {
      for (final trip in [
        ownerTrip(status: 'COMPLETED'),
        ownerTrip(status: 'CANCELLED'),
        ownerTrip(status: 'REMOVED_BY_ADMIN'),
        ownerTrip(status: 'FULL'),
      ]) {
        await pumpBar(tester, trip: trip, bids: const []);
        expect(find.byKey(const Key('trip-owner-sticky-bar')), findsNothing);
        expect(find.byType(DonyButton), findsNothing);
      }
      await pumpBar(tester, trip: ownerTrip(), bids: const [], isOwner: false);
      expect(find.byType(DonyButton), findsNothing);
    });

    Finder todoKey(TripTodoKind kind) =>
        find.byKey(Key('trip-footer-todo-${kind.name}'));

    /// Colis arrivé dont la remise n'est pas encore ouverte (départ du
    /// colis dans le futur) : « Prévenir » passe en tête.
    BidModel arrivedNotDeliverable(String id) =>
        ownerBid(id, 'ARRIVED', departureDate: DateTime(2026, 11, 20));

    testWidgets('libellés FR', (tester) async {
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'DRAFT'),
        bids: const [],
      );
      expect(find.text('Publier'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);

      await pumpBar(tester, trip: ownerTrip(), bids: const []);
      expect(find.text("Partager l'affiche"), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);

      // Une carte pas encore payée ne compte pas : seule la demande payée.
      await pumpBar(
        tester,
        trip: ownerTrip(),
        bids: [ownerBid('b1', 'PENDING'), ownerBid('b2', 'PAYMENT_ESCROWED')],
      );
      expect(find.text('Voir les demandes (1)'), findsOneWidget);
      expect(find.byType(DonyButton), findsOneWidget);

      // Cartes pas encore payées seules : « Voir les demandes (N) » d'avant.
      await pumpBar(
        tester,
        trip: ownerTrip(),
        bids: [ownerBid('b1', 'PENDING'), ownerBid('b2', 'PENDING')],
      );
      expect(find.text('Voir les demandes (2)'), findsOneWidget);
      expect(key(TripFooterButton.seeRequests), findsOneWidget);

      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [ownerBid('b1', 'IN_TRANSIT')],
      );
      expect(find.text('Arrivé à destination'), findsOneWidget);
      expect(find.byType(DonyButton), findsOneWidget);

      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [arrivedNotDeliverable('b1'), arrivedNotDeliverable('b2')],
      );
      expect(find.text('Prévenir les destinataires (2)'), findsOneWidget);

      // Remise ouverte : « Valider la remise » passe avant « Prévenir ».
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [ownerBid('b1', 'ARRIVED')],
      );
      expect(find.text('Valider la remise'), findsOneWidget);

      // Présence confirmée : récupérer le colis.
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'FULL'),
        bids: [ownerBid('b1', 'ACCEPTED', voyageurConfirmed: true)],
      );
      expect(find.text('Lire le QR du colis'), findsOneWidget);
    });

    testWidgets('libellés EN', (tester) async {
      const en = Locale('en');
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'DRAFT'),
        bids: const [],
        locale: en,
      );
      expect(find.text('Post'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      await pumpBar(tester, trip: ownerTrip(), bids: const [], locale: en);
      expect(find.text('Share the poster'), findsOneWidget);
      await pumpBar(
        tester,
        trip: ownerTrip(),
        bids: [ownerBid('b1', 'PAYMENT_ESCROWED')],
        locale: en,
      );
      expect(find.text('See requests (1)'), findsOneWidget);
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [ownerBid('b1', 'HANDED_OVER')],
        locale: en,
      );
      expect(find.text('Arrived at destination'), findsOneWidget);
      await pumpBar(
        tester,
        trip: ownerTrip(),
        bids: [arrivedNotDeliverable('b1')],
        locale: en,
      );
      expect(find.text('Notify recipients (1)'), findsOneWidget);
    });

    testWidgets('Publier envoie AnnouncementPublishRequested', (tester) async {
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'DRAFT'),
        bids: const [],
      );
      await tester.tap(todoKey(TripTodoKind.publish));
      await tester.pump();
      final added = verify(() => annBloc.add(captureAny())).captured;
      expect(added.single, isA<AnnouncementPublishRequested>());
      expect((added.single as AnnouncementPublishRequested).id, 'trip-1');
      verifyNever(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, any()),
      );
    });

    testWidgets('Modifier ouvre l’édition et relit si elle enregistre', (
      tester,
    ) async {
      final pushed = await pumpBar(
        tester,
        trip: ownerTrip(status: 'DRAFT'),
        bids: const [],
      );
      await tester.tap(key(TripFooterButton.edit));
      await tester.pumpAndSettle();
      expect(pushed.single.location, '/trips/create');
      final args = pushed.single.extra! as CreateTripArgs;
      expect(args.announcement?.id, 'trip-1');
    });

    testWidgets('Partager l’affiche ouvre l’affiche du trajet', (tester) async {
      final trip = ownerTrip();
      final pushed = await pumpBar(tester, trip: trip, bids: const []);
      await tester.tap(key(TripFooterButton.sharePoster));
      await tester.pumpAndSettle();
      expect(pushed.single.location, '/announcements/trip-1/affiche');
      expect(identical(pushed.single.extra, trip), isTrue);
    });

    testWidgets('Voir les demandes ouvre /demandes puis relit au retour', (
      tester,
    ) async {
      final pushed = await pumpBar(
        tester,
        trip: ownerTrip(status: 'FULL'),
        bids: [ownerBid('b1', 'PENDING')],
      );
      await tester.tap(key(TripFooterButton.seeRequests));
      await tester.pumpAndSettle();
      expect(
        pushed.single.location,
        '/demandes?filter=aTraiter&announcement=trip-1',
      );
      verifyNever(() => bidBloc.add(any()));
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      final reload = verify(() => bidBloc.add(captureAny())).captured.single;
      expect(reload, isA<BidListRequested>());
      expect((reload as BidListRequested).silent, isTrue);
      verify(
        () => annBloc.add(any(that: isA<AnnouncementDetailRequested>())),
      ).called(1);
    });

    testWidgets('Arrivé à destination ouvre la feuille de l’arrivée', (
      tester,
    ) async {
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS', arrivalInstructions: 'Rue 10'),
        bids: [ownerBid('b1', 'HANDED_OVER')],
      );
      await tester.tap(todoKey(TripTodoKind.arrive));
      await tester.pumpAndSettle();
      final sheet = find.byType(ArrivalInstructionsBottomSheet);
      expect(sheet, findsOneWidget);
      final widget = tester.widget<ArrivalInstructionsBottomSheet>(sheet);
      expect(widget.isEditing, isFalse);
      expect(widget.announcementId, 'trip-1');
      expect(widget.initialInstructions, 'Rue 10');
      expect(sheetRouteName(tester, sheet), '/sheet/trip-owner/mark-arrived');
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'arrive',
          'role': 'trip_owner',
          'source': 'footer',
        }),
      ).called(1);

      // Confirmer envoie le marquage (la position est jointe par le bloc).
      await tester.tap(find.text("Confirmer l'arrivée"));
      await tester.pump();
      final added = verify(() => annBloc.add(captureAny())).captured;
      expect(added.last, isA<AnnouncementTripMarkArrivedRequested>());
      final event = added.last as AnnouncementTripMarkArrivedRequested;
      expect(event.announcementId, 'trip-1');
      expect(event.arrivalInstructions, 'Rue 10');
    });

    testWidgets('trajet parti, suivi ouvert, « Je pars » jamais touché : le '
        'pied dit « Arrivé à destination », jamais « Je pars »', (
      tester,
    ) async {
      await pumpBar(
        tester,
        trip: ownerTrip(
          status: 'IN_PROGRESS',
          trackingActive: true,
          parcelsSummary: const TripParcelsSummary(
            count: 2,
            totalKg: 6,
            netAmount: 40,
            currency: 'EUR',
          ),
        ),
        bids: [ownerBid('b1', 'HANDED_OVER'), ownerBid('b2', 'HANDED_OVER')],
      );
      expect(todoKey(TripTodoKind.arrive), findsOneWidget);
      expect(find.text('Arrivé à destination'), findsOneWidget);
      expect(todoKey(TripTodoKind.depart), findsNothing);
      expect(find.text('Je pars'), findsNothing);
    });

    testWidgets('double appui sur le pied : une seule feuille', (tester) async {
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS', arrivalInstructions: 'Rue 10'),
        bids: [ownerBid('b1', 'HANDED_OVER')],
      );
      // Deux appuis dans la même image (avant que la feuille ne couvre le
      // pied) : le second ne doit rien ouvrir.
      final press = tester
          .widget<DonyButton>(todoKey(TripTodoKind.arrive))
          .onPressed!;
      press();
      press();
      await tester.pumpAndSettle();
      expect(find.byType(ArrivalInstructionsBottomSheet), findsOneWidget);
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'arrive',
          'role': 'trip_owner',
          'source': 'footer',
        }),
      ).called(1);
    });

    testWidgets('trajet espèces seules : « Modifier » | « Partager '
        'l\'affiche », pas « Ajouter la carte »', (tester) async {
      await pumpTripOwnerScreen(
        tester,
        bottomBar: TripOwnerStickyBar(
          trip: ownerTrip(methods: const {BidPaymentMethod.cash}),
          bids: const [],
          isOwner: true,
          stripe: const StripeAccountReady(
            ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
          ),
        ),
        announcement: annBloc,
        bids: bidBloc,
      );
      expect(key(TripFooterButton.sharePoster), findsOneWidget);
      expect(key(TripFooterButton.edit), findsOneWidget);
      expect(todoKey(TripTodoKind.addCard), findsNothing);
    });

    testWidgets('Prévenir ouvre la feuille des destinataires (manual)', (
      tester,
    ) async {
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [arrivedNotDeliverable('b1'), ownerBid('b2', 'COMPLETED')],
      );
      // Le colis livré attend une note : « Prévenir » reste en tête
      // (important, ordre fixe des types).
      await tester.tap(todoKey(TripTodoKind.notify));
      await tester.pumpAndSettle();
      final sheet = find.byType(NotifyRecipientsSheet);
      expect(sheet, findsOneWidget);
      expect(tester.widget<NotifyRecipientsSheet>(sheet).bids, hasLength(1));
      expect(
        sheetRouteName(tester, sheet),
        '/sheet/trip-owner/notify-recipients',
      );
      verify(
        () => backend.capture(AnalyticsEvents.recipientsNotifyOpened, {
          'count': 1,
          'source': 'manual',
        }),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'notify',
          'role': 'trip_owner',
          'source': 'footer',
        }),
      ).called(1);
    });

    testWidgets('Lire le QR : sheet des colis à récupérer, puis Suivi', (
      tester,
    ) async {
      final pushed = await pumpBar(
        tester,
        trip: ownerTrip(status: 'FULL'),
        bids: [ownerBid('b1', 'ACCEPTED', voyageurConfirmed: true)],
      );
      await tester.tap(todoKey(TripTodoKind.scan));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('trip-todo-parcels-scan-button'));
      expect(sheet, findsOneWidget);
      expect(sheetRouteName(tester, sheet), '/sheet/trip-owner/todo-scan');
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'scan',
          'role': 'trip_owner',
          'source': 'footer',
        }),
      ).called(1);
      await tester.tap(sheet);
      await tester.pumpAndSettle();
      expect(pushed.single.location, '/tracking/validate?trip=trip-1');
    });

    group('disposition', () {
      testWidgets('Modifier | Publier sur une ligne à 360 dp, FR × 1', (
        tester,
      ) async {
        await pumpBar(
          tester,
          trip: ownerTrip(status: 'DRAFT'),
          bids: const [],
        );
        final edit = tester.getRect(key(TripFooterButton.edit));
        final publish = tester.getRect(todoKey(TripTodoKind.publish));
        expect(edit.top, publish.top);
        expect(edit.right, lessThan(publish.left));
        // Secondaire 1/3, principal 2/3.
        expect(publish.width, closeTo(edit.width * 2, 1));
      });

      testWidgets('libellés trop longs : empilés, le principal en haut', (
        tester,
      ) async {
        await pumpBar(
          tester,
          trip: ownerTrip(),
          bids: const [],
          textScale: 1.3,
        );
        final edit = tester.getRect(key(TripFooterButton.edit));
        final poster = tester.getRect(key(TripFooterButton.sharePoster));
        expect(poster.bottom, lessThanOrEqualTo(edit.top));
        expect(poster.width, edit.width);
      });
    });

    group('libellés à taille nominale', () {
      double labelScale(WidgetTester tester, Finder button, String label) {
        final fitted = find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
          ),
        );
        final text = find.descendant(of: button, matching: find.text(label));
        expect(fitted, findsOneWidget, reason: label);
        expect(text, findsOneWidget, reason: label);
        return tester.getSize(fitted).width / tester.getSize(text).width;
      }

      final cases = <(String, AnnouncementModel, List<BidModel>)>[
        ('brouillon', ownerTrip(status: 'DRAFT'), const []),
        ('ouvert', ownerTrip(), const []),
        (
          'demandes',
          ownerTrip(),
          [for (var i = 0; i < 12; i++) ownerBid('p$i', 'PAYMENT_ESCROWED')],
        ),
        (
          'cartes pas encore payées',
          ownerTrip(),
          [for (var i = 0; i < 12; i++) ownerBid('p$i', 'PENDING')],
        ),
        (
          'arrivée',
          ownerTrip(status: 'IN_PROGRESS'),
          [ownerBid('b1', 'IN_TRANSIT')],
        ),
        (
          'prévenir',
          ownerTrip(status: 'IN_PROGRESS'),
          [
            for (var i = 0; i < 12; i++)
              ownerBid('a$i', 'ARRIVED', departureDate: DateTime(2026, 11, 20)),
          ],
        ),
        (
          'récupérer',
          ownerTrip(status: 'FULL'),
          [ownerBid('b1', 'ACCEPTED', voyageurConfirmed: true)],
        ),
        ('présence', ownerTrip(status: 'FULL'), [ownerBid('b1', 'ACCEPTED')]),
      ];

      for (final locale in const [Locale('fr'), Locale('en')]) {
        for (final scale in const [1.0, 1.3]) {
          for (final width in const [360.0, 412.0]) {
            for (final (name, trip, bids) in cases) {
              testWidgets('$name ${locale.languageCode} × $scale à $width dp', (
                tester,
              ) async {
                await pumpBar(
                  tester,
                  trip: trip,
                  bids: bids,
                  locale: locale,
                  textScale: scale,
                  size: Size(width, 800),
                );
                expect(tester.takeException(), isNull);
                final l = lookupAppLocalizations(locale);
                final todo = _todoFor(trip, bids);
                final footer = tripFooterFor(
                  trip: trip,
                  bids: bids,
                  isOwner: true,
                  todo: todo,
                )!;
                for (final b in [footer.primary, ?footer.secondary]) {
                  final label = switch (b) {
                    TripFooterButton.todo => tripTodoButton(
                      l,
                      todo.first,
                      cardReady: false,
                    ),
                    TripFooterButton.edit => l.commonEdit,
                    TripFooterButton.seeRequests => l.listingSeeRequestsButton(
                      12,
                    ),
                    TripFooterButton.sharePoster => l.tripPosterShareButton,
                  };
                  final finder = b == TripFooterButton.todo
                      ? find.byKey(
                          Key('trip-footer-todo-${todo.first.kind.name}'),
                        )
                      : key(b);
                  expect(tester.getSize(finder).height, 52, reason: label);
                  expect(
                    labelScale(tester, finder, label),
                    closeTo(1, 0.001),
                    reason: label,
                  );
                }
              });
            }
          }
        }
      }
    });
  });
}
