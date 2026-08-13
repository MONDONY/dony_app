import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/sender_public_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SenderPublicProfile _sender({
  bool kycVerified = true,
  double averageRating = 4.8,
  int totalRatings = 12,
}) => SenderPublicProfile(
  id: 'sender-1',
  displayName: 'Fatou Diallo',
  averageRating: averageRating,
  totalRatings: totalRatings,
  kycVerified: kycVerified,
);

Widget _buildApp(SenderPublicProfile sender) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Builder(
      builder: (ctx) => ElevatedButton(
        key: const Key('open'),
        onPressed: () => showSenderPublicProfileSheet(ctx, sender),
        child: const Text('Ouvrir'),
      ),
    ),
  ),
);

void main() {
  group('SenderPublicProfileSheet', () {
    testWidgets('shows "Profil expéditeur" title', (tester) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Profil expéditeur'), findsOneWidget);
    });

    testWidgets('shows sender display name', (tester) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Fatou Diallo'), findsWidgets);
    });

    testWidgets('shows "Identité vérifiée" when kycVerified=true', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Identité vérifiée'), findsOneWidget);
    });

    testWidgets('hides "Identité vérifiée" when kycVerified=false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender(kycVerified: false)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Identité vérifiée'), findsNothing);
    });

    testWidgets('shows average rating and review count when totalRatings > 0', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('· 12 avis'), findsOneWidget);
    });

    testWidgets('shows "Nouveau membre" when totalRatings = 0', (tester) async {
      await tester.pumpWidget(_buildApp(_sender(totalRatings: 0)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau membre'), findsOneWidget);
    });
  });
}
