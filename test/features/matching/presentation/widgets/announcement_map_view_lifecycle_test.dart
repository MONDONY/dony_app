import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldRecreateNativeMap (FLUTTER-BK)', () {
    test('une pause brève (permission, notification) garde la carte', () {
      expect(shouldRecreateNativeMap(Duration.zero), isFalse);
      expect(shouldRecreateNativeMap(const Duration(seconds: 2)), isFalse);
    });

    test('une vraie pause recrée la vue native de la carte', () {
      expect(shouldRecreateNativeMap(kMapRecreateAfterPause), isTrue);
      expect(shouldRecreateNativeMap(const Duration(minutes: 10)), isTrue);
    });
  });
}
