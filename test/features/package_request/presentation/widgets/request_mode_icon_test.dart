import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/presentation/widgets/request_mode_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  group('requestModeIconAsset', () {
    test('peu importe : icône neutre route', () {
      expect(requestModeIconAsset(null), 'route');
    });

    test('un icône par mode, le bus comme la route', () {
      expect(requestModeIconAsset(TransportMode.plane), 'plane');
      expect(requestModeIconAsset(TransportMode.boat), 'ship');
      expect(requestModeIconAsset(TransportMode.car), 'car');
      expect(requestModeIconAsset(TransportMode.bus), 'car');
    });
  });

  group('requestModeLabel', () {
    test('français', () {
      final l = AppL10n.current;
      expect(requestModeLabel(l, null), 'Peu importe');
      expect(requestModeLabel(l, TransportMode.car), 'Route');
      expect(requestModeLabel(l, TransportMode.bus), 'Route');
      expect(requestModeLabel(l, TransportMode.boat), 'Bateau');
      expect(requestModeLabel(l, TransportMode.plane), 'Avion');
    });

    test('anglais', () {
      useEnglish();
      final l = AppL10n.current;
      expect(requestModeLabel(l, null), 'Any');
      expect(requestModeLabel(l, TransportMode.car), 'Road');
    });
  });
}
