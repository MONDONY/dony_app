import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/profile/presentation/widgets/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHeader({
  bool isTraveler = false,
  bool isSender = true,
  bool isKycVerified = false,
  bool isProAccount = false,
  String? phoneNumber,
  String? email,
  String? city,
  double profileCompletionPercent = 0.0,
  VoidCallback? onEditProfile,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ProfileHeader(
        displayName: 'Ibrahima Diallo',
        isTraveler: isTraveler,
        isSender: isSender,
        isKycVerified: isKycVerified,
        isProAccount: isProAccount,
        phoneNumber: phoneNumber,
        email: email,
        city: city,
        profileCompletionPercent: profileCompletionPercent,
        onEditProfile: onEditProfile,
      ),
    ),
  );
}

void main() {
  group('ProfileHeader', () {
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
      await tester.pumpWidget(_buildHeader(isKycVerified: false));
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

    testWidgets('shows phone chip with "Tél. ✓" when phoneNumber provided', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader(phoneNumber: '+33612345678'));
      await tester.pump();
      expect(find.text('Tél. ✓'), findsOneWidget);
    });

    testWidgets('shows "Tél. manquant" chip when phoneNumber absent', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Tél. manquant'), findsOneWidget);
    });

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
      expect(find.text('KYC ✓'), findsOneWidget);
    });

    testWidgets('does NOT show KYC chip when isKycVerified false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: false));
      await tester.pump();
      expect(find.text('KYC ✓'), findsNothing);
    });

    // Pill switcher removed — additive model: no role pill in header.
    testWidgets(
      'does NOT show role pill switcher for dual-role user (additive model)',
      (tester) async {
        await tester.pumpWidget(_buildHeader(isTraveler: true, isSender: true));
        await tester.pump();
        // The _RolePill was deleted: neither "Voyageur" nor "Expéditeur" pill appears.
        expect(find.text('Voyageur'), findsNothing);
        expect(find.text('Expéditeur'), findsNothing);
      },
    );

    testWidgets('does NOT show pill switcher when user has only sender role', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader(isTraveler: false, isSender: true));
      await tester.pump();
      expect(find.text('Voyageur'), findsNothing);
    });

    testWidgets('shows profile completion percentage', (tester) async {
      await tester.pumpWidget(_buildHeader(profileCompletionPercent: 0.5));
      await tester.pump();
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('hides completion bar when profile is complete', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeader(profileCompletionPercent: 1.0));
      await tester.pump();
      // À 100%, la barre de complétion est volontairement masquée
      // (ProfileHeader : `if (profileCompletionPercent < 1.0)`).
      expect(find.text('100% ✓'), findsNothing);
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('edit button calls onEditProfile when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_buildHeader(onEditProfile: () => tapped = true));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.edit_rounded));
      expect(tapped, isTrue);
    });
  });
}
