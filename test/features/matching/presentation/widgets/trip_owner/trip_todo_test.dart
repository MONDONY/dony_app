// « À traiter » complet de l'écran du trajet vu par son voyageur (phase 1,
// app seule) : fonction pure `tripTodoFor` (16 types, urgence, échéances,
// tri), compte des actions, colis distincts pour la ligne Colis, liste pas
// encore chargée, statuts du trajet, visiteur, et mesure d'affichage.
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Horloge des tests : aucun appel à `DateTime.now()` dans la règle.
final _now = DateTime(2026, 10, 31, 12);
final _past = _now.subtract(const Duration(hours: 2));
final _future = _now.add(const Duration(hours: 5));

const _statuses = [
  'DRAFT',
  'ACTIVE',
  'FULL',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'REMOVED_BY_ADMIN',
];

const _notReady = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED'),
);

const _summary = TripParcelsSummary(
  count: 1,
  totalKg: 3,
  netAmount: 20,
  currency: 'EUR',
);

AnnouncementModel _trip({
  String status = 'ACTIVE',
  int pendingBidCount = 0,
  bool trackingActive = false,
  TripParcelsSummary? parcelsSummary,
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
  DateTime? handoverDeadline,
  String? arrivalInstructions,
}) => AnnouncementModel(
  id: 'trip-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
  departureDate: _now.add(const Duration(days: 3)),
  availableKg: 20,
  totalKg: 20,
  status: status,
  createdAt: _now,
  updatedAt: _now,
  pendingBidCount: pendingBidCount,
  trackingActive: trackingActive,
  parcelsSummary: parcelsSummary,
  acceptedPaymentMethods: methods,
  handoverDeadline: handoverDeadline,
  arrivalInstructions: arrivalInstructions,
);

BidModel _bid(
  String id,
  String status, {
  BidPaymentMethod paymentMethod = BidPaymentMethod.cash,
  bool voyageurConfirmed = false,
  DateTime? handoverDeadline,
  String? cancellationNoShowStatus,
  BidSupplement? supplement,
  List<BidAmendment> amendments = const [],
  DateTime? returnDeadline,
  DateTime? returnedAt,
  DateTime? departureAt,
  bool recipientDeclined = false,
  DateTime? recipientReplacementRequestedAt,
  bool travelerHasRated = false,
}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  paymentMethod: paymentMethod,
  voyageurConfirmed: voyageurConfirmed,
  handoverDeadline: handoverDeadline,
  cancellationNoShowStatus: cancellationNoShowStatus,
  supplement: supplement,
  amendments: amendments,
  returnDeadline: returnDeadline,
  returnedAt: returnedAt,
  departureAt: departureAt,
  recipientDeclined: recipientDeclined,
  recipientReplacementRequestedAt: recipientReplacementRequestedAt,
  travelerHasRated: travelerHasRated,
  recipientName: 'Fatou',
  recipientPhone: '+221770000000',
);

BidSupplement _supplement(
  BidSupplementStatus status, {
  bool blocksHandover = false,
  DateTime? expiresAt,
}) => BidSupplement(
  id: 'sup-1',
  status: status,
  grossAmount: 10,
  blocksHandover: blocksHandover,
  expiresAt: expiresAt,
);

BidAmendment _amendment(
  BidAmendmentStatus status, {
  bool blocksHandover = false,
  DateTime? expiresAt,
}) => BidAmendment(
  id: 'am-1',
  status: status,
  grossAmount: 10,
  blocksHandover: blocksHandover,
  expiresAt: expiresAt,
);

List<TripTodoItem> _todo(
  AnnouncementModel trip, {
  List<BidModel>? bids = const [],
  bool isOwner = true,
  bool departed = false,
  StripeAccountState stripe = _notReady,
  DateTime? now,
}) => tripTodoFor(
  trip: trip,
  bids: bids,
  isOwner: isOwner,
  now: now ?? _now,
  departed: departed,
  stripe: stripe,
);

List<TripTodoKind> _kinds(List<TripTodoItem> items) =>
    items.map((i) => i.kind).toList();

TripTodoItem? _item(List<TripTodoItem> items, TripTodoKind kind) =>
    items.where((i) => i.kind == kind).firstOrNull;

void main() {
  test('les noms des types sont figés (valeur `tile` des mesures)', () {
    expect(TripTodoKind.values.map((k) => k.name), [
      'requests',
      'presence',
      'scan',
      'amendment',
      'supplement',
      'senderAbsence',
      'returnParcel',
      'depart',
      'arrive',
      'deliver',
      'notify',
      'recipientDeclined',
      'instructions',
      'rate',
      'publish',
      'addCard',
    ]);
  });

  test('urgence de chaque type (décision du 31/10)', () {
    final urgent = TripTodoKind.values
        .where((k) => k.urgency == TripTodoUrgency.urgent)
        .toList();
    expect(urgent, [
      TripTodoKind.requests,
      TripTodoKind.presence,
      TripTodoKind.scan,
      TripTodoKind.amendment,
      TripTodoKind.supplement,
      TripTodoKind.senderAbsence,
      TripTodoKind.returnParcel,
    ]);
  });

  test('types par colis et types du trajet', () {
    expect(TripTodoKind.values.where((k) => k.perParcel).toList(), [
      TripTodoKind.presence,
      TripTodoKind.scan,
      TripTodoKind.amendment,
      TripTodoKind.supplement,
      TripTodoKind.senderAbsence,
      TripTodoKind.returnParcel,
      TripTodoKind.deliver,
      TripTodoKind.recipientDeclined,
      TripTodoKind.rate,
    ]);
  });

  group('#1 demandes', () {
    test('PENDING espèces et PAYMENT_ESCROWED comptent, une par demande', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid('b1', 'PENDING'),
          _bid(
            'b2',
            'PAYMENT_ESCROWED',
            paymentMethod: BidPaymentMethod.stripe,
          ),
          _bid('b3', 'PENDING', paymentMethod: BidPaymentMethod.mobileMoney),
        ],
      );
      final requests = _item(items, TripTodoKind.requests)!;
      expect(requests.count, 3);
      expect(requests.bidIds, ['b1', 'b2', 'b3']);
      expect(requests.urgency, TripTodoUrgency.urgent);
      // Échéance d'une demande non servie par le back : hors phase 1.
      expect(requests.dueAt, isNull);
    });

    test('une carte pas encore payée (PENDING + STRIPE) ne compte pas', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid('b1', 'PENDING', paymentMethod: BidPaymentMethod.stripe),
          _bid('b2', 'PENDING'),
        ],
      );
      expect(_item(items, TripTodoKind.requests)!.bidIds, ['b2']);
      expect(
        _todo(
          _trip(),
          bids: [_bid('b1', 'PENDING', paymentMethod: BidPaymentMethod.stripe)],
        ),
        isEmpty,
      );
    });

    test('seulement sur un trajet ACTIVE ou FULL', () {
      for (final status in _statuses) {
        final items = _todo(
          _trip(status: status),
          bids: [_bid('b1', 'PENDING')],
        );
        expect(
          _kinds(items).contains(TripTodoKind.requests),
          status == 'ACTIVE' || status == 'FULL',
          reason: status,
        );
      }
    });

    test('date limite de dépôt du trajet : avant oui, à partir de non', () {
      final bids = [_bid('b1', 'PENDING')];
      final before = _todo(
        _trip(handoverDeadline: _now.add(const Duration(minutes: 1))),
        bids: bids,
      );
      expect(_kinds(before), contains(TripTodoKind.requests));
      final at = _todo(_trip(handoverDeadline: _now), bids: bids);
      expect(_kinds(at), isNot(contains(TripTodoKind.requests)));
      final after = _todo(_trip(handoverDeadline: _past), bids: bids);
      expect(_kinds(after), isNot(contains(TripTodoKind.requests)));
    });

    test('un colis accepté, refusé ou annulé n’est pas une demande', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid('b1', 'REJECTED'),
          _bid('b2', 'CANCELLED'),
          _bid('b3', 'AWAITING_PAYMENT'),
        ],
      );
      expect(_kinds(items), isNot(contains(TripTodoKind.requests)));
    });
  });

  group('#7 confirmer la présence', () {
    test('ACCEPTED, pas confirmée, avant la date limite', () {
      final items = _todo(
        _trip(),
        bids: [_bid('b1', 'ACCEPTED', handoverDeadline: _future)],
      );
      final presence = _item(items, TripTodoKind.presence)!;
      expect(presence.bidIds, ['b1']);
      expect(presence.dueAt, _future);
      expect(presence.urgency, TripTodoUrgency.urgent);
      // Le scan n'est pas encore proposé (même règle que la fiche colis).
      expect(_kinds(items), isNot(contains(TripTodoKind.scan)));
    });

    test('déjà confirmée : plus de présence, le scan prend le relais', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid(
            'b1',
            'ACCEPTED',
            handoverDeadline: _future,
            voyageurConfirmed: true,
          ),
        ],
      );
      expect(_kinds(items), isNot(contains(TripTodoKind.presence)));
      expect(_kinds(items), contains(TripTodoKind.scan));
    });

    test('date limite juste avant / juste après', () {
      final bid = _bid(
        'b1',
        'ACCEPTED',
        handoverDeadline: _now.add(const Duration(seconds: 1)),
      );
      expect(
        _kinds(_todo(_trip(), bids: [bid])),
        contains(TripTodoKind.presence),
      );
      final later = _todo(
        _trip(),
        bids: [bid],
        now: _now.add(const Duration(seconds: 2)),
      );
      expect(_kinds(later), isNot(contains(TripTodoKind.presence)));
    });

    test('sans date limite : la présence reste à confirmer, sans échéance', () {
      final items = _todo(_trip(), bids: [_bid('b1', 'ACCEPTED')]);
      expect(_item(items, TripTodoKind.presence)!.dueAt, isNull);
    });
  });

  group('#8 récupérer le colis (scan de départ)', () {
    test('présence confirmée : échéance = date limite + 1 h', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid(
            'b1',
            'ACCEPTED',
            handoverDeadline: _future,
            voyageurConfirmed: true,
          ),
        ],
      );
      final scan = _item(items, TripTodoKind.scan)!;
      expect(scan.dueAt, _future.add(const Duration(hours: 1)));
      expect(scan.urgency, TripTodoUrgency.urgent);
    });

    test('date limite passée sans présence : récupérer reste possible', () {
      final items = _todo(
        _trip(),
        bids: [_bid('b1', 'ACCEPTED', handoverDeadline: _past)],
      );
      expect(_kinds(items), contains(TripTodoKind.scan));
    });

    test('bloqué par un supplément, une modification ou une déclaration', () {
      BidModel accepted({
        BidSupplement? supplement,
        List<BidAmendment> amendments = const [],
        String? noShow,
      }) => _bid(
        'b1',
        'ACCEPTED',
        handoverDeadline: _future,
        voyageurConfirmed: true,
        supplement: supplement,
        amendments: amendments,
        cancellationNoShowStatus: noShow,
      );
      final blocked = [
        accepted(
          supplement: _supplement(
            BidSupplementStatus.proposed,
            blocksHandover: true,
          ),
        ),
        accepted(
          amendments: [
            _amendment(BidAmendmentStatus.proposed, blocksHandover: true),
          ],
        ),
        accepted(noShow: 'CONTESTED'),
        accepted(noShow: 'CONFIRMED'),
      ];
      for (final bid in blocked) {
        expect(
          _kinds(_todo(_trip(), bids: [bid])),
          isNot(contains(TripTodoKind.scan)),
        );
      }
      // Une déclaration encore en attente ne bloque pas : le scan la lève.
      expect(
        _kinds(
          _todo(_trip(), bids: [accepted(noShow: 'PENDING_CONFIRMATION')]),
        ),
        contains(TripTodoKind.scan),
      );
    });

    test('plusieurs colis : un seul item, échéance la plus proche', () {
      final soon = _now.add(const Duration(hours: 1));
      final items = _todo(
        _trip(),
        bids: [
          _bid(
            'late',
            'ACCEPTED',
            handoverDeadline: _future,
            voyageurConfirmed: true,
          ),
          _bid(
            'soon',
            'ACCEPTED',
            handoverDeadline: soon,
            voyageurConfirmed: true,
          ),
        ],
      );
      final scan = _item(items, TripTodoKind.scan)!;
      expect(scan.count, 2);
      expect(scan.bidIds, ['soon', 'late']);
      expect(scan.dueAt, soon.add(const Duration(hours: 1)));
      expect(scan.dueAtByBid['late'], _future.add(const Duration(hours: 1)));
    });
  });

  group('#9 #11 #12 modification', () {
    test('PROPOSED : à traiter, échéance = expiresAt', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid(
            'b1',
            'ACCEPTED',
            voyageurConfirmed: true,
            amendments: [
              _amendment(
                BidAmendmentStatus.proposed,
                blocksHandover: true,
                expiresAt: _future,
              ),
            ],
          ),
        ],
      );
      final amendment = _item(items, TripTodoKind.amendment)!;
      expect(amendment.dueAt, _future);
      expect(amendment.urgency, TripTodoUrgency.urgent);
    });

    test('COMMISSION_PENDING : à traiter', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid(
            'b1',
            'ACCEPTED',
            amendments: [_amendment(BidAmendmentStatus.commissionPending)],
          ),
        ],
      );
      expect(_kinds(items), contains(TripTodoKind.amendment));
    });

    test('autorisation carte, acceptée ou close : rien à faire', () {
      for (final status in [
        BidAmendmentStatus.authorizationPending,
        BidAmendmentStatus.declined,
        BidAmendmentStatus.expired,
      ]) {
        final items = _todo(
          _trip(),
          bids: [
            _bid('b1', 'ACCEPTED', amendments: [_amendment(status)]),
          ],
        );
        expect(
          _kinds(items),
          isNot(contains(TripTodoKind.amendment)),
          reason: status.name,
        );
      }
    });
  });

  group('#10 supplément', () {
    test('COMMISSION_PENDING : à valider, échéance = expiresAt', () {
      final items = _todo(
        _trip(),
        bids: [
          _bid(
            'b1',
            'ACCEPTED',
            supplement: _supplement(
              BidSupplementStatus.commissionPending,
              expiresAt: _future,
            ),
          ),
        ],
      );
      final supplement = _item(items, TripTodoKind.supplement)!;
      expect(supplement.dueAt, _future);
      expect(supplement.urgency, TripTodoUrgency.urgent);
    });

    test('proposé, refusé ou expiré : rien à faire pour le voyageur', () {
      for (final status in [
        BidSupplementStatus.proposed,
        BidSupplementStatus.declined,
        BidSupplementStatus.expired,
      ]) {
        final items = _todo(
          _trip(),
          bids: [_bid('b1', 'ACCEPTED', supplement: _supplement(status))],
        );
        expect(
          _kinds(items),
          isNot(contains(TripTodoKind.supplement)),
          reason: status.name,
        );
      }
    });
  });

  group('#16 absence de l’expéditeur', () {
    test(
      'date limite dépassée, pas déclarée : échéance = date limite + 1 h',
      () {
        final items = _todo(
          _trip(),
          bids: [_bid('b1', 'ACCEPTED', handoverDeadline: _past)],
        );
        final absence = _item(items, TripTodoKind.senderAbsence)!;
        expect(absence.dueAt, _past.add(const Duration(hours: 1)));
        expect(absence.urgency, TripTodoUrgency.urgent);
      },
    );

    test('avant la date limite, ou déjà déclarée : non', () {
      expect(
        _kinds(
          _todo(
            _trip(),
            bids: [_bid('b1', 'ACCEPTED', handoverDeadline: _future)],
          ),
        ),
        isNot(contains(TripTodoKind.senderAbsence)),
      );
      for (final noShow in [
        'PENDING_CONFIRMATION',
        'CONTESTED',
        'CONFIRMED',
        'RESOLVED',
      ]) {
        final items = _todo(
          _trip(),
          bids: [
            _bid(
              'b1',
              'ACCEPTED',
              handoverDeadline: _past,
              cancellationNoShowStatus: noShow,
            ),
          ],
        );
        expect(
          _kinds(items),
          isNot(contains(TripTodoKind.senderAbsence)),
          reason: noShow,
        );
      }
    });

    test('colis déjà remis : non', () {
      final items = _todo(
        _trip(),
        bids: [_bid('b1', 'HANDED_OVER', handoverDeadline: _past)],
      );
      expect(_kinds(items), isNot(contains(TripTodoKind.senderAbsence)));
    });
  });

  group('#28 restitution', () {
    test('colis annulé à rendre, sur un trajet annulé', () {
      final items = _todo(
        _trip(status: 'CANCELLED'),
        bids: [_bid('b1', 'CANCELLED', returnDeadline: _future)],
      );
      final ret = _item(items, TripTodoKind.returnParcel)!;
      expect(ret.bidIds, ['b1']);
      expect(ret.dueAt, _future);
      expect(ret.urgency, TripTodoUrgency.urgent);
    });

    test('déjà rendu, ou sans délai de retour : non', () {
      final items = _todo(
        _trip(status: 'CANCELLED'),
        bids: [
          _bid('b1', 'CANCELLED', returnDeadline: _future, returnedAt: _past),
          _bid('b2', 'CANCELLED'),
        ],
      );
      expect(items, isEmpty);
    });
  });

  group('#25 valider la remise', () {
    test('remis, en transit ou arrivé, trajet parti', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS'),
        bids: [
          _bid('b1', 'HANDED_OVER', departureAt: _past),
          _bid('b2', 'IN_TRANSIT', departureAt: _past),
          _bid('b3', 'ARRIVED', departureAt: _past),
        ],
      );
      final deliver = _item(items, TripTodoKind.deliver)!;
      expect(deliver.count, 3);
      expect(deliver.urgency, TripTodoUrgency.important);
      expect(deliver.dueAt, isNull);
    });

    test('pas encore parti (heure de départ à venir) : non', () {
      final items = _todo(
        _trip(),
        bids: [_bid('b1', 'HANDED_OVER', departureAt: _future)],
      );
      expect(_kinds(items), isNot(contains(TripTodoKind.deliver)));
    });

    test('départ juste atteint : oui', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS'),
        bids: [_bid('b1', 'IN_TRANSIT', departureAt: _now)],
      );
      expect(_kinds(items), contains(TripTodoKind.deliver));
    });

    test('départ inconnu : le serveur tranche, l’action reste', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS'),
        bids: [_bid('b1', 'IN_TRANSIT')],
      );
      expect(_kinds(items), contains(TripTodoKind.deliver));
    });
  });

  group('#24 prévenir les destinataires', () {
    test('arrivée marquée, plus rien à bord : une action du trajet', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS', arrivalInstructions: 'Gare routière'),
        bids: [
          _bid('b1', 'ARRIVED', departureAt: _past),
          _bid('b2', 'ARRIVED', departureAt: _past),
        ],
      );
      final notify = _item(items, TripTodoKind.notify)!;
      expect(notify.count, 1);
      expect(notify.bidIds, ['b1', 'b2']);
      expect(notify.urgency, TripTodoUrgency.important);
    });

    test('un colis encore à bord : « Arrivé à destination » d’abord', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS'),
        bids: [
          _bid('b1', 'ARRIVED', departureAt: _past),
          _bid('b2', 'IN_TRANSIT', departureAt: _past),
        ],
      );
      expect(_kinds(items), isNot(contains(TripTodoKind.notify)));
      expect(_kinds(items), contains(TripTodoKind.arrive));
    });

    test('trajet terminé ou annulé : non', () {
      for (final status in ['COMPLETED', 'CANCELLED']) {
        final items = _todo(
          _trip(status: status),
          bids: [_bid('b1', 'ARRIVED', departureAt: _past)],
        );
        expect(
          _kinds(items),
          isNot(contains(TripTodoKind.notify)),
          reason: status,
        );
      }
    });
  });

  group('#21 destinataire refusé', () {
    test('refus, colis en cours, aucune demande récente', () {
      final items = _todo(
        _trip(),
        bids: [_bid('b1', 'ACCEPTED', recipientDeclined: true)],
      );
      final declined = _item(items, TripTodoKind.recipientDeclined)!;
      expect(declined.urgency, TripTodoUrgency.important);
    });

    test('demande envoyée il y a moins de 12 h : non ; 12 h après : oui', () {
      BidModel bid(Duration ago) => _bid(
        'b1',
        'ACCEPTED',
        recipientDeclined: true,
        recipientReplacementRequestedAt: _now.subtract(ago),
      );
      expect(
        _kinds(_todo(_trip(), bids: [bid(const Duration(hours: 11))])),
        isNot(contains(TripTodoKind.recipientDeclined)),
      );
      expect(
        _kinds(_todo(_trip(), bids: [bid(const Duration(hours: 12))])),
        contains(TripTodoKind.recipientDeclined),
      );
    });

    test('colis livré ou destinataire d’accord : non', () {
      final items = _todo(
        _trip(status: 'COMPLETED'),
        bids: [
          _bid(
            'b1',
            'COMPLETED',
            recipientDeclined: true,
            travelerHasRated: true,
          ),
          _bid('b2', 'ACCEPTED', handoverDeadline: _future),
        ],
      );
      expect(_kinds(items), isNot(contains(TripTodoKind.recipientDeclined)));
    });
  });

  group('#30 noter l’expéditeur', () {
    test('livré, pas encore noté', () {
      final items = _todo(
        _trip(status: 'COMPLETED'),
        bids: [_bid('b1', 'COMPLETED'), _bid('b2', 'DELIVERED')],
      );
      final rate = _item(items, TripTodoKind.rate)!;
      expect(rate.count, 2);
      expect(rate.urgency, TripTodoUrgency.important);
    });

    test('déjà noté, ou pas livré : non', () {
      final items = _todo(
        _trip(status: 'COMPLETED'),
        bids: [
          _bid('b1', 'COMPLETED', travelerHasRated: true),
          _bid('b2', 'CANCELLED'),
        ],
      );
      expect(items, isEmpty);
    });
  });

  group('#32 publier', () {
    test('brouillon seulement, même sans la liste des colis', () {
      for (final status in _statuses) {
        final items = _todo(_trip(status: status), bids: null);
        expect(
          _kinds(items).contains(TripTodoKind.publish),
          status == 'DRAFT',
          reason: status,
        );
      }
      final publish = _item(
        _todo(_trip(status: 'DRAFT')),
        TripTodoKind.publish,
      )!;
      expect(publish.count, 1);
      expect(publish.bidIds, isEmpty);
      expect(publish.urgency, TripTodoUrgency.important);
    });
  });

  group('#34 ajouter la carte', () {
    test('règle de tripTodoTilesFor : espèces seules, carte possible', () {
      final cashOnly = _trip(methods: const {BidPaymentMethod.cash});
      expect(_kinds(_todo(cashOnly)), [TripTodoKind.addCard]);
      expect(_kinds(_todo(_trip())), isEmpty);
      // Un colis en vol verrouille la modification du trajet.
      expect(
        _kinds(
          _todo(
            cashOnly,
            bids: [_bid('b1', 'ACCEPTED', handoverDeadline: _future)],
          ),
        ),
        isNot(contains(TripTodoKind.addCard)),
      );
    });

    test('paiement par carte fermé dans le pays : non', () {
      const unavailable = StripeAccountReady(
        ConnectAccountStatus(
          status: 'NOT_CREATED',
          connectAvailableInCountry: false,
        ),
      );
      final items = _todo(
        _trip(methods: const {BidPaymentMethod.cash}),
        stripe: unavailable,
      );
      expect(items, isEmpty);
    });
  });

  group('#37 je pars', () {
    final trip = _trip(trackingActive: true, parcelsSummary: _summary);

    test('colis remis, fenêtre de suivi ouverte, pas encore confirmé', () {
      final items = _todo(trip, bids: null);
      expect(_kinds(items), [TripTodoKind.depart]);
      expect(items.single.urgency, TripTodoUrgency.important);
    });

    test('déjà confirmé sur cet appareil, ou fenêtre fermée : non', () {
      expect(_todo(trip, departed: true), isEmpty);
      expect(_todo(_trip(parcelsSummary: _summary)), isEmpty);
    });
  });

  group('#38 arrivé à destination', () {
    test('trajet parti avec un colis à bord', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS', arrivalInstructions: 'Gare'),
        bids: [_bid('b1', 'HANDED_OVER', departureAt: _future)],
      );
      expect(_kinds(items), [TripTodoKind.arrive]);
    });

    test('trajet encore ACTIVE avec un colis remis : non', () {
      final items = _todo(
        _trip(),
        bids: [_bid('b1', 'HANDED_OVER', departureAt: _future)],
      );
      expect(_kinds(items), isNot(contains(TripTodoKind.arrive)));
    });
  });

  group('#39 instructions de retrait', () {
    test('un colis arrivé, instructions vides ou blanches', () {
      for (final instructions in [null, '', '   ']) {
        final items = _todo(
          _trip(status: 'IN_PROGRESS', arrivalInstructions: instructions),
          bids: [_bid('b1', 'ARRIVED', departureAt: _past)],
        );
        expect(
          _kinds(items),
          contains(TripTodoKind.instructions),
          reason: '$instructions',
        );
      }
    });

    test('instructions renseignées, ou aucun colis arrivé : non', () {
      final filled = _todo(
        _trip(status: 'IN_PROGRESS', arrivalInstructions: 'Gare routière'),
        bids: [_bid('b1', 'ARRIVED', departureAt: _past)],
      );
      expect(_kinds(filled), isNot(contains(TripTodoKind.instructions)));
      final notArrived = _todo(
        _trip(status: 'IN_PROGRESS'),
        bids: [_bid('b1', 'IN_TRANSIT', departureAt: _future)],
      );
      expect(_kinds(notArrived), isNot(contains(TripTodoKind.instructions)));
    });
  });

  group('tri', () {
    test('urgent avant important, puis ordre fixe', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS'),
        bids: [
          _bid('b1', 'COMPLETED'),
          _bid('b2', 'ARRIVED', departureAt: _past),
          _bid('b3', 'CANCELLED', returnDeadline: _future),
        ],
      );
      expect(_kinds(items), [
        TripTodoKind.returnParcel,
        TripTodoKind.deliver,
        TripTodoKind.notify,
        TripTodoKind.instructions,
        TripTodoKind.rate,
      ]);
    });

    test('dans les urgents, l’échéance la plus proche d’abord', () {
      final soon = _now.add(const Duration(minutes: 30));
      final items = _todo(
        _trip(),
        bids: [
          _bid('b1', 'PENDING'),
          _bid('b2', 'ACCEPTED', handoverDeadline: _future),
          _bid(
            'b3',
            'ACCEPTED',
            voyageurConfirmed: true,
            amendments: [
              _amendment(
                BidAmendmentStatus.proposed,
                blocksHandover: true,
                expiresAt: soon,
              ),
            ],
          ),
          _bid(
            'b4',
            'CANCELLED',
            returnDeadline: _now.add(const Duration(days: 2)),
          ),
        ],
      );
      // Échéances connues d'abord (modification 30 min, présence 5 h,
      // restitution 2 j), puis la demande sans échéance.
      expect(_kinds(items), [
        TripTodoKind.amendment,
        TripTodoKind.presence,
        TripTodoKind.returnParcel,
        TripTodoKind.requests,
      ]);
    });

    test('à échéance égale, ordre fixe des types', () {
      final items = _todo(
        _trip(),
        bids: [_bid('b1', 'ACCEPTED', handoverDeadline: _past)],
      );
      // scan et absence de l'expéditeur partagent date limite + 1 h.
      expect(_kinds(items), [TripTodoKind.scan, TripTodoKind.senderAbsence]);
    });
  });

  group('compte et colis distincts', () {
    final bids = [
      _bid('p1', 'PENDING'),
      _bid('p2', 'PENDING'),
      _bid('a1', 'ACCEPTED', handoverDeadline: _past),
      _bid(
        'a2',
        'ACCEPTED',
        voyageurConfirmed: true,
        handoverDeadline: _future,
        supplement: _supplement(BidSupplementStatus.commissionPending),
      ),
      _bid('r1', 'CANCELLED', returnDeadline: _future),
    ];

    test('compte = somme des actions, colis distincts sans les demandes', () {
      final items = _todo(
        _trip(trackingActive: true, parcelsSummary: _summary),
        bids: bids,
      );
      // Urgents à échéance (date limite passée + 1 h, puis retour), urgents
      // sans échéance dans l'ordre fixe (demandes, supplément), puis
      // « Je pars ».
      expect(_kinds(items), [
        TripTodoKind.scan,
        TripTodoKind.senderAbsence,
        TripTodoKind.returnParcel,
        TripTodoKind.requests,
        TripTodoKind.supplement,
        TripTodoKind.depart,
      ]);
      // 2 demandes + scan a1, a2 + absence a1 + supplément a2 + retour r1
      // + « Je pars ».
      expect(tripTodoCount(items), 2 + 2 + 1 + 1 + 1 + 1);
      expect(tripTodoParcelIds(items), {'a1', 'a2', 'r1'});
    });

    test('rien à traiter : 0 et aucun colis', () {
      expect(tripTodoCount(const []), 0);
      expect(tripTodoParcelIds(const []), isEmpty);
    });

    test('« Prévenir » ne marque aucun colis de la ligne Colis', () {
      final items = _todo(
        _trip(status: 'IN_PROGRESS', arrivalInstructions: 'Gare'),
        bids: [_bid('b1', 'ARRIVED', departureAt: _future)],
      );
      expect(_kinds(items), [TripTodoKind.notify]);
      expect(tripTodoParcelIds(items), isEmpty);
      expect(tripTodoCount(items), 1);
    });
  });

  group('liste des colis pas encore chargée (bids == null)', () {
    test('seuls « Je pars », « Publier » et « Ajouter la carte » restent', () {
      final active = _todo(
        _trip(
          pendingBidCount: 3,
          trackingActive: true,
          parcelsSummary: _summary,
          methods: const {BidPaymentMethod.cash},
        ),
        bids: null,
      );
      // La carte : un colis remis (parcelsSummary) verrouille l'édition.
      expect(_kinds(active), [TripTodoKind.depart]);
      final draft = _todo(
        _trip(status: 'DRAFT', methods: const {BidPaymentMethod.cash}),
        bids: null,
      );
      expect(_kinds(draft), [TripTodoKind.publish, TripTodoKind.addCard]);
      // Aucune demande déduite de `pendingBidCount`.
      expect(_kinds(_todo(_trip(pendingBidCount: 2), bids: null)), isEmpty);
    });
  });

  group('statuts du trajet', () {
    test(
      'aucun item sans colis ni geste de trajet, quel que soit le statut',
      () {
        for (final status in _statuses) {
          final items = _todo(_trip(status: status));
          expect(
            _kinds(items),
            status == 'DRAFT' ? [TripTodoKind.publish] : isEmpty,
            reason: status,
          );
        }
      },
    );

    test('REMOVED_BY_ADMIN : ni demande, ni départ, ni carte', () {
      final items = _todo(
        _trip(
          status: 'REMOVED_BY_ADMIN',
          trackingActive: true,
          parcelsSummary: _summary,
          methods: const {BidPaymentMethod.cash},
        ),
        bids: [_bid('b1', 'PENDING')],
      );
      expect(items, isEmpty);
    });
  });

  test('visiteur (non propriétaire) : aucun item', () {
    final items = _todo(
      _trip(
        status: 'DRAFT',
        trackingActive: true,
        parcelsSummary: _summary,
        methods: const {BidPaymentMethod.cash},
      ),
      bids: [
        _bid('b1', 'PENDING'),
        _bid('b2', 'ACCEPTED', handoverDeadline: _past),
        _bid('b3', 'CANCELLED', returnDeadline: _future),
      ],
      isOwner: false,
    );
    expect(items, isEmpty);
  });

  group('DeliveryWindow.isOpenAt', () {
    test('avec heure : ouvert à partir de l’instant de départ', () {
      final window = DeliveryWindow(departure: _now, hasTime: true);
      expect(
        window.isOpenAt(_now.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(window.isOpenAt(_now), isTrue);
    });

    test('sans heure : ouvert le lendemain du jour de départ', () {
      final window = DeliveryWindow(
        departure: DateTime(2026, 10, 31),
        hasTime: false,
      );
      expect(window.isOpenAt(DateTime(2026, 10, 31, 23, 59)), isFalse);
      expect(window.isOpenAt(DateTime(2026, 11)), isTrue);
    });
  });

  group('mesure d’affichage', () {
    final trip = _trip(status: 'IN_PROGRESS');
    const item = TripTodoItem(
      kind: TripTodoKind.deliver,
      count: 2,
      bidIds: ['b1', 'b2'],
    );

    test('bid_detail_todo_tile_shown, tile = nom du type, role trip_owner', () {
      final shown = tripTodoItemShown(item, trip);
      expect(shown.event, AnalyticsEvents.bidDetailTodoTileShown);
      expect(shown.tile, 'deliver');
      expect(shown.properties, {
        'tile': 'deliver',
        'role': 'trip_owner',
        'status': 'IN_PROGRESS',
        'count': 2,
      });
    });

    test('dédoublonnée par type et nombre', () {
      final same = tripTodoItemShown(item, trip);
      final more = tripTodoItemShown(
        const TripTodoItem(
          kind: TripTodoKind.deliver,
          count: 3,
          bidIds: ['b1', 'b2', 'b3'],
        ),
        trip,
      );
      final otherTripStatus = tripTodoItemShown(item, _trip());
      expect(same.status, tripTodoItemShown(item, trip).status);
      expect(more.status, isNot(same.status));
      // Le statut du trajet n'entre pas dans la clé.
      expect(otherTripStatus.status, same.status);
    });
  });

  test('TripTodoItem : urgence lue du type', () {
    const item = TripTodoItem(kind: TripTodoKind.returnParcel, count: 1);
    expect(item.urgency, TripTodoUrgency.urgent);
    expect(item.bidIds, isEmpty);
    expect(item.dueAt, isNull);
    expect(item.dueAtByBid, isEmpty);
  });
}
