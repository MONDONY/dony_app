import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:flutter_test/flutter_test.dart';

PackageRequest req(
  PackageRequestStatus status, {
  bool negotiable = true,
}) =>
    PackageRequest(
      id: 'pr-1',
      senderId: 'sender-1',
      departureCity: 'Divo',
      arrivalCity: 'Annemasse',
      desiredDate: DateTime(2026, 9, 27),
      dateToleranceDays: 2,
      weightKg: 2,
      parcelSize: ParcelSize.small,
      transportMode: TransportMode.plane,
      status: status,
      createdAt: DateTime.utc(2026, 9, 17, 6, 25),
      negotiable: negotiable,
    );

NegotiationThread thread(
  NegotiationThreadStatus status, {
  String id = 't-1',
  String? bidId,
}) =>
    NegotiationThread(
      id: id,
      packageRequestId: 'pr-1',
      travelerId: 'trav-$id',
      travelerTravelDate: DateTime(2026, 9, 26),
      travelerAvailableKg: 8,
      status: status,
      currentPriceEur: 25,
      roundsCount: 1,
      lastActivityAt: DateTime(2026, 9, 17),
      createdAt: DateTime(2026, 9, 17),
      messages: const [],
      materializedBidId: bidId,
    );

AnnouncementModel trip(String id) =>
    AnnouncementModel(
      id: id,
      travelerId: 'trav-$id',
      departureCity: 'Divo',
      arrivalCity: 'Annemasse',
      departureDate: DateTime(2026, 9, 26),
      availableKg: 8,
      totalKg: 10,
      pricePerKg: 7,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9),
    );

BidModel bid(String status) =>
    BidModel(
      id: 'bid-1',
      announcementId: 'a',
      senderId: 'sender-1',
      weightKg: 2,
      status: status,
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9),
    );

void main() {
  RequestScreenCase resolve(
    PackageRequest r, [
    List<NegotiationThread> t = const [],
  ]) =>
      resolveRequestScreenCase(request: r, threads: t);

  group('resolveRequestScreenCase', () {
    test('annulée localement prime sur le statut', () {
      expect(
        resolveRequestScreenCase(
          request: req(PackageRequestStatus.open),
          threads: const [],
          cancelledLocally: true,
        ),
        RequestScreenCase.cancelled,
      );
    });
    test('statuts simples', () {
      expect(resolve(req(PackageRequestStatus.draft)), RequestScreenCase.draft);
      expect(resolve(req(PackageRequestStatus.expired)), RequestScreenCase.expired);
      expect(resolve(req(PackageRequestStatus.cancelled)), RequestScreenCase.cancelled);
      expect(resolve(req(PackageRequestStatus.completed)), RequestScreenCase.delivered);
    });
    test('acceptée : livrée seulement si le bid est COMPLETED', () {
      expect(
        resolveRequestScreenCase(
          request: req(PackageRequestStatus.accepted),
          threads: const [],
          materializedBid: bid('IN_TRANSIT'),
        ),
        RequestScreenCase.accepted,
      );
      expect(
        resolveRequestScreenCase(
          request: req(PackageRequestStatus.accepted),
          threads: const [],
          materializedBid: bid('COMPLETED'),
        ),
        RequestScreenCase.delivered,
      );
      expect(resolve(req(PackageRequestStatus.accepted)), RequestScreenCase.accepted);
    });
    test('fil choisi prime sur tout le reste', () {
      for (final s in [
        NegotiationThreadStatus.awaitingTrip,
        NegotiationThreadStatus.awaitingPayment,
        NegotiationThreadStatus.awaitingDeposit
      ]) {
        expect(
          resolve(
            req(PackageRequestStatus.negotiating),
            [
              thread(NegotiationThreadStatus.open, id: 'a'),
              thread(s, id: 'b')
            ],
          ),
          RequestScreenCase.toFinalize,
        );
      }
    });
    test('commission espèces en attente', () {
      expect(
        resolve(
          req(PackageRequestStatus.negotiating),
          [thread(NegotiationThreadStatus.awaitingCommission)],
        ),
        RequestScreenCase.cashCommissionPending,
      );
    });
    test('offres reçues selon négociable ou prix ferme', () {
      expect(
        resolve(
          req(PackageRequestStatus.negotiating),
          [thread(NegotiationThreadStatus.open)],
        ),
        RequestScreenCase.offersReceived,
      );
      expect(
        resolve(
          req(PackageRequestStatus.open, negotiable: false),
          [thread(NegotiationThreadStatus.open)],
        ),
        RequestScreenCase.firmCandidates,
      );
    });
    test('fils terminés ignorés', () {
      expect(
        resolveRequestScreenCase(
          request: req(PackageRequestStatus.open),
          threads: [thread(NegotiationThreadStatus.rejected)],
          compatibleTrips: [trip('x')],
        ),
        RequestScreenCase.noOffers,
      );
    });
    test('personne sur l axe seulement si la liste est chargée et vide', () {
      expect(
        resolveRequestScreenCase(
          request: req(PackageRequestStatus.open),
          threads: const [],
          compatibleTrips: const [],
        ),
        RequestScreenCase.noTravelers,
      );
      expect(resolve(req(PackageRequestStatus.open)), RequestScreenCase.noOffers);
    });
  });

  group('requestActionsFor', () {
    RequestScreenActions actions(
      RequestScreenCase c,
      PackageRequest r, [
      List<NegotiationThread> t = const [],
    ]) =>
        requestActionsFor(c, request: r, threads: t);

    test('brouillon : Modifier + Publier, menu Dupliquer', () {
      final a = actions(RequestScreenCase.draft, req(PackageRequestStatus.draft));
      expect(a.primary, RequestPrimaryAction.publish);
      expect(a.showEdit, isTrue);
      expect(a.menu, [RequestMenuAction.duplicate]);
    });
    test('publiée sans aucun fil : Dépublier proposé', () {
      final a = actions(RequestScreenCase.noOffers, req(PackageRequestStatus.open));
      expect(a.primary, RequestPrimaryAction.share);
      expect(
        a.menu,
        [
          RequestMenuAction.unpublish,
          RequestMenuAction.duplicate,
          RequestMenuAction.cancel
        ],
      );
    });
    test('publiée avec un fil terminé : plus de Dépublier (409 has-offers)', () {
      final a = actions(
        RequestScreenCase.noOffers,
        req(PackageRequestStatus.open),
        [thread(NegotiationThreadStatus.rejected)],
      );
      expect(a.menu, [RequestMenuAction.duplicate, RequestMenuAction.cancel]);
    });
    test('à finaliser : Payer, ou attente du trajet', () {
      expect(
        actions(
          RequestScreenCase.toFinalize,
          req(PackageRequestStatus.negotiating),
          [thread(NegotiationThreadStatus.awaitingPayment)],
        ).primary,
        RequestPrimaryAction.pay,
      );
      expect(
        actions(
          RequestScreenCase.toFinalize,
          req(PackageRequestStatus.negotiating),
          [thread(NegotiationThreadStatus.awaitingTrip)],
        ).primary,
        RequestPrimaryAction.waitTrip,
      );
    });
    test('états avancés', () {
      expect(
        actions(
          RequestScreenCase.cashCommissionPending,
          req(PackageRequestStatus.negotiating),
        ).primary,
        RequestPrimaryAction.openThread,
      );
      final accepted =
          actions(RequestScreenCase.accepted, req(PackageRequestStatus.accepted));
      expect(accepted.primary, RequestPrimaryAction.trackParcel);
      expect(accepted.showMessage, isTrue);
      expect(accepted.showEdit, isFalse);
      expect(
        actions(RequestScreenCase.delivered, req(PackageRequestStatus.accepted))
            .primary,
        RequestPrimaryAction.rate,
      );
      final expired = actions(RequestScreenCase.expired, req(PackageRequestStatus.expired));
      expect(expired.primary, RequestPrimaryAction.republish);
      expect(expired.menu, isEmpty);
      expect(
        actions(RequestScreenCase.cancelled, req(PackageRequestStatus.open)).primary,
        RequestPrimaryAction.publishSimilar,
      );
    });

    test('livrée déjà notée : plus de Noter, demande similaire à la place', () {
      final notRated = requestActionsFor(
        RequestScreenCase.delivered,
        request: req(PackageRequestStatus.accepted),
        threads: const [],
        materializedBid: bid('COMPLETED'),
      );
      expect(notRated.primary, RequestPrimaryAction.rate);

      final rated = requestActionsFor(
        RequestScreenCase.delivered,
        request: req(PackageRequestStatus.accepted),
        threads: const [],
        materializedBid: BidModel(
          id: 'bid-1', announcementId: 'a', senderId: 'sender-1', weightKg: 2,
          status: 'COMPLETED', senderHasRated: true,
          createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9),
        ),
      );
      expect(rated.primary, RequestPrimaryAction.publishSimilar);
      expect(rated.menu, [RequestMenuAction.duplicate]);
    });

    test('acceptée : bid annulé/no-show/refusé → demande similaire au lieu de suivre', () {
      for (final status in ['CANCELLED', 'NO_SHOW', 'PARCEL_REFUSED', 'REJECTED', 'EXPIRED']) {
        final a = requestActionsFor(
          RequestScreenCase.accepted,
          request: req(PackageRequestStatus.accepted),
          threads: const [],
          materializedBid: bid(status),
        );
        expect(a.primary, RequestPrimaryAction.publishSimilar, reason: status);
      }
      final onTrack = requestActionsFor(
        RequestScreenCase.accepted,
        request: req(PackageRequestStatus.accepted),
        threads: const [],
        materializedBid: bid('HANDED_OVER'),
      );
      expect(onTrack.primary, RequestPrimaryAction.trackParcel);
      expect(onTrack.showMessage, isTrue);
    });
  });

  test('focusThreadFor', () {
    final chosen = thread(NegotiationThreadStatus.awaitingPayment, id: 'c');
    final threads = [thread(NegotiationThreadStatus.open, id: 'o'), chosen];
    expect(focusThreadFor(RequestScreenCase.toFinalize, threads), chosen);
    final accepted = thread(NegotiationThreadStatus.accepted, id: 'acc', bidId: 'bid-1');
    expect(focusThreadFor(RequestScreenCase.accepted, [accepted]), accepted);
    expect(focusThreadFor(RequestScreenCase.noOffers, threads), isNull);
  });
}
