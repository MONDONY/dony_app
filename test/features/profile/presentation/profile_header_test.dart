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
  int totalTrips = 0,
  int totalShipments = 0,
  bool isLoadingStats = false,
  bool isProAccount = false,
  VoidCallback? onNotificationTap,
  VoidCallback? onSettingsTap,
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
        totalTrips: totalTrips,
        totalShipments: totalShipments,
        isLoadingStats: isLoadingStats,
        onNotificationTap: onNotificationTap,
        onSettingsTap: onSettingsTap,
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

    testWidgets('shows KYC verified badge when isKycVerified true', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: true));
      await tester.pump();
      expect(find.text('Identité vérifiée'), findsOneWidget);
    });

    testWidgets('does NOT show KYC badge when isKycVerified false', (tester) async {
      await tester.pumpWidget(_buildHeader(isKycVerified: false));
      await tester.pump();
      expect(find.text('Identité vérifiée'), findsNothing);
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

    testWidgets('shows dash for stats when isLoadingStats true', (tester) async {
      await tester.pumpWidget(_buildHeader(isLoadingStats: true));
      await tester.pump();
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('shows trip count for traveler role', (tester) async {
      await tester.pumpWidget(_buildHeader(
        role: ActiveRole.traveler,
        totalTrips: 5,
      ));
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows shipment count for sender role', (tester) async {
      await tester.pumpWidget(_buildHeader(
        role: ActiveRole.sender,
        totalShipments: 7,
      ));
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('calls onNotificationTap when bell tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_buildHeader(onNotificationTap: () => tapped = true));
      await tester.pump();
      await tester.tap(find.byTooltip('Notifications'));
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

    testWidgets('settings icon absent when onSettingsTap is null', (tester) async {
      await tester.pumpWidget(_buildHeader());
      await tester.pump();
      expect(find.byTooltip('Paramètres'), findsNothing);
    });

    testWidgets('calls onSettingsTap when settings button tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_buildHeader(onSettingsTap: () => tapped = true));
      await tester.pump();
      await tester.tap(find.byTooltip('Paramètres'));
      expect(tapped, isTrue);
    });

    testWidgets('both notification and settings icons visible when both callbacks provided',
        (tester) async {
      await tester.pumpWidget(_buildHeader(
        onNotificationTap: () {},
        onSettingsTap: () {},
      ));
      await tester.pump();
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byTooltip('Paramètres'), findsOneWidget);
    });
  });
}
