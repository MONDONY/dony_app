import 'package:dony/core/design/widgets/phone_verification_badge.dart';
import 'package:dony/core/phone/phone_verification_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  group('PhoneVerificationBadge', () {
    const fr = {
      PhoneVerificationLevel.none: 'Non vérifié',
      PhoneVerificationLevel.yadony: 'Vérifié par Yadony',
      PhoneVerificationLevel.sms: 'Vérifié',
    };
    const en = {
      PhoneVerificationLevel.none: 'Not verified',
      PhoneVerificationLevel.yadony: 'Verified by Yadony',
      PhoneVerificationLevel.sms: 'Verified',
    };

    for (final level in PhoneVerificationLevel.values) {
      testWidgets('${level.name} : libellé français', (tester) async {
        await tester.pumpWidget(
          localizedApp(Scaffold(body: PhoneVerificationBadge(level))),
        );
        expect(find.text(fr[level]!), findsOneWidget);
      });

      testWidgets('${level.name} : libellé anglais', (tester) async {
        enableEnglish();
        await tester.pumpWidget(
          localizedApp(
            Scaffold(body: PhoneVerificationBadge(level)),
            locale: const Locale('en'),
          ),
        );
        expect(find.text(en[level]!), findsOneWidget);
      });
    }

    testWidgets('les trois pastilles ont des couleurs de fond distinctes', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Column(
              children: [
                for (final l in PhoneVerificationLevel.values)
                  PhoneVerificationBadge(l, key: ValueKey(l)),
              ],
            ),
          ),
        ),
      );
      final colors = <Color?>{};
      for (final l in PhoneVerificationLevel.values) {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(ValueKey(l)),
                matching: find.byType(Container),
              )
              .first,
        );
        colors.add((box.decoration! as BoxDecoration).color);
      }
      expect(colors, hasLength(3));
    });

    testWidgets('libellé sur une ligne à 360 dp, sans exception', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        localizedApp(
          const Scaffold(
            body: PhoneVerificationBadge(PhoneVerificationLevel.yadony),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('Vérifié par Yadony'));
      expect(text.maxLines, 1);
    });

    test('parse tolère l absence et les valeurs inconnues', () {
      expect(
        PhoneVerificationLevel.parseContact(null),
        PhoneVerificationLevel.sms,
      );
      expect(
        PhoneVerificationLevel.parseContact('SMS'),
        PhoneVerificationLevel.sms,
      );
      expect(
        PhoneVerificationLevel.parseContact('YADONY'),
        PhoneVerificationLevel.yadony,
      );
      expect(
        PhoneVerificationLevel.parseContact('NONE'),
        PhoneVerificationLevel.none,
      );
      expect(
        PhoneVerificationLevel.parseContact('???'),
        PhoneVerificationLevel.none,
      );
      expect(
        PhoneVerificationLevel.parseDeclared('DECLARED'),
        PhoneVerificationLevel.none,
      );
      expect(
        PhoneVerificationLevel.parseDeclared('YADONY_VERIFIED'),
        PhoneVerificationLevel.yadony,
      );
      expect(PhoneVerificationLevel.parseDeclared(null), isNull);
    });
  });
}
