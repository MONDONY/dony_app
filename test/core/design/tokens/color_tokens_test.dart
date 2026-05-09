import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonyStatusColors brightness-aware', () {
    const lightCs = ColorScheme.light();
    const darkCs = ColorScheme.dark();

    test('success switches between light and dark variants', () {
      expect(lightCs.success, DonyColors.success500);
      expect(darkCs.success, DonyColors.successDark500);
    });

    test('warning switches between light and dark variants', () {
      expect(lightCs.warning, DonyColors.warning500);
      expect(darkCs.warning, DonyColors.warningDark500);
    });

    test('info switches between light and dark variants', () {
      expect(lightCs.info, DonyColors.info500);
      expect(darkCs.info, DonyColors.infoDark500);
    });

    test('successLight switches between light and dark variants', () {
      expect(lightCs.successLight, DonyColors.success50);
      expect(darkCs.successLight, DonyColors.successDark50);
    });

    test('warningLight switches between light and dark variants', () {
      expect(lightCs.warningLight, DonyColors.warning50);
      expect(darkCs.warningLight, DonyColors.warningDark50);
    });

    test('infoLight switches between light and dark variants', () {
      expect(lightCs.infoLight, DonyColors.info50);
      expect(darkCs.infoLight, DonyColors.infoDark50);
    });

    test('errorLight switches between light and dark variants', () {
      expect(lightCs.errorLight, DonyColors.danger50);
      expect(darkCs.errorLight, DonyColors.dangerDark50);
    });

    test('surfaceWarm switches between light and dark variants', () {
      expect(lightCs.surfaceWarm, DonyColors.sand100);
      expect(darkCs.surfaceWarm, DonyColors.sandDark100);
    });
  });
}
