// Pied collant de l'écran du trajet vu par son voyageur : règle pure
// (`tripFooterFor`, statut × demandes × colis, priorités), libellés FR / EN,
// actions de chaque bouton, disposition (deux boutons sur une ligne ou
// empilés) et libellés à taille nominale à 360 dp × 1,3 avec les vraies
// polices.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_sticky_bar.dart';
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

const _arrived = (primary: TripFooterButton.markArrived, secondary: null);
const _notify = (primary: TripFooterButton.notifyRecipients, secondary: null);
const _requests = (primary: TripFooterButton.seeRequests, secondary: null);
const _publishEdit = (
  primary: TripFooterButton.publish,
  secondary: TripFooterButton.edit,
);
const _publish = (primary: TripFooterButton.publish, secondary: null);
const _posterEdit = (
  primary: TripFooterButton.sharePoster,
  secondary: TripFooterButton.edit,
);
const _poster = (primary: TripFooterButton.sharePoster, secondary: null);

/// Pied attendu pour un trajet [status] dont les colis sont [p].
///
/// « Arrivé à destination » seulement sur un trajet parti (IN_PROGRESS) : sur
/// un trajet ACTIVE ou FULL, des colis remis (étape de remise, avant le
/// départ) laissent le pied aux règles suivantes.
TripFooter? _expected(String status, _Parcels p) {
  const travelling = {'ACTIVE', 'FULL', 'IN_PROGRESS'};
  const onBoard = {
    _Parcels.handedOver,
    _Parcels.inTransit,
    _Parcels.arrivedAndHandedOver,
    _Parcels.handedOverAndPending,
  };
  if (status == 'IN_PROGRESS' && onBoard.contains(p)) return _arrived;
  if (travelling.contains(status) &&
      (p == _Parcels.arrived || p == _Parcels.arrivedAndPending)) {
    return _notify;
  }
  final pending = const {
    _Parcels.pending,
    _Parcels.escrowed,
    _Parcels.handedOverAndPending,
    _Parcels.notLoadedWithPending,
  }.contains(p);
  final empty = p == _Parcels.none || p == _Parcels.notLoaded;
  return switch (status) {
    'DRAFT' => empty ? _publishEdit : _publish,
    'ACTIVE' when pending => _requests,
    'ACTIVE' => empty ? _posterEdit : _poster,
    'FULL' when pending => _requests,
    _ => null,
  };
}

void main() {
  group('tripFooterFor', () {
    for (final status in kTripStatuses) {
      for (final p in _Parcels.values) {
        test('$status × ${p.name}', () {
          expect(
            tripFooterFor(
              trip: _tripFor(status, p),
              bids: _bidsFor(p),
              isOwner: true,
            ),
            _expected(status, p),
          );
        });
      }
    }

    test('table : cas clés écrits en clair', () {
      TripFooter? f(String s, _Parcels p) =>
          tripFooterFor(trip: _tripFor(s, p), bids: _bidsFor(p), isOwner: true);
      // Priorités : l'arrivée l'emporte sur « Prévenir » et sur les demandes,
      // « Prévenir » sur les demandes.
      expect(f('IN_PROGRESS', _Parcels.handedOverAndPending), _arrived);
      expect(f('IN_PROGRESS', _Parcels.arrivedAndHandedOver), _arrived);
      expect(f('ACTIVE', _Parcels.arrivedAndPending), _notify);
      // Trajet parti : colis remis (transit facultatif) ou en transit.
      expect(f('IN_PROGRESS', _Parcels.handedOver), _arrived);
      expect(f('IN_PROGRESS', _Parcels.inTransit), _arrived);
      // Étape de remise (recette du propriétaire) : trajet pas encore parti,
      // colis remis, jamais « Arrivé à destination ».
      expect(f('ACTIVE', _Parcels.handedOver), _poster);
      expect(f('ACTIVE', _Parcels.handedOverAndPending), _requests);
      expect(f('FULL', _Parcels.handedOver), isNull);
      expect(f('FULL', _Parcels.handedOverAndPending), _requests);
      expect(f('FULL', _Parcels.arrivedAndHandedOver), isNull);
      for (final s in ['ACTIVE', 'FULL']) {
        for (final p in [_Parcels.handedOver, _Parcels.inTransit]) {
          expect(f(s, p)?.primary, isNot(TripFooterButton.markArrived));
        }
      }
      expect(f('IN_PROGRESS', _Parcels.arrived), _notify);
      // Brouillon, trajet ouvert sans demande, trajet complet.
      expect(f('DRAFT', _Parcels.none), _publishEdit);
      expect(f('ACTIVE', _Parcels.none), _posterEdit);
      expect(f('ACTIVE', _Parcels.pending), _requests);
      expect(f('FULL', _Parcels.escrowed), _requests);
      expect(f('FULL', _Parcels.accepted), isNull);
      expect(f('IN_PROGRESS', _Parcels.pending), isNull);
      // Trajets soldés : jamais de pied, même avec des colis arrivés.
      for (final s in ['COMPLETED', 'CANCELLED', 'REMOVED_BY_ADMIN']) {
        expect(f(s, _Parcels.arrived), isNull, reason: s);
        expect(f(s, _Parcels.handedOver), isNull, reason: s);
      }
    });

    test('colis acceptés seulement : affiche sans « Modifier »', () {
      expect(
        tripFooterFor(
          trip: ownerTrip(),
          bids: [ownerBid('b1', 'ACCEPTED')],
          isOwner: true,
        ),
        _poster,
      );
    });

    test('demandes comptées par le back (bidsCount) : affiche seule', () {
      expect(
        tripFooterFor(trip: ownerTrip(bidsCount: 1), bids: null, isOwner: true),
        _poster,
      );
    });

    test('une liste chargée prime sur le compteur du modèle', () {
      expect(
        tripFooterFor(
          trip: ownerTrip(pendingBidCount: 3),
          bids: const [],
          isOwner: true,
        ),
        _posterEdit,
      );
    });

    test('colis arrivé, liste pas encore chargée : pas de « Prévenir »', () {
      // La règle d'arrivée attend la liste des colis.
      expect(
        tripFooterFor(
          trip: ownerTrip(status: 'IN_PROGRESS'),
          bids: null,
          isOwner: true,
        ),
        isNull,
      );
    });

    test('colis refusé, annulé ou livré seulement : rien à faire avancer', () {
      for (final s in ['NO_SHOW', 'PARCEL_REFUSED', 'CANCELLED', 'COMPLETED']) {
        expect(
          tripFooterFor(
            trip: ownerTrip(status: 'IN_PROGRESS'),
            bids: [ownerBid('b1', s)],
            isOwner: true,
          ),
          isNull,
          reason: s,
        );
      }
    });

    test('visiteur : aucun pied, quel que soit le trajet', () {
      for (final status in kTripStatuses) {
        for (final p in _Parcels.values) {
          expect(
            tripFooterFor(
              trip: _tripFor(status, p),
              bids: _bidsFor(p),
              isOwner: false,
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

      await pumpBar(
        tester,
        trip: ownerTrip(),
        bids: [ownerBid('b1', 'PENDING'), ownerBid('b2', 'PAYMENT_ESCROWED')],
      );
      expect(find.text('Voir les demandes (2)'), findsOneWidget);
      expect(find.byType(DonyButton), findsOneWidget);

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
        bids: [ownerBid('b1', 'ARRIVED'), ownerBid('b2', 'ARRIVED')],
      );
      expect(find.text('Prévenir les destinataires (2)'), findsOneWidget);
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
        bids: [ownerBid('b1', 'PENDING')],
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
        bids: [ownerBid('b1', 'ARRIVED')],
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
      await tester.tap(key(TripFooterButton.publish));
      await tester.pump();
      final added = verify(() => annBloc.add(captureAny())).captured;
      expect(added.single, isA<AnnouncementPublishRequested>());
      expect((added.single as AnnouncementPublishRequested).id, 'trip-1');
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
      await tester.tap(key(TripFooterButton.markArrived));
      await tester.pumpAndSettle();
      final sheet = find.byType(ArrivalInstructionsBottomSheet);
      expect(sheet, findsOneWidget);
      final widget = tester.widget<ArrivalInstructionsBottomSheet>(sheet);
      expect(widget.isEditing, isFalse);
      expect(widget.announcementId, 'trip-1');
      expect(widget.initialInstructions, 'Rue 10');
      expect(sheetRouteName(tester, sheet), '/sheet/trip-owner/mark-arrived');

      // Confirmer envoie le marquage (la position est jointe par le bloc).
      await tester.tap(find.text("Confirmer l'arrivée"));
      await tester.pump();
      final added = verify(() => annBloc.add(captureAny())).captured;
      expect(added.last, isA<AnnouncementTripMarkArrivedRequested>());
      final event = added.last as AnnouncementTripMarkArrivedRequested;
      expect(event.announcementId, 'trip-1');
      expect(event.arrivalInstructions, 'Rue 10');
    });

    testWidgets('Prévenir ouvre la feuille des destinataires (manual)', (
      tester,
    ) async {
      await pumpBar(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [ownerBid('b1', 'ARRIVED'), ownerBid('b2', 'COMPLETED')],
      );
      await tester.tap(key(TripFooterButton.notifyRecipients));
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
        final publish = tester.getRect(key(TripFooterButton.publish));
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
          [for (var i = 0; i < 12; i++) ownerBid('a$i', 'ARRIVED')],
        ),
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
                final footer = tripFooterFor(
                  trip: trip,
                  bids: bids,
                  isOwner: true,
                )!;
                for (final b in [footer.primary, ?footer.secondary]) {
                  final label = switch (b) {
                    TripFooterButton.markArrived =>
                      l.tripOwnerMarkArrivedButton,
                    TripFooterButton.notifyRecipients =>
                      l.notifyRecipientsButton(12),
                    TripFooterButton.edit => l.commonEdit,
                    TripFooterButton.publish => l.tripOwnerPublishTile,
                    TripFooterButton.seeRequests => l.listingSeeRequestsButton(
                      12,
                    ),
                    TripFooterButton.sharePoster => l.tripPosterShareButton,
                  };
                  expect(tester.getSize(key(b)).height, 52, reason: label);
                  expect(
                    labelScale(tester, key(b), label),
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
