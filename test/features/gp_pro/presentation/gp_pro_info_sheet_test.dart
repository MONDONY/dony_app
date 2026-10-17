import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_info_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';

void main() {
  final l = lookupAppLocalizations(AppL10n.fr);

  Widget host() => localizedApp(
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () =>
              unawaited(GpProInfoSheet.show(context, surface: 'chat')),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  );

  tearDown(() async => getIt.reset());

  testWidgets('loggue gp_pro_badge_tapped une fois avec la surface', (
    tester,
  ) async {
    final backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    getIt.registerSingleton<AnalyticsService>(analytics);

    await tester.pumpWidget(host());
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text(l.gpProInfoTitle), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.gpProBadgeTapped, {
        'surface': 'chat',
      }),
    ).called(1);
  });

  testWidgets('sans AnalyticsService enregistré, la feuille s\'ouvre', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text(l.gpProInfoBody), findsOneWidget);
  });
}
