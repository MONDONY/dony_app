import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/announcement_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Fixture builder ───────────────────────────────────────────────────────────

AnnouncementModel _makeAnnouncement({
  DateTime? handoverDeadline,
  String status = 'ACTIVE',
  int bidsCount = 0,
  String currency = 'EUR',
}) => AnnouncementModel(
  id: 'ann-detail-001',
  travelerId: 'trav-001',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 7),
  availableKg: 10,
  totalKg: 23,
  pricePerKg: 8,
  status: status,
  bidsCount: bidsCount,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
  handoverDeadline: handoverDeadline,
  currency: currency,
);

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  required AnnouncementModel announcement,
  required _MockAnnouncementBloc annBloc,
  required _MockCancellationBloc cancelBloc,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(announcement));
  whenListen(
    annBloc,
    Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
    initialState: AnnouncementDetailLoaded(announcement),
  );
  when(() => cancelBloc.state).thenReturn(CancellationInitial());
  whenListen(
    cancelBloc,
    const Stream<CancellationState>.empty(),
    initialState: CancellationInitial(),
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: annBloc),
            BlocProvider<CancellationBloc>.value(value: cancelBloc),
          ],
          child: const AnnouncementDetailScreen(id: 'ann-detail-001'),
        ),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, _) => const Scaffold(body: Text('announcements')),
      ),
      GoRoute(
        path: '/announcements/:id/bids',
        builder: (_, _) => const Scaffold(body: Text('bids')),
      ),
      GoRoute(
        path: '/announcements/:id/edit',
        builder: (_, _) => const Scaffold(body: Text('edit')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockAnnouncementBloc annBloc;
  late _MockCancellationBloc cancelBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    cancelBloc = _MockCancellationBloc();
    analytics = _MockAnalyticsService();

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<CancellationBloc>()) {
      getIt.unregister<CancellationBloc>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerFactory<CancellationBloc>(() => cancelBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<CancellationBloc>()) {
      getIt.unregister<CancellationBloc>();
    }
    annBloc.close();
    cancelBloc.close();
  });

  // ── Fenêtre de remise — présente ──────────────────────────────────────────

  testWidgets('affiche la date limite de dépôt si présente', (tester) async {
    final announcement = _makeAnnouncement(
      handoverDeadline: DateTime(2026, 6, 14, 18),
    );

    await _pump(
      tester,
      announcement: announcement,
      annBloc: annBloc,
      cancelBloc: cancelBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Dépôt des colis'), findsOneWidget);
    // L'écran porte déjà d'autres icônes calendrier (date de départ) : on
    // vérifie seulement que la section en affiche une.
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'calendar'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('affiche le prix dans la devise du trajet, pas toujours en EUR', (
    tester,
  ) async {
    final announcement = _makeAnnouncement(currency: 'CAD');

    await _pump(
      tester,
      announcement: announcement,
      annBloc: annBloc,
      cancelBloc: cancelBloc,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('CA\$'), findsOneWidget);
    expect(find.textContaining('8 €/kg'), findsNothing);
  });

  testWidgets('masque la fenêtre si absente (annonce legacy)', (tester) async {
    final announcement = _makeAnnouncement();

    await _pump(
      tester,
      announcement: announcement,
      annBloc: annBloc,
      cancelBloc: cancelBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Fenêtre de remise'), findsNothing);
  });

  testWidgets('masque la fenêtre si seulement windowStart est présent', (
    tester,
  ) async {
    final announcement = _makeAnnouncement(
      handoverDeadline: DateTime(2026, 6, 14, 16),
    );

    await _pump(
      tester,
      announcement: announcement,
      annBloc: annBloc,
      cancelBloc: cancelBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Fenêtre de remise'), findsNothing);
  });

  testWidgets('la date limite de dépôt est affichée et formatée', (
    tester,
  ) async {
    final end = DateTime(2026, 6, 14, 18).toUtc();
    final announcement = _makeAnnouncement(
      handoverDeadline: end,
    );

    await _pump(
      tester,
      announcement: announcement,
      annBloc: annBloc,
      cancelBloc: cancelBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Dépôt des colis'), findsOneWidget);
    // Une seule date, préfixée : plus de plage « début → fin ».
    expect(find.textContaining('Jusqu\'au'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
  });
}
