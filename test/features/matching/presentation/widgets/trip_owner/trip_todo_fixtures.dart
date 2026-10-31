// Fixtures « À traiter » de l'écran du trajet : horloge figée, trajet et
// colis de test, et une situation par type d'action qui la met EN TÊTE de la
// file (grosse carte, pied collant), reprises par les tests de la section,
// des sheets par colis, des libellés et des scénarios de la maquette.
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';

/// Horloge des tests : 1er novembre 2026, midi, avant le départ du trajet.
final kTodoNow = DateTime(2026, 11, 1, 12);

/// Départ du trajet de test (et des colis) : la remise au destinataire ne
/// s'ouvre qu'après (sauf colis « parti » [kTodoDeparted]).
final kTodoDeparture = DateTime(2026, 11, 12);

/// Jour de départ déjà passé : remise ouverte.
final kTodoDeparted = DateTime(2026, 10, 30);

const kTodoStripeReady = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);

const kTodoSummary = TripParcelsSummary(
  count: 1,
  totalKg: 3,
  netAmount: 21,
  currency: 'EUR',
);

AnnouncementModel todoTrip({
  String status = 'ACTIVE',
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
  bool trackingActive = false,
  TripParcelsSummary? summary,
  String? instructions,
  String? timezone,
}) => AnnouncementModel(
  id: 'trip-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: kTodoDeparture,
  availableKg: 20,
  totalKg: 20,
  pricePerKg: 7,
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  acceptedPaymentMethods: methods,
  trackingActive: trackingActive,
  parcelsSummary: summary,
  arrivalInstructions: instructions,
  departureTimezone: timezone,
);

BidModel todoBid(
  String id,
  String status, {
  BidPaymentMethod paymentMethod = BidPaymentMethod.cash,
  bool voyageurConfirmed = false,
  DateTime? handoverDeadline,
  BidSupplement? supplement,
  List<BidAmendment> amendments = const [],
  DateTime? returnDeadline,
  bool recipientDeclined = false,
  DateTime? departureDate,
  String? senderName,
}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  senderName: senderName ?? 'Expéditeur $id',
  weightKg: 3,
  description: 'Contenu $id',
  status: status,
  paymentMethod: paymentMethod,
  voyageurConfirmed: voyageurConfirmed,
  handoverDeadline: handoverDeadline,
  supplement: supplement,
  amendments: amendments,
  returnDeadline: returnDeadline,
  recipientDeclined: recipientDeclined,
  departureDate: departureDate ?? kTodoDeparture,
  recipientName: 'Fatou',
  recipientPhone: '+221770000000',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Situation d'écran : trajet, colis, compte de paiement, départ confirmé.
typedef TodoScenario = ({
  AnnouncementModel trip,
  List<BidModel> bids,
  StripeAccountState stripe,
  bool departed,
});

TodoScenario _s(
  AnnouncementModel trip,
  List<BidModel> bids, {
  StripeAccountState stripe = const StripeAccountInitial(),
}) => (trip: trip, bids: bids, stripe: stripe, departed: false);

/// Une situation dont l'action en tête est [kind] (à [kTodoNow]).
TodoScenario todoScenarioFor(TripTodoKind kind) {
  final now = kTodoNow;
  return switch (kind) {
    TripTodoKind.requests => _s(todoTrip(), [
      todoBid('r1', 'PAYMENT_ESCROWED', paymentMethod: BidPaymentMethod.stripe),
    ]),
    TripTodoKind.presence => _s(todoTrip(status: 'FULL'), [
      todoBid(
        'b1',
        'ACCEPTED',
        handoverDeadline: now.add(const Duration(hours: 5)),
      ),
    ]),
    TripTodoKind.scan => _s(todoTrip(status: 'FULL'), [
      todoBid(
        'b1',
        'ACCEPTED',
        voyageurConfirmed: true,
        handoverDeadline: now.add(const Duration(hours: 2)),
      ),
    ]),
    TripTodoKind.amendment => _s(todoTrip(status: 'FULL'), [
      todoBid(
        'b1',
        'ACCEPTED',
        voyageurConfirmed: true,
        amendments: [
          BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.proposed,
            grossAmount: 10,
            blocksHandover: true,
            expiresAt: now.add(const Duration(days: 1)),
          ),
        ],
      ),
    ]),
    TripTodoKind.supplement => _s(todoTrip(status: 'FULL'), [
      todoBid(
        'b1',
        'ACCEPTED',
        voyageurConfirmed: true,
        supplement: BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.commissionPending,
          grossAmount: 10,
          blocksHandover: true,
          expiresAt: now.add(const Duration(minutes: 90)),
        ),
      ),
    ]),
    // Scan bloqué par un supplément chez l'expéditeur : l'absence passe en
    // tête (à échéance égale, le scan la précéderait).
    TripTodoKind.senderAbsence => _s(todoTrip(status: 'FULL'), [
      todoBid(
        'b1',
        'ACCEPTED',
        handoverDeadline: now.subtract(const Duration(minutes: 30)),
        supplement: const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.proposed,
          grossAmount: 10,
          blocksHandover: true,
        ),
      ),
    ]),
    TripTodoKind.returnParcel => _s(todoTrip(status: 'CANCELLED'), [
      todoBid(
        'b1',
        'CANCELLED',
        returnDeadline: now.add(const Duration(days: 2)),
      ),
    ]),
    TripTodoKind.depart => _s(
      todoTrip(trackingActive: true, summary: kTodoSummary),
      [todoBid('b1', 'HANDED_OVER')],
    ),
    TripTodoKind.arrive => _s(todoTrip(status: 'IN_PROGRESS'), [
      todoBid('b1', 'IN_TRANSIT'),
    ]),
    TripTodoKind.deliver => _s(
      todoTrip(status: 'IN_PROGRESS', instructions: 'Gare routière'),
      [todoBid('b1', 'ARRIVED', departureDate: kTodoDeparted)],
    ),
    TripTodoKind.notify => _s(
      todoTrip(status: 'IN_PROGRESS', instructions: 'Gare routière'),
      [todoBid('b1', 'ARRIVED'), todoBid('b2', 'ARRIVED')],
    ),
    TripTodoKind.recipientDeclined => _s(todoTrip(), [
      todoBid('b1', 'HANDED_OVER', recipientDeclined: true),
    ]),
    // Un colis encore à bord : ni « Prévenir » ni « Arrivé » (trajet pas
    // parti), les instructions restent à renseigner.
    TripTodoKind.instructions => _s(todoTrip(status: 'FULL'), [
      todoBid('b1', 'ARRIVED'),
      todoBid('b2', 'HANDED_OVER'),
    ]),
    TripTodoKind.rate => _s(todoTrip(status: 'COMPLETED'), [
      todoBid('b1', 'COMPLETED'),
    ]),
    TripTodoKind.publish => _s(todoTrip(status: 'DRAFT'), const []),
    TripTodoKind.addCard => _s(
      todoTrip(methods: const {BidPaymentMethod.cash}),
      const [],
      stripe: kTodoStripeReady,
    ),
  };
}

/// File « À traiter » de [s] à [kTodoNow].
List<TripTodoItem> todoOf(TodoScenario s) => tripTodoFor(
  trip: s.trip,
  bids: s.bids,
  isOwner: true,
  now: kTodoNow,
  departed: s.departed,
  stripe: s.stripe,
);

/// Scénarios de la maquette (« 3 · Prochaine action »).
Map<String, TodoScenario> todoMockupScenarios() {
  final now = kTodoNow;
  return {
    'calme': _s(todoTrip(), const []),
    '3 demandes + 2 présences': _s(todoTrip(), [
      for (var i = 1; i <= 3; i++)
        todoBid(
          'r$i',
          'PAYMENT_ESCROWED',
          paymentMethod: BidPaymentMethod.stripe,
        ),
      todoBid('a1', 'ACCEPTED'),
      todoBid('a2', 'ACCEPTED'),
    ]),
    'jour du départ': (
      trip: todoTrip(trackingActive: true, summary: kTodoSummary),
      bids: [
        todoBid(
          'a1',
          'ACCEPTED',
          voyageurConfirmed: true,
          handoverDeadline: now.add(const Duration(hours: 2)),
        ),
        todoBid(
          'a2',
          'ACCEPTED',
          voyageurConfirmed: true,
          handoverDeadline: now.add(const Duration(hours: 4)),
        ),
        todoBid('a3', 'ACCEPTED'),
        todoBid('h1', 'HANDED_OVER'),
      ],
      stripe: const StripeAccountInitial(),
      departed: false,
    ),
    'en route': _s(todoTrip(status: 'IN_PROGRESS'), [
      todoBid('t1', 'IN_TRANSIT'),
      todoBid('t2', 'IN_TRANSIT'),
    ]),
    'arrivé': _s(todoTrip(status: 'IN_PROGRESS'), [
      todoBid('d1', 'ARRIVED', departureDate: kTodoDeparted),
      todoBid('d2', 'ARRIVED', departureDate: kTodoDeparted),
      todoBid('c1', 'COMPLETED', departureDate: kTodoDeparted),
    ]),
    'très chargé': (
      trip: todoTrip(trackingActive: true, summary: kTodoSummary),
      bids: [
        for (var i = 1; i <= 8; i++)
          todoBid(
            'r$i',
            'PAYMENT_ESCROWED',
            paymentMethod: BidPaymentMethod.stripe,
          ),
        todoBid(
          's1',
          'ACCEPTED',
          voyageurConfirmed: true,
          handoverDeadline: now.add(const Duration(hours: 3)),
        ),
        todoBid('p1', 'ACCEPTED'),
        todoBid(
          'm1',
          'ACCEPTED',
          voyageurConfirmed: true,
          amendments: [
            BidAmendment(
              id: 'am-1',
              status: BidAmendmentStatus.proposed,
              grossAmount: 10,
              blocksHandover: true,
              expiresAt: now.add(const Duration(days: 1)),
            ),
          ],
        ),
        todoBid(
          'x1',
          'CANCELLED',
          returnDeadline: now.add(const Duration(days: 2)),
        ),
        todoBid('h1', 'HANDED_OVER'),
      ],
      stripe: const StripeAccountInitial(),
      departed: false,
    ),
  };
}
