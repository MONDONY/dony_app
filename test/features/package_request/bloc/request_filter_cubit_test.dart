import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

PackageRequest _req({
  String depart = 'Paris',
  String arrivee = 'Dakar',
  String catLabel = 'Vêtements & tissus',
  PackageRequestStatus status = PackageRequestStatus.open,
}) => PackageRequest(
  id: 'r_${arrivee}_${status.name}',
  senderId: 's1',
  departureCity: depart,
  arrivalCity: arrivee,
  desiredDate: DateTime(2026, 6, 8),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: [catLabel],
  status: status,
  createdAt: DateTime(2026, 5, 1),
);

void main() {
  group('requestMatchesQuery', () {
    test('vide -> tout', () => expect(requestMatchesQuery(_req(), ''), isTrue));
    test(
      'ville (accents)',
      () =>
          expect(requestMatchesQuery(_req(arrivee: 'Dákar'), 'dakar'), isTrue),
    );
    test(
      'catégorie',
      () => expect(
        requestMatchesQuery(
          _req(catLabel: 'Documents & administratif'),
          'doc',
        ),
        isTrue,
      ),
    );
    test('rien', () => expect(requestMatchesQuery(_req(), 'zzz'), isFalse));
  });

  group('isSearchRequest', () {
    test('open / negotiating / expired / cancelled = en recherche', () {
      expect(isSearchRequest(_req(status: PackageRequestStatus.open)), isTrue);
      expect(
        isSearchRequest(_req(status: PackageRequestStatus.negotiating)),
        isTrue,
      );
      expect(
        isSearchRequest(_req(status: PackageRequestStatus.expired)),
        isTrue,
      );
      expect(
        isSearchRequest(_req(status: PackageRequestStatus.cancelled)),
        isTrue,
      );
    });
    test('accepted / completed = parties dans Envois', () {
      expect(
        isSearchRequest(_req(status: PackageRequestStatus.accepted)),
        isFalse,
      );
      expect(
        isSearchRequest(_req(status: PackageRequestStatus.completed)),
        isFalse,
      );
    });
  });

  group('applyRequestFilters', () {
    final all = [
      _req(arrivee: 'Dakar', status: PackageRequestStatus.open),
      _req(arrivee: 'Lyon', status: PackageRequestStatus.negotiating),
      _req(arrivee: 'Abidjan', status: PackageRequestStatus.accepted),
      _req(arrivee: 'Douala', status: PackageRequestStatus.cancelled),
    ];
    test('exclut toujours les demandes acceptées (parties dans Envois)', () {
      final r = applyRequestFilters(all, const RequestFilterState());
      expect(r.map((e) => e.arrivalCity), isNot(contains('Abidjan')));
    });
    test('preset open = open + negotiating', () {
      final r = applyRequestFilters(
        all,
        const RequestFilterState(preset: RequestQuickFilter.open),
      );
      expect(r.map((e) => e.arrivalCity).toSet(), {'Dakar', 'Lyon'});
    });
    test('preset closed = expired + cancelled', () {
      final r = applyRequestFilters(
        all,
        const RequestFilterState(preset: RequestQuickFilter.closed),
      );
      expect(r.single.arrivalCity, 'Douala');
    });
    test('recherche + preset (ET)', () {
      final r = applyRequestFilters(
        all,
        const RequestFilterState(preset: RequestQuickFilter.all, query: 'lyon'),
      );
      expect(r.single.arrivalCity, 'Lyon');
    });
  });
}
