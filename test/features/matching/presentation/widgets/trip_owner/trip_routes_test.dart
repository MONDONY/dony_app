import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tripRequestsLocation compose la route filtrée', () {
    expect(
      tripRequestsLocation('11111111-2222-3333-4444-555555555555'),
      '/demandes?filter=aTraiter&announcement=11111111-2222-3333-4444-555555555555',
    );
  });
}
