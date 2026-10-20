import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonyVerifiedBadge.colorFor', () {
    test('bleu pour un compte vérifié seul', () {
      expect(
        DonyVerifiedBadge.colorFor(pro: false, gpPro: false),
        DonyColors.primary,
      );
    });

    test('argent pour un GP Pro', () {
      expect(
        DonyVerifiedBadge.colorFor(pro: false, gpPro: true),
        DonyColors.kycBadgeSilver,
      );
    });

    test('or pour un PRO', () {
      expect(
        DonyVerifiedBadge.colorFor(pro: true, gpPro: false),
        DonyColors.kycBadgeGold,
      );
    });

    test('or quand le compte est PRO et GP Pro', () {
      expect(
        DonyVerifiedBadge.colorFor(pro: true, gpPro: true),
        DonyColors.kycBadgeGold,
      );
    });
  });

  testWidgets('DonyAvatar : la coche prend la couleur du niveau', (
    tester,
  ) async {
    Future<Color> iconColor({bool pro = false, bool gpPro = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonyAvatar(
              name: 'Awa Diallo',
              verified: true,
              pro: pro,
              gpPro: gpPro,
            ),
          ),
        ),
      );
      // Deux icônes superposées : le contour blanc, puis la coche colorée.
      final icons = tester.widgetList<DonyIcon>(find.byType(DonyIcon)).toList();
      return icons.last.color!;
    }

    expect(await iconColor(), DonyColors.primary);
    expect(await iconColor(gpPro: true), DonyColors.kycBadgeSilver);
    expect(await iconColor(pro: true), DonyColors.kycBadgeGold);
    expect(await iconColor(pro: true, gpPro: true), DonyColors.kycBadgeGold);
  });

  testWidgets('DonyAvatar : pas de coche sans vérification', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DonyAvatar(name: 'Awa Diallo', gpPro: true)),
      ),
    );
    expect(find.byType(DonyVerifiedBadge), findsNothing);
  });
}
