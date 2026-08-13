import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_avatar.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/presentation/widgets/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHeader({
  bool isTraveler = false,
  bool isSender = true,
  bool isKycVerified = false,
  bool isProAccount = false,
  String? avatarUrl,
  String? phoneNumber,
  String? email,
  String? city,
  VoidCallback? onEditProfile,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: ProfileHeader(
        displayName: 'Ibrahima Diallo',
        isTraveler: isTraveler,
        isSender: isSender,
        isKycVerified: isKycVerified,
        isProAccount: isProAccount,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
        email: email,
        city: city,
        onEditProfile: onEditProfile,
      ),
    ),
  );
}

void main() {
  group('ProfileHeader', () {
    setUp(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
    tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
    testWidgets('shows display name', (tester) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Ibrahima Diallo'), findsOneWidget);
    });

    testWidgets('shows VÉRIFIÉ badge when isKycVerified true', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: true));
      await tester.pump();
      expect(find.text('VÉRIFIÉ'), findsOneWidget);
    });

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

    testWidgets('edit button calls onEditProfile when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_buildHeader(onEditProfile: () => tapped = true));
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'square-pen'),
      );
      expect(tapped, isTrue);
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
  });
}
