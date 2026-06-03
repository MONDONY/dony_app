import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

PackageRequest _req({
  String depart = 'Paris',
  String arrivee = 'Dakar',
  ContentCategory cat = ContentCategory.vetements,
  PackageRequestStatus status = PackageRequestStatus.open,
}) =>
    PackageRequest(
      id: 'r_${arrivee}_${status.name}',
      senderId: 's1',
      departureCity: depart,
      arrivalCity: arrivee,
      desiredDate: DateTime(2026, 6, 8),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      contentCategory: cat,
      status: status,
      createdAt: DateTime(2026, 5, 1),
    );

void main() {
  group('requestMatchesQuery', () {
    test('vide -> tout', () => expect(requestMatchesQuery(_req(), ''), isTrue));
    test('ville (accents)', () => expect(requestMatchesQuery(_req(arrivee: 'Dákar'), 'dakar'), isTrue));
    test('catégorie', () => expect(requestMatchesQuery(_req(cat: ContentCategory.documents), 'doc'), isTrue));
    test('rien', () => expect(requestMatchesQuery(_req(), 'zzz'), isFalse));
  });

  group('applyRequestFilters', () {
    final all = [
      _req(arrivee: 'Dakar', status: PackageRequestStatus.open),
      _req(arrivee: 'Abidjan', status: PackageRequestStatus.accepted),
    ];
    test('preset open exclut accepted', () {
      final r = applyRequestFilters(all, const RequestFilterState(preset: RequestQuickFilter.open));
      expect(r.single.arrivalCity, 'Dakar');
    });
    test('preset accepted', () {
      final r = applyRequestFilters(all, const RequestFilterState(preset: RequestQuickFilter.accepted));
      expect(r.single.arrivalCity, 'Abidjan');
    });
    test('recherche + preset (ET)', () {
      final r = applyRequestFilters(all,
          const RequestFilterState(preset: RequestQuickFilter.all, query: 'abidjan'));
      expect(r.single.arrivalCity, 'Abidjan');
    });
  });
}
