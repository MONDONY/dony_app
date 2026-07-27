import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/presentation/widgets/reimbursement_info_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalyticsService analytics;

  setUp(() {
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => setDonyReimbursementCap(kDonyReimbursementCapDefault));

  testWidgets('shows configured reimbursement cap and conditions link', (
    tester,
  ) async {
    setDonyReimbursementCap(50);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReimbursementInfoBanner())),
    );

    expect(find.textContaining('50'), findsWidgets);
    expect(find.textContaining('rembourse'), findsOneWidget);
    expect(find.text('Voir conditions'), findsOneWidget);
  });

  testWidgets('reflects a cap changed after the banner is mounted', (
    tester,
  ) async {
    setDonyReimbursementCap(50);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReimbursementInfoBanner(analytics: analytics)),
      ),
    );

    expect(find.textContaining('50'), findsOneWidget);

    setDonyReimbursementCap(75);
    await tester.pump();

    expect(find.textContaining('75'), findsWidgets);
    expect(find.textContaining('50'), findsNothing);
  });

  testWidgets('onSeeConditions override is invoked on tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReimbursementInfoBanner(
            analytics: analytics,
            onSeeConditions: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Voir conditions'));
    expect(tapped, isTrue);
  });

  testWidgets('conditions action meets the 44-point touch target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReimbursementInfoBanner(analytics: analytics)),
      ),
    );

    final size = tester.getSize(
      find.widgetWithText(TextButton, 'Voir conditions'),
    );
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('conditions action logs the analytics event', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReimbursementInfoBanner(
            analytics: analytics,
            onSeeConditions: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Voir conditions'));
    await tester.pump();

    verify(
      () => analytics.logEvent(AnalyticsEvents.reimbursementConditionsOpened),
    ).called(1);
  });
}
