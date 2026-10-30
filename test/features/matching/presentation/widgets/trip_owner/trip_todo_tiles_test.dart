// « À traiter » de l'écran du trajet (vue du voyageur propriétaire) :
// fonction pure des tuiles pour chaque statut du trajet, demandes en attente,
// fenêtre de suivi, départ déjà confirmé et encart « espèces seules » ;
// titres, résumés et mesure d'affichage (`role: trip_owner`).
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _statuses = [
  'DRAFT',
  'ACTIVE',
  'FULL',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'REMOVED_BY_ADMIN',
  'SOMETHING_NEW',
];

const _ready = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);
const _notReady = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED'),
);
const _unavailable = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED', connectAvailableInCountry: false),
);

const _summary = TripParcelsSummary(
  count: 2,
  totalKg: 6,
  netAmount: 40,
  currency: 'EUR',
);

AnnouncementModel _trip({
  String status = 'ACTIVE',
  int pendingBidCount = 0,
  bool trackingActive = false,
  TripParcelsSummary? parcelsSummary,
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
  String currency = 'EUR',
}) {
  final now = DateTime(2026, 10, 30);
  return AnnouncementModel(
    id: 'trip-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    departureDate: now.add(const Duration(days: 3)),
    availableKg: 20,
    totalKg: 20,
    status: status,
    createdAt: now,
    updatedAt: now,
    pendingBidCount: pendingBidCount,
    trackingActive: trackingActive,
    parcelsSummary: parcelsSummary,
    acceptedPaymentMethods: methods,
    currency: currency,
  );
}

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

List<TripTodoTile> _tiles(
  AnnouncementModel trip, {
  List<BidModel>? bids = const [],
  bool isOwner = true,
  bool departed = false,
  StripeAccountState stripe = _notReady,
}) => tripTodoTilesFor(
  trip: trip,
  bids: bids,
  isOwner: isOwner,
  departed: departed,
  stripe: stripe,
);

void main() {
  test('les noms des tuiles sont figés (valeur `tile` des mesures)', () {
    expect(TripTodoTile.values.map((t) => t.name), [
      'requests',
      'depart',
      'card',
    ]);
  });

  group('demandes à traiter', () {
    final pending = [_bid('b1', 'PENDING'), _bid('b2', 'ACCEPTED')];
    final escrowed = [_bid('b3', 'PAYMENT_ESCROWED')];
    final none = [
      _bid('b4', 'ACCEPTED'),
      _bid('b5', 'REJECTED'),
      _bid('b6', 'IN_TRANSIT'),
    ];

    for (final status in _statuses) {
      final open = const {'ACTIVE', 'FULL', 'IN_PROGRESS'}.contains(status);
      test('$status avec une demande PENDING : ${open ? 'tuile' : 'rien'}', () {
        expect(
          _tiles(_trip(status: status), bids: pending),
          open ? [TripTodoTile.requests] : isEmpty,
        );
      });
      test('$status sans demande en attente : rien', () {
        expect(_tiles(_trip(status: status), bids: none), isEmpty);
      });
    }

    test('PAYMENT_ESCROWED compte comme une demande à traiter', () {
      expect(_tiles(_trip(), bids: escrowed), [TripTodoTile.requests]);
    });

    test('liste pas encore chargée : repli sur pendingBidCount', () {
      expect(_tiles(_trip(pendingBidCount: 2), bids: null), [
        TripTodoTile.requests,
      ]);
      expect(_tiles(_trip(), bids: null), isEmpty);
    });

    test('liste chargée : elle prime sur pendingBidCount', () {
      expect(_tiles(_trip(pendingBidCount: 3), bids: none), isEmpty);
    });

    test('nombre de demandes à traiter', () {
      expect(tripPendingRequestCount(_trip(), [...pending, ...escrowed]), 2);
      expect(tripPendingRequestCount(_trip(pendingBidCount: 4), null), 4);
    });
  });

  group('« Je pars »', () {
    AnnouncementModel trip({
      String status = 'ACTIVE',
      bool trackingActive = true,
      TripParcelsSummary? summary = _summary,
    }) => _trip(
      status: status,
      trackingActive: trackingActive,
      parcelsSummary: summary,
    );

    test('colis remis, fenêtre de suivi ouverte, pas encore parti : tuile', () {
      expect(_tiles(trip()), [TripTodoTile.depart]);
    });

    test('départ déjà confirmé sur cet appareil : rien', () {
      expect(_tiles(trip(), departed: true), isEmpty);
    });

    test('fenêtre de suivi fermée (détail sans trackingActive) : rien', () {
      expect(_tiles(trip(trackingActive: false)), isEmpty);
    });

    test('aucun colis remis : rien', () {
      expect(_tiles(trip(summary: null)), isEmpty);
      expect(
        _tiles(
          trip(
            summary: const TripParcelsSummary(
              count: 0,
              totalKg: 0,
              netAmount: 0,
              currency: 'EUR',
            ),
          ),
        ),
        isEmpty,
      );
    });

    // Trajet publié, complet ou en cours seulement : jamais annulé (colis
    // en retour), terminé, brouillon, retiré ni d'un statut inconnu, même
    // si le back sert la fenêtre de suivi ouverte.
    for (final status in _statuses) {
      final shown = const {'ACTIVE', 'FULL', 'IN_PROGRESS'}.contains(status);
      test('$status : ${shown ? 'tuile' : 'rien'}', () {
        expect(
          _tiles(trip(status: status)),
          shown ? [TripTodoTile.depart] : isEmpty,
        );
      });
    }

    test('après les demandes, avant la carte', () {
      expect(
        _tiles(
          _trip(
            trackingActive: true,
            parcelsSummary: _summary,
            methods: const {BidPaymentMethod.cash},
          ),
          bids: [_bid('b1', 'PENDING')],
        ),
        [TripTodoTile.requests, TripTodoTile.depart, TripTodoTile.card],
      );
    });
  });

  group('carte à ajouter (espèces seules)', () {
    AnnouncementModel cashTrip({
      String status = 'ACTIVE',
      String currency = 'EUR',
    }) => _trip(
      status: status,
      methods: const {BidPaymentMethod.cash},
      currency: currency,
    );

    for (final status in _statuses) {
      final shown = const {'DRAFT', 'ACTIVE', 'FULL'}.contains(status);
      test('$status, Stripe prêt : ${shown ? 'tuile' : 'rien'}', () {
        expect(
          _tiles(cashTrip(status: status), stripe: _ready),
          shown ? [TripTodoTile.card] : isEmpty,
        );
      });
      test('$status, Stripe pas prêt : ${shown ? 'tuile' : 'rien'}', () {
        expect(
          _tiles(cashTrip(status: status)),
          shown ? [TripTodoTile.card] : isEmpty,
        );
      });
    }

    test('statut Stripe pas encore chargé : tuile (activation)', () {
      expect(_tiles(cashTrip(), stripe: const StripeAccountInitial()), [
        TripTodoTile.card,
      ]);
      expect(_tiles(cashTrip(), stripe: const StripeAccountLoadError()), [
        TripTodoTile.card,
      ]);
    });

    test('carte déjà acceptée : rien', () {
      expect(
        _tiles(
          _trip(
            methods: const {BidPaymentMethod.cash, BidPaymentMethod.stripe},
          ),
          stripe: _ready,
        ),
        isEmpty,
      );
      expect(_tiles(_trip(), stripe: _ready), isEmpty);
    });

    test('mobile money seul : rien', () {
      expect(
        _tiles(_trip(methods: const {BidPaymentMethod.mobileMoney})),
        isEmpty,
      );
    });

    test('espèces et mobile money : rien (pas « espèces seules »)', () {
      final trip = _trip(
        methods: const {BidPaymentMethod.cash, BidPaymentMethod.mobileMoney},
      );
      expect(_tiles(trip), isEmpty);
      expect(_tiles(trip, stripe: _ready), isEmpty);
    });

    test('devise sans carte (XOF) : rien', () {
      expect(_tiles(cashTrip(currency: 'XOF'), stripe: _ready), isEmpty);
    });

    test('Stripe absent du pays : rien', () {
      expect(_tiles(cashTrip(), stripe: _unavailable), isEmpty);
    });

    test('compte prêt seulement si l\'inscription est terminée', () {
      expect(tripCardPaymentsReady(_ready), isTrue);
      expect(tripCardPaymentsReady(_notReady), isFalse);
      expect(tripCardPaymentsReady(const StripeAccountInitial()), isFalse);
      expect(tripCardPaymentsReady(const StripeAccountLoading()), isFalse);
    });
  });

  test('non propriétaire : aucune tuile, même si tout est réuni', () {
    expect(
      _tiles(
        _trip(
          trackingActive: true,
          parcelsSummary: _summary,
          methods: const {BidPaymentMethod.cash},
        ),
        bids: [_bid('b1', 'PENDING')],
        isOwner: false,
        stripe: _ready,
      ),
      isEmpty,
    );
  });

  group('titres, résumés, icônes', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);
      test('${locale.languageCode} : libellés existants repris', () {
        expect(
          tripTodoTitle(l, TripTodoTile.requests, cardReady: false),
          l.tripTodoRequestsTitle,
        );
        expect(
          tripTodoTitle(l, TripTodoTile.depart, cardReady: false),
          l.tripDepartButton,
        );
        expect(
          tripTodoTitle(l, TripTodoTile.card, cardReady: true),
          l.listingEnableCardOnTripButton,
        );
        expect(
          tripTodoTitle(l, TripTodoTile.card, cardReady: false),
          l.listingActivateCardPaymentsButton,
        );
        expect(
          tripTodoSummary(
            l,
            TripTodoTile.requests,
            pendingCount: 2,
            cardReady: false,
          ),
          l.tripTodoRequestsSummary(2),
        );
        expect(
          tripTodoSummary(
            l,
            TripTodoTile.depart,
            pendingCount: 0,
            cardReady: false,
          ),
          l.tripTodoDepartSummary,
        );
        expect(
          tripTodoSummary(
            l,
            TripTodoTile.card,
            pendingCount: 0,
            cardReady: true,
          ),
          l.tripTodoCardReadySummary,
        );
        expect(
          tripTodoSummary(
            l,
            TripTodoTile.card,
            pendingCount: 0,
            cardReady: false,
          ),
          l.tripTodoCardActivateSummary,
        );
      });
    }

    test('résumé des demandes au singulier et au pluriel', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      expect(fr.tripTodoRequestsSummary(1), 'Une demande attend votre réponse');
      expect(
        fr.tripTodoRequestsSummary(3),
        '3 demandes attendent votre réponse',
      );
    });

    test('une icône par tuile', () {
      expect(TripTodoTile.values.map(tripTodoIcon), [
        'package',
        'plane',
        'credit-card',
      ]);
    });
  });

  group('mesure d\'affichage', () {
    test('bid_detail_todo_tile_shown, role trip_owner, statut du trajet', () {
      final shown = tripTodoShown(
        TripTodoTile.requests,
        _trip(status: 'FULL'),
        pendingCount: 2,
      );
      expect(shown.event, AnalyticsEvents.bidDetailTodoTileShown);
      expect(shown.tile, 'requests');
      expect(shown.properties, {
        'tile': 'requests',
        'role': 'trip_owner',
        'status': 'FULL',
      });
    });

    test('dédoublonnée par statut du trajet et nombre de demandes', () {
      final a = tripTodoShown(TripTodoTile.requests, _trip(), pendingCount: 1);
      final same = tripTodoShown(
        TripTodoTile.requests,
        _trip(),
        pendingCount: 1,
      );
      final more = tripTodoShown(
        TripTodoTile.requests,
        _trip(),
        pendingCount: 2,
      );
      final full = tripTodoShown(
        TripTodoTile.requests,
        _trip(status: 'FULL'),
        pendingCount: 1,
      );
      expect(a.status, same.status);
      expect(a.status, isNot(more.status));
      expect(a.status, isNot(full.status));
    });

    for (final tile in [TripTodoTile.depart, TripTodoTile.card]) {
      test('${tile.name} : dédoublonnée par statut du trajet seulement', () {
        final a = tripTodoShown(tile, _trip(), pendingCount: 0);
        final more = tripTodoShown(tile, _trip(), pendingCount: 3);
        final full = tripTodoShown(
          tile,
          _trip(status: 'FULL'),
          pendingCount: 0,
        );
        // Une demande reçue ou traitée ne remesure ni « Je pars » ni la
        // carte.
        expect(a.status, more.status);
        expect(a.status, 'ACTIVE');
        expect(a.status, isNot(full.status));
        expect(a.properties, {
          'tile': tile.name,
          'role': 'trip_owner',
          'status': 'ACTIVE',
        });
      });
    }
  });
}
