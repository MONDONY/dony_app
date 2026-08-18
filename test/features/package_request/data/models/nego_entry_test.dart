import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/nego_entry.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter_test/flutter_test.dart';

NegotiationThread _thread({
  String id = 't1',
  String? traveler = 'Mamadou Diallo',
  String? arrivee = 'Dakar',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  bool isMyTurn = true,
  bool hasUnread = false,
  DateTime? lastActivityAt,
}) => NegotiationThread(
  id: id,
  packageRequestId: 'pr1',
  travelerId: 'tr1',
  travelerName: traveler,
  departureCity: 'Paris',
  arrivalCity: arrivee,
  status: status,
  currentPriceEur: 45,
  roundsCount: 1,
  lastActivityAt: lastActivityAt ?? DateTime(2026, 6, 10),
  createdAt: DateTime(2026, 6),
  travelerTravelDate: DateTime(2026, 7),
  travelerAvailableKg: 10,
  isMyTurn: isMyTurn,
  hasUnread: hasUnread,
  messages: const [],
);

BidNegotiationSummary _summary({
  String bidId = 'bid1',
  String status = 'NEGOTIATING',
  bool myTurn = false,
  bool hasUnread = true,
  String? counterparty = 'Awa Diop',
  String? arrivee = 'Abidjan',
  DateTime? updatedAt,
}) => BidNegotiationSummary(
  bidId: bidId,
  announcementId: 'ann1',
  status: status,
  round: 2,
  myTurn: myTurn,
  hasUnread: hasUnread,
  proposedGrossEur: 42,
  counterpartyName: counterparty,
  departureCity: 'Lyon',
  arrivalCity: arrivee,
  updatedAt: updatedAt ?? DateTime(2026, 6, 12),
);

void main() {
  group('NegoEntry.fromRequest', () {
    test('expose les champs communs d une negociation de demande', () {
      final entry = NegoEntry.fromRequest(_thread(hasUnread: true));

      expect(entry, isA<RequestNegoEntry>());
      expect(entry.isActive, isTrue);
      expect(entry.updatedAt, DateTime(2026, 6, 10));
      expect(entry.counterpartyName, 'Mamadou Diallo');
      expect(entry.departureCity, 'Paris');
      expect(entry.arrivalCity, 'Dakar');
    });

    test('un statut terminal n est plus actif', () {
      final entry = NegoEntry.fromRequest(
        _thread(status: NegotiationThreadStatus.rejected),
      );
      expect(entry.isActive, isFalse);
    });
  });

  group('NegoEntry.fromTrip', () {
    test('expose les champs communs d une negociation de trajet', () {
      final entry = NegoEntry.fromTrip(_summary());

      expect(entry, isA<TripNegoEntry>());
      expect(entry.isActive, isTrue);
      expect(entry.updatedAt, DateTime(2026, 6, 12));
      expect(entry.counterpartyName, 'Awa Diop');
      expect(entry.departureCity, 'Lyon');
      expect(entry.arrivalCity, 'Abidjan');
    });

    test('un fil clos n est plus actif', () {
      expect(
        NegoEntry.fromTrip(_summary(status: 'ACCEPTED')).isActive,
        isFalse,
      );
    });
  });

  group('applyNegotiationFilters sur une liste mixte', () {
    List<NegoEntry> mixed() => [
      NegoEntry.fromRequest(_thread(lastActivityAt: DateTime(2026, 6, 10))),
      NegoEntry.fromRequest(
        _thread(
          id: 't2',
          arrivee: 'Bamako',
          status: NegotiationThreadStatus.rejected,
          lastActivityAt: DateTime(2026, 6, 14),
        ),
      ),
      NegoEntry.fromTrip(_summary(updatedAt: DateTime(2026, 6, 12))),
      NegoEntry.fromTrip(
        _summary(
          bidId: 'bid2',
          status: 'REJECTED',
          arrivee: 'Douala',
          updatedAt: DateTime(2026, 6, 8),
        ),
      ),
    ];

    test('le filtre En cours ne garde que les actifs des deux sources', () {
      final result = applyNegotiationFilters(
        mixed(),
        const NegotiationFilterState(preset: NegoQuickFilter.active),
      );
      expect(result, hasLength(2));
      expect(result.whereType<RequestNegoEntry>(), hasLength(1));
      expect(result.whereType<TripNegoEntry>(), hasLength(1));
    });

    test('le filtre Terminees ne garde que les termines des deux sources', () {
      final result = applyNegotiationFilters(
        mixed(),
        const NegotiationFilterState(preset: NegoQuickFilter.terminal),
      );
      expect(result, hasLength(2));
      expect(result.map((e) => e.arrivalCity).toSet(), {'Bamako', 'Douala'});
    });

    test('la recherche texte porte sur les deux sources', () {
      final byTrip = applyNegotiationFilters(
        mixed(),
        const NegotiationFilterState(query: 'abidjan'),
      );
      expect(byTrip.single, isA<TripNegoEntry>());

      final byRequest = applyNegotiationFilters(
        mixed(),
        const NegotiationFilterState(query: 'mamadou'),
      );
      expect(byRequest, everyElement(isA<RequestNegoEntry>()));
    });

    test('la liste fusionnee est triee par updatedAt decroissant', () {
      final result = applyNegotiationFilters(
        mixed(),
        const NegotiationFilterState(),
      );
      final dates = result.map((e) => e.updatedAt).toList();
      expect(dates, [
        DateTime(2026, 6, 14),
        DateTime(2026, 6, 12),
        DateTime(2026, 6, 10),
        DateTime(2026, 6, 8),
      ]);
    });
  });
}
