import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/phone_verification_badge.dart';
import 'package:dony/core/phone/phone_verification_level.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Future<void> _loadFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/$file.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  }
}

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

    // Vraies polices : sans elles les glyphes carrés de 1 em fausseraient la
    // mesure (et un maxLines == 1 ne prouve rien, il est vrai par construction).
    for (final (locale, level, label) in [
      ('fr', PhoneVerificationLevel.yadony, 'Vérifié par Yadony'),
      ('fr', PhoneVerificationLevel.none, 'Non vérifié'),
      ('en', PhoneVerificationLevel.yadony, 'Verified by Yadony'),
      ('en', PhoneVerificationLevel.none, 'Not verified'),
    ]) {
      testWidgets(
        '$locale ${level.name} : libellé entier sur une ligne à 360 dp, sans coupe',
        (tester) async {
          await _loadFonts();
          if (locale == 'en') enableEnglish();
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: PhoneVerificationBadge(level),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final text = find.text(label);
          final rendered = tester.renderObject<RenderParagraph>(text);
          // Ellipsis = didExceedMaxLines ; une seconde ligne ferait grandir la boîte.
          expect(rendered.didExceedMaxLines, isFalse);
          final painter = TextPainter(
            text: rendered.text,
            textDirection: TextDirection.ltr,
          )..layout();
          expect(tester.getSize(text).width, closeTo(painter.width, 1));
          expect(tester.getSize(text).height, closeTo(painter.height, 1));
          expect(painter.width, lessThan(200), reason: 'police réelle chargée');
        },
      );
    }

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
