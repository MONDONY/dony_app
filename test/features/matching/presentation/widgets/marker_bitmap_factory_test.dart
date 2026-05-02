import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarkerBitmapFactory', () {
    test('luggagePickup returns non-null BitmapDescriptor', () async {
      final desc = await MarkerBitmapFactory.luggagePickup();
      expect(desc, isA<BitmapDescriptor>());
    });

    test('luggageDelivery returns non-null BitmapDescriptor', () async {
      final desc = await MarkerBitmapFactory.luggageDelivery();
      expect(desc, isA<BitmapDescriptor>());
    });

    test('clusterBadge returns non-null BitmapDescriptor for count=3', () async {
      final desc = await MarkerBitmapFactory.clusterBadge(3);
      expect(desc, isA<BitmapDescriptor>());
    });

    test('clusterBadge handles big counts (99+)', () async {
      final desc = await MarkerBitmapFactory.clusterBadge(150);
      expect(desc, isA<BitmapDescriptor>());
    });
  });
}
