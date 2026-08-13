import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/dispute_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

// Même helper que dispute_list_screen_test.dart (B4).
DisputeModel _dispute({
  String status = 'OPEN',
  bool refundFrozen = true,
  bool isBeneficiary = false,
  String myRole = 'SENDER',
}) => DisputeModel(
  id: 'd-$status',
  bidId: 'b1',
  type: 'SENDER_NO_SHOW_CONTESTED',
  status: status,
  refundFrozen: refundFrozen,
  createdAt: DateTime(2026, 7, 12),
  myRole: myRole,
  otherPartyName: 'Awa K.',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  departureCountryCode: 'FR',
  arrivalCountryCode: 'CI',
  tripDate: DateTime(2026, 6, 20),
  weightKg: 5,
  resolutionType: status == 'RESOLVED' ? 'GUARANTEE_PAID' : null,
  resolvedAt: status == 'RESOLVED' ? DateTime(2026, 6, 4) : null,
  resolutionNote: status == 'RESOLVED' ? 'No-show confirmé.' : null,
  guaranteeAmountCents: status == 'RESOLVED' ? 4000 : null,
  isBeneficiary: isBeneficiary,
);

Widget _harness(DisputeModel dispute) {
  final router = GoRouter(
    initialLocation: '/detail',
    routes: [
      GoRoute(
        path: '/detail',
        builder: (_, _) => DisputeDetailScreen(dispute: dispute),
      ),
      GoRoute(
        path: '/profile/help/contact',
        builder: (_, _) => const Scaffold(body: Text('SupportStub')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockAnalyticsService mockAnalytics;

  setUpAll(() => initializeDateFormatting('fr'));

  setUp(() {
    mockAnalytics = _MockAnalyticsService();
    when(
      () => mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => mockAnalytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  testWidgets(
    'détail résolu : décision, note admin, indemnisation si bénéficiaire',
    (tester) async {
      await tester.pumpWidget(
        _harness(_dispute(status: 'RESOLVED', isBeneficiary: true)),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Résolu en votre faveur'), findsOneWidget);
      expect(find.text('No-show confirmé.'), findsOneWidget);
      expect(find.textContaining('40,00 €'), findsOneWidget);
      expect(find.text('Décision rendue'), findsOneWidget);
    },
  );

  testWidgets(
    'détail résolu non bénéficiaire : pas de montant, verdict neutre',
    (tester) async {
      await tester.pumpWidget(_harness(_dispute(status: 'RESOLVED')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Litige résolu'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    },
  );

  testWidgets(
    'détail en cours : étape décision grisée « sous 72 h », bandeau gel',
    (tester) async {
      await tester.pumpWidget(_harness(_dispute()));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining('sous 72 h'), findsWidgets);
      expect(find.textContaining('Remboursement gelé'), findsOneWidget);
      expect(find.text('Décision rendue'), findsNothing);
    },
  );

  testWidgets(
    "timeline expéditeur : « vous avez contesté l'absence du voyageur »",
    (tester) async {
      await tester.pumpWidget(_harness(_dispute()));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.textContaining("vous avez contesté l'absence du voyageur"),
        findsOneWidget,
      );
      expect(find.textContaining('no-show'), findsNothing);
    },
  );

  testWidgets("timeline voyageur : « l'expéditeur a contesté une absence »", (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_dispute(myRole: 'TRAVELER')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.textContaining("l'expéditeur a contesté une absence à la remise"),
      findsOneWidget,
    );
    expect(find.textContaining('vous avez contesté'), findsNothing);
  });

  testWidgets('CTA Contacter le support → route contact', (tester) async {
    await tester.pumpWidget(_harness(_dispute()));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Contacter le support'));
    await tester.tap(find.text('Contacter le support'));
    await tester.pumpAndSettle();
    expect(find.text('SupportStub'), findsOneWidget);
  });

  testWidgets(
    '/disputes/detail ouvert sans extra → redirige vers /disputes sans crash',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/disputes/detail',
        routes: [
          GoRoute(
            path: '/disputes',
            builder: (_, _) => const Scaffold(body: Text('ListeStub')),
          ),
          GoRoute(
            path: '/disputes/detail',
            redirect: (context, state) =>
                state.extra is DisputeModel ? null : '/disputes',
            builder: (context, state) =>
                DisputeDetailScreen(dispute: state.extra! as DisputeModel),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ListeStub'), findsOneWidget);
    },
  );
}
