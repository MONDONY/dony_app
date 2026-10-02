import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/first_action_card.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

void main() {
  test('visible seulement si KYC vérifié et aucune première action', () {
    const notDone = ActivationLoaded(
      ActivationStatus(intent: UserIntent.sender, firstActionDone: false),
    );
    const done = ActivationLoaded(ActivationStatus(intent: UserIntent.sender));
    expect(shouldShowFirstActionCard(notDone, isKycVerified: true), isTrue);
    expect(shouldShowFirstActionCard(notDone, isKycVerified: false), isFalse);
    expect(shouldShowFirstActionCard(done, isKycVerified: true), isFalse);
    expect(
      shouldShowFirstActionCard(
        const ActivationUnavailable(),
        isKycVerified: true,
      ),
      isFalse,
    );
    expect(
      shouldShowFirstActionCard(const ActivationInitial(), isKycVerified: true),
      isFalse,
    );
  });

  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
  });

  Future<void> pump(WidgetTester tester, ActivationStatus status) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: FirstActionCard(analytics: analytics, status: status),
          ),
        ),
        GoRoute(
          path: firstStepsRoute,
          builder: (_, _) => const Scaffold(body: Text('Premiers pas')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tap : trace et ouvre les premiers pas', (tester) async {
    await pump(
      tester,
      const ActivationStatus(
        intent: UserIntent.traveler,
        destinationCountry: 'SN',
        firstActionDone: false,
        kind: OpportunityKind.packages,
        total: 2,
      ),
    );
    expect(
      find.textContaining('Des colis attendent un voyageur vers'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('first-action-card')));
    await tester.pumpAndSettle();
    expect(find.text('Premiers pas'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstActionCardTapped, {
        'variant': 'traveler_full',
      }),
    ).called(1);
  });

  testWidgets('messages selon l\'intention', (tester) async {
    await pump(tester, const ActivationStatus(firstActionDone: false));
    expect(
      find.text("Votre identité est vérifiée : passez à l'action"),
      findsOneWidget,
    );

    await pump(
      tester,
      const ActivationStatus(intent: UserIntent.sender, firstActionDone: false),
    );
    expect(find.text("Soyez prévenu dès qu'un voyageur part"), findsOneWidget);

    await pump(
      tester,
      const ActivationStatus(
        intent: UserIntent.both,
        destinationCountry: 'CI',
        firstActionDone: false,
        kind: OpportunityKind.trips,
        total: 1,
      ),
    );
    expect(find.textContaining('Des voyageurs partent vers'), findsOneWidget);

    await pump(
      tester,
      const ActivationStatus(
        intent: UserIntent.traveler,
        firstActionDone: false,
      ),
    );
    expect(find.text('Publiez votre premier trajet'), findsOneWidget);
  });
}
