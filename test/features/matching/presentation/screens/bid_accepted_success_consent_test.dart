import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/presentation/screens/bid_accepted_success_screen.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/map_backed_box.dart';

class _MockLocator extends Mock implements ScanLocator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late int sheetShown;

  Future<void> open(WidgetTester tester, List<String> roles) async {
    sheetShown = 0;
    final locator = _MockLocator();
    when(() => locator.isPermissionGranted()).thenAnswer((_) async => true);
    when(() => locator.requestPermission()).thenAnswer((_) async => true);
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    final stored = <String, dynamic>{};
    getIt.registerSingleton<TrackingConsentCubit>(
      TrackingConsentCubit(
        box: () => mapBackedBox(stored),
        locator: locator,
        analytics: analytics,
        showSheet: (_) async {
          sheetShown++;
          return true;
        },
      )..updateRoles(roles),
    );
    addTearDown(() => getIt.unregister<TrackingConsentCubit>());
    await tester.pumpWidget(
      localizedApp(const BidAcceptedSuccessScreen(bidId: 'b-1')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('acceptedParcelTriggersConsentOnlyForTraveler: voyageur', (
    tester,
  ) async {
    await open(tester, ['TRAVELER']);
    expect(sheetShown, 1);
  });

  testWidgets('acceptedParcelTriggersConsentOnlyForTraveler: expéditeur', (
    tester,
  ) async {
    await open(tester, ['SENDER']);
    expect(sheetShown, 0);
  });
}
