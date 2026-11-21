import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/presentation/widgets/profile_header.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _buildHeader({
  bool isTraveler = false,
  bool isSender = true,
  bool isKycVerified = false,
  bool isProAccount = false,
  bool gpPro = false,
  String? avatarUrl,
  String? phoneNumber,
  String? email,
  String? city,
  String? username,
  Locale locale = AppL10n.fr,
  String displayName = 'Ibrahima Diallo',
  double trailingInset = 0,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light(),
    home: Scaffold(
      body: ProfileHeader(
        displayName: displayName,
        isTraveler: isTraveler,
        isSender: isSender,
        isKycVerified: isKycVerified,
        isProAccount: isProAccount,
        gpPro: gpPro,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
        email: email,
        city: city,
        username: username,
        trailingInset: trailingInset,
        onTap: onTap,
      ),
    ),
  );
}

void main() {
  group('ProfileHeader', () {
    setUp(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
    tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
    testWidgets('trailingInset garde le nom et le badge à gauche des actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const inset = 80.0;
      await tester.pumpWidget(
        _buildHeader(
          displayName: 'aboubakar Siriki DIAKITE KONATÉ TRAORÉ',
          isKycVerified: true,
          isProAccount: true,
          trailingInset: inset,
        ),
      );
      await tester.pump();

      // Le badge est le dernier élément de la ligne : son bord droit borne
      // toute la ligne, et il doit rester dans la zone hors actions.
      final badgeRight = tester.getTopRight(find.text('PRO')).dx;
      expect(badgeRight, lessThanOrEqualTo(400 - inset - DonySpacing.lg));
    });

    testWidgets('shows display name', (tester) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Ibrahima Diallo'), findsOneWidget);
    });

    testWidgets(
      'pas de badge VÉRIFIÉ à côté du nom : la puce Identité suffit',
      (tester) async {
        await tester.pumpWidget(_buildHeader(isKycVerified: true));
        await tester.pump();
        expect(find.text('VÉRIFIÉ'), findsNothing);
        expect(find.text('PRO'), findsNothing);
      },
    );

    testWidgets('does NOT show VÉRIFIÉ badge when isKycVerified false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('VÉRIFIÉ'), findsNothing);
    });

    testWidgets('shows PRO badge when isProAccount and isKycVerified true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHeader(isKycVerified: true, isProAccount: true),
      );
      await tester.pump();
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('VÉRIFIÉ'), findsNothing);
    });

    testWidgets('shows city when provided', (tester) async {
      await tester.pumpWidget(_buildHeader(city: 'Paris'));
      await tester.pump();
      expect(find.text('Paris'), findsOneWidget);
    });

    testWidgets('does NOT show city when null', (tester) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Paris'), findsNothing);
    });

    testWidgets('shows phone chip with "Tél. ✓" when phoneNumber provided '
        'and SMS OTP confirmé par le backend', (tester) async {
      setSmsAuthEnabled(true);
      await tester.pumpWidget(_buildHeader(phoneNumber: '+33612345678'));
      await tester.pump();
      expect(find.text('Tél. ✓'), findsOneWidget);
    });

    testWidgets('shows "Tél. manquant" chip when phoneNumber absent '
        'et SMS OTP confirmé par le backend', (tester) async {
      setSmsAuthEnabled(true);
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Tél. manquant'), findsOneWidget);
    });

    testWidgets(
      'masque le chip téléphone (✓ ou manquant) tant que le SMS OTP backend '
      'n\'est pas confirmé, même avec un numéro',
      (tester) async {
        await tester.pumpWidget(_buildHeader(phoneNumber: '+33612345678'));
        await tester.pump();
        expect(find.text('Tél. ✓'), findsNothing);
        expect(find.text('Tél. manquant'), findsNothing);
      },
    );

    testWidgets('shows "Email ✓" chip when email provided', (tester) async {
      await tester.pumpWidget(_buildHeader(email: 'test@example.com'));
      await tester.pump();
      expect(find.text('Email ✓'), findsOneWidget);
    });

    testWidgets('shows "Email manquant" chip when email absent', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Email manquant'), findsOneWidget);
    });

    testWidgets('shows KYC chip when isKycVerified true', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: true));
      await tester.pump();
      expect(find.text('Identité ✓'), findsOneWidget);
    });

    testWidgets('does NOT show KYC chip when isKycVerified false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Identité ✓'), findsNothing);
    });

    // Pill switcher removed — additive model: no role pill in header.
    testWidgets(
      'does NOT show role pill switcher for dual-role user (additive model)',
      (tester) async {
        await tester.pumpWidget(_buildHeader(isTraveler: true));
        await tester.pump();
        // The _RolePill was deleted: neither "Voyageur" nor "Expéditeur" pill appears.
        expect(find.text('Voyageur'), findsNothing);
        expect(find.text('Expéditeur'), findsNothing);
      },
    );

    testWidgets('does NOT show pill switcher when user has only sender role', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Voyageur'), findsNothing);
    });

    testWidgets(
      'ne montre plus de barre de complétion (déplacée vers Modifier le profil)',
      (tester) async {
        await tester.pumpWidget(_buildHeader());
        await tester.pump();
        expect(find.text('Profil complet'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    // L'édition vit dans la feuille de menu du burger : le header ne porte
    // plus de crayon, et ne réclame plus de rappel d'édition.
    testWidgets('ne porte plus de bouton « Modifier le profil »', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'square-pen'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Modifier le profil'), findsNothing);
    });

    testWidgets('passes avatarUrl to DonyAvatar when non-null', (tester) async {
      const url = 'https://example.com/photo.jpg';
      await tester.pumpWidget(_buildHeader(avatarUrl: url));
      await tester.pump();
      final avatar = tester.widget<DonyAvatar>(find.byType(DonyAvatar));
      expect(avatar.imageUrl, equals(url));
    });

    testWidgets('DonyAvatar imageUrl is null when avatarUrl not provided', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      final avatar = tester.widget<DonyAvatar>(find.byType(DonyAvatar));
      expect(avatar.imageUrl, isNull);
    });

    testWidgets('chips en anglais', (tester) async {
      useEnglish();
      enableEnglish();
      setSmsAuthEnabled(true);
      await tester.pumpWidget(
        _buildHeader(
          locale: AppL10n.en,
          phoneNumber: '+33612345678',
          email: 'test@example.com',
          isKycVerified: true,
          isProAccount: true,
        ),
      );
      await tester.pump();

      expect(find.text('Phone ✓'), findsOneWidget);
      expect(find.text('Identity ✓'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
    });

    testWidgets('un tap sur l\'avatar ou le nom ouvre le profil (FLUTTER-9X)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_buildHeader(onTap: () => taps++));
      await tester.tap(find.text('Ibrahima Diallo'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('sans onTap, le header reste inerte', (tester) async {
      await tester.pumpWidget(_buildHeader());
      expect(find.byKey(const Key('profile-header-open')), findsNothing);
    });

    testWidgets('niveau de la coche : GP Pro et PRO transmis à l\'avatar', (
      tester,
    ) async {
      DonyAvatar avatar() => tester.widget<DonyAvatar>(find.byType(DonyAvatar));

      await tester.pumpWidget(_buildHeader(isKycVerified: true));
      expect(avatar().gpPro, isFalse);
      expect(avatar().pro, isFalse);

      await tester.pumpWidget(_buildHeader(isKycVerified: true, gpPro: true));
      expect(avatar().gpPro, isTrue);
      expect(avatar().pro, isFalse);

      await tester.pumpWidget(
        _buildHeader(isKycVerified: true, gpPro: true, isProAccount: true),
      );
      expect(avatar().pro, isTrue);
      expect(avatar().gpPro, isTrue);
    });

    testWidgets('pastille PRO : or plein, texte très foncé', (tester) async {
      await tester.pumpWidget(
        _buildHeader(isKycVerified: true, isProAccount: true),
      );
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text('PRO'), matching: find.byType(Container))
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, DonyColors.kycBadgeGold);
      final text = tester.widget<Text>(find.text('PRO'));
      expect(text.style?.color, const Color(0xFF2B1B00));
    });

    group('puce identifiant', () {
      final copied = <String>[];

      setUp(() {
        DonySnackbar.clearDedup();
        copied.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied.add((call.arguments as Map)['text'] as String);
              }
              return null;
            });
      });
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      Future<void> settle(WidgetTester tester) async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 400));
        }
      }

      testWidgets('affiche l identifiant', (tester) async {
        await tester.pumpWidget(_buildHeader(username: 'awa.diallo'));
        await settle(tester);
        expect(find.text('awa.diallo'), findsOneWidget);
        expect(find.byKey(const Key('profile-username-chip')), findsOneWidget);
      });

      testWidgets('absente quand l identifiant est vide ou nul', (
        tester,
      ) async {
        await tester.pumpWidget(_buildHeader(username: ''));
        await settle(tester);
        expect(find.byKey(const Key('profile-username-chip')), findsNothing);
        await tester.pumpWidget(_buildHeader());
        await settle(tester);
        expect(find.byKey(const Key('profile-username-chip')), findsNothing);
      });

      testWidgets(
        'un tap copie l identifiant et confirme, sans ouvrir le profil',
        (tester) async {
          var opened = 0;
          await tester.pumpWidget(
            _buildHeader(username: 'awa.diallo', onTap: () => opened++),
          );
          await settle(tester);
          await tester.tap(find.byKey(const Key('profile-username-chip')));
          await tester.pump();
          await settle(tester);
          expect(copied, ['awa.diallo']);
          expect(find.text('Identifiant copié'), findsOneWidget);
          expect(opened, 0);
        },
      );

      testWidgets('un tap sur l avatar appelle toujours onTap', (tester) async {
        var opened = 0;
        await tester.pumpWidget(
          _buildHeader(username: 'awa.diallo', onTap: () => opened++),
        );
        await settle(tester);
        await tester.tap(find.byKey(const Key('profile-header-open')));
        await tester.pump();
        expect(opened, 1);
        expect(copied, isEmpty);
      });

      for (final locale in [AppL10n.fr, AppL10n.en]) {
        testWidgets('360 dp ${locale.languageCode} : pas de débordement', (
          tester,
        ) async {
          if (locale == AppL10n.en) enableEnglish();
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _buildHeader(
              locale: locale,
              username: 'awa.diallo.tres.long',
              email: 'a@b.c',
              phoneNumber: '+221700000000',
              isKycVerified: true,
              trailingInset: 80,
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.text('awa.diallo.tres.long'), findsOneWidget);
        });
      }
    });
  });
}
