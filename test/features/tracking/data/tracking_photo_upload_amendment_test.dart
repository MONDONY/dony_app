import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/tracking/data/tracking_photo_upload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('handover-amendment-pending', () {
    const error = ConflictException('d', code: 'handover-amendment-pending');

    test('est un refus « pour l\'instant » : l\'étape reste en file', () {
      expect(isRetryLaterTrackingRejection(error), isTrue);
    });

    test('n\'est pas un refus définitif', () {
      expect(isDefinitiveTrackingRejection(error), isFalse);
    });
  });
}
