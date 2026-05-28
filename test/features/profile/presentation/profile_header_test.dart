import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/profile/presentation/widgets/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHeader({
  ActiveRole role = ActiveRole.sender,
  bool isTraveler = false,
  bool isSender = true,
  bool isKycVerified = false,
  bool isProAccount = false,
  String? phoneNumber,
  String? email,
  String? city,
  double profileCompletionPercent = 0.0,
  VoidCallback? onEditProfile,
  ValueChanged<ActiveRole>? onRoleSwitch,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ProfileHeader(
        displayName: 'Ibrahima Diallo',
        activeRole: role,
        isTraveler: isTraveler,
        isSender: isSender,
        isKycVerified: isKycVerified,
        isProAccount: isProAccount,
        phoneNumber: phoneNumber,
        email: email,
        city: city,
        profileCompletionPercent: profileCompletionPercent,
        onEditProfile: onEditProfile,
        onRoleSwitch: onRoleSwitch,
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

    testWidgets('does NOT show VÉRIFIÉ badge when isKycVerified false', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: false));
      await tester.pump();
      expect(find.text('VÉRIFIÉ'), findsNothing);
    });

    testWidgets('shows PRO badge when isProAccount and isKycVerified true', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: true, isProAccount: true));
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

    testWidgets('shows phone chip with "Tél. ✓" when phoneNumber provided', (tester) async {
      await tester.pumpWidget(_buildHeader(phoneNumber: '+33612345678'));
      await tester.pump();
      expect(find.text('Tél. ✓'), findsOneWidget);
    });

    testWidgets('shows "Tél. manquant" chip when phoneNumber absent', (tester) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Tél. manquant'), findsOneWidget);
    });

    testWidgets('shows "Email ✓" chip when email provided', (tester) async {
      await tester.pumpWidget(_buildHeader(email: 'test@example.com'));
      await tester.pump();
      expect(find.text('Email ✓'), findsOneWidget);
    });

    testWidgets('shows "Email manquant" chip when email absent', (tester) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.text('Email manquant'), findsOneWidget);
    });

    testWidgets('shows KYC chip when isKycVerified true', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: true));
      await tester.pump();
      expect(find.text('KYC ✓'), findsOneWidget);
    });

    testWidgets('does NOT show KYC chip when isKycVerified false', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: false));
      await tester.pump();
      expect(find.text('KYC ✓'), findsNothing);
    });

    testWidgets('shows pill switcher when user has both roles', (tester) async {
      await tester.pumpWidget(_buildHeader(isTraveler: true, isSender: true));
      await tester.pump();
      expect(find.text('Voyageur'), findsOneWidget);
      expect(find.text('Expéditeur'), findsOneWidget);
    });

    testWidgets('does NOT show pill switcher when user has only sender role', (tester) async {
      await tester.pumpWidget(_buildHeader(isTraveler: false, isSender: true));
      await tester.pump();
      expect(find.text('Voyageur'), findsNothing);
    });

    testWidgets('shows profile completion percentage', (tester) async {
      await tester.pumpWidget(_buildHeader(profileCompletionPercent: 0.5));
      await tester.pump();
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('hides completion bar when profile is complete', (tester) async {
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

    testWidgets('calls onRoleSwitch with traveler when Voyageur tab tapped', (tester) async {
      ActiveRole? switched;
      await tester.pumpWidget(_buildHeader(
        isTraveler: true,
        isSender: true,
        role: ActiveRole.sender,
        onRoleSwitch: (r) => switched = r,
      ));
      await tester.pump();
      await tester.tap(find.text('Voyageur'));
      expect(switched, equals(ActiveRole.traveler));
    });

    testWidgets('calls onRoleSwitch with sender when Expéditeur tab tapped', (tester) async {
      ActiveRole? switched;
      await tester.pumpWidget(_buildHeader(
        isTraveler: true,
        isSender: true,
        role: ActiveRole.traveler,
        onRoleSwitch: (r) => switched = r,
      ));
      await tester.pump();
      await tester.tap(find.text('Expéditeur'));
      expect(switched, equals(ActiveRole.sender));
    });
  });
}
