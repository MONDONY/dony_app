// Gestes « Je pars » et « carte » de l'écran du trajet (vue du voyageur
// propriétaire), repris par « À traiter » (`tripTodoFor`) : fonction pure
// pour chaque statut du trajet, demandes en attente, fenêtre de suivi,
// départ déjà confirmé et encart « espèces seules ».
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
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
  int confirmedParcelCount = 0,
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
    confirmedParcelCount: confirmedParcelCount,
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
    expect(TripTodoTile.values.map((t) => t.name), ['depart', 'card']);
  });

  group('demandes à traiter', () {
    final pending = [_bid('b1', 'PENDING'), _bid('b2', 'ACCEPTED')];
    final escrowed = [_bid('b3', 'PAYMENT_ESCROWED')];
    final none = [
      _bid('b4', 'ACCEPTED'),
      _bid('b5', 'REJECTED'),
      _bid('b6', 'IN_TRANSIT'),
    ];

    // Les demandes ne sont plus une tuile : l'action « À traiter »
    // `requests` de `tripTodoFor` les porte (trip_todo_test.dart).
    for (final status in _statuses) {
      test('$status avec des demandes : aucune tuile', () {
        expect(_tiles(_trip(status: status), bids: pending), isEmpty);
        expect(_tiles(_trip(status: status), bids: escrowed), isEmpty);
        expect(_tiles(_trip(status: status), bids: none), isEmpty);
        expect(
          _tiles(_trip(status: status, pendingBidCount: 2), bids: null),
          isEmpty,
        );
      });
    }

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

    test('avec des demandes', () {
      expect(
        _tiles(
          _trip(trackingActive: true, parcelsSummary: _summary),
          bids: [_bid('b1', 'PENDING')],
        ),
        [TripTodoTile.depart],
      );
    });

    // « Je pars » suppose des colis remis : le back refuse alors toute
    // modification du trajet, la tuile « carte » ne l'accompagne jamais.
    test('jamais avec la carte : colis remis, modification refusée', () {
      expect(
        _tiles(
          _trip(
            trackingActive: true,
            parcelsSummary: _summary,
            methods: const {BidPaymentMethod.cash},
          ),
          bids: [_bid('b1', 'PENDING')],
          stripe: _ready,
        ),
        [TripTodoTile.depart],
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

    test('avec des demandes', () {
      expect(_tiles(cashTrip(), bids: [_bid('b1', 'PENDING')]), [
        TripTodoTile.card,
      ]);
    });

    // Règle du back (`AnnouncementService.updateAnnouncement`) : 409
    // `modification-impossible` dès qu'un colis est ACCEPTED, HANDED_OVER,
    // IN_TRANSIT ou ARRIVED, quel que soit le statut du trajet. La tuile mène
    // à l'édition du trajet (ou à l'activation de la carte, puis à elle) :
    // elle n'existe que si le back accepterait la modification.
    group('modification acceptée par le back', () {
      for (final stripe in const [_ready, _notReady]) {
        final variant = stripe == _ready ? 'compte prêt' : 'compte pas prêt';
        for (final locking in const [
          'ACCEPTED',
          'HANDED_OVER',
          'IN_TRANSIT',
          'ARRIVED',
        ]) {
          test('ACTIVE avec un colis $locking ($variant) : rien', () {
            expect(
              _tiles(
                cashTrip(),
                bids: [_bid('b1', 'PENDING'), _bid('b2', locking)],
                stripe: stripe,
              ),
              isEmpty,
            );
          });
        }
        test('FULL avec un colis accepté ($variant) : rien', () {
          expect(
            _tiles(
              cashTrip(status: 'FULL'),
              bids: [_bid('b1', 'ACCEPTED')],
              stripe: stripe,
            ),
            isEmpty,
          );
        });
        test('ACTIVE avec seulement des demandes ($variant) : tuile', () {
          expect(
            _tiles(
              cashTrip(),
              bids: [_bid('b1', 'PENDING'), _bid('b2', 'PAYMENT_ESCROWED')],
              stripe: stripe,
            ),
            [TripTodoTile.card],
          );
        });
        test('DRAFT sans colis ($variant) : tuile', () {
          expect(_tiles(cashTrip(status: 'DRAFT'), stripe: stripe), [
            TripTodoTile.card,
          ]);
        });
      }

      test('paiement attendu, colis clôturés : ne bloquent pas', () {
        expect(
          _tiles(
            cashTrip(),
            bids: [
              _bid('b1', 'AWAITING_PAYMENT'),
              _bid('b2', 'CANCELLED'),
              _bid('b3', 'NO_SHOW'),
              _bid('b4', 'PARCEL_REFUSED'),
              _bid('b5', 'REJECTED'),
            ],
            stripe: _ready,
          ),
          [TripTodoTile.card],
        );
      });

      test('liste pas encore chargée : compteurs du détail', () {
        AnnouncementModel counted({
          int confirmed = 0,
          TripParcelsSummary? summary,
        }) => _trip(
          methods: const {BidPaymentMethod.cash},
          confirmedParcelCount: confirmed,
          parcelsSummary: summary,
        );
        expect(_tiles(counted(), bids: null, stripe: _ready), [
          TripTodoTile.card,
        ]);
        expect(
          _tiles(counted(confirmed: 1), bids: null, stripe: _ready),
          isEmpty,
        );
        expect(
          _tiles(counted(summary: _summary), bids: null, stripe: _ready),
          isEmpty,
        );
      });

      test('un compteur du détail suffit, même liste chargée sans colis', () {
        final trip = _trip(
          methods: const {BidPaymentMethod.cash},
          confirmedParcelCount: 1,
        );
        expect(_tiles(trip, stripe: _ready), isEmpty);
      });

      test('tripEditAcceptedByBack', () {
        expect(tripEditAcceptedByBack(_trip(), const []), isTrue);
        expect(tripEditAcceptedByBack(_trip(), null), isTrue);
        expect(
          tripEditAcceptedByBack(_trip(), [_bid('b1', 'PENDING')]),
          isTrue,
        );
        expect(
          tripEditAcceptedByBack(_trip(), [_bid('b1', 'ACCEPTED')]),
          isFalse,
        );
        expect(
          tripEditAcceptedByBack(_trip(status: 'DRAFT'), [
            _bid('b1', 'ARRIVED'),
          ]),
          isFalse,
        );
      });
    });

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

  test('suivi ouvert : trajet publié, complet ou en cours seulement', () {
    for (final status in _statuses) {
      expect(
        tripTrackingStatusOpen(status),
        const {'ACTIVE', 'FULL', 'IN_PROGRESS'}.contains(status),
        reason: status,
      );
    }
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
}
