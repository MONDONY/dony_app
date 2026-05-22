import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

// ── Helpers ───────────────────────────────────────────────────────────────────

AnnouncementModel _makeAnnouncement({
  String id = 'ann-001',
  String status = 'ACTIVE',
  DateTime? departureDate,
  int bidsCount = 0,
}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: departureDate ??
          DateTime.now().add(const Duration(days: 10)),
      availableKg: 10.0,
      totalKg: 23.0,
      pricePerKg: 8.0,
      status: status,
      bidsCount: bidsCount,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester, MockAnnouncementBloc bloc) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => BlocProvider<AnnouncementBloc>.value(
          value: bloc,
          child: const AnnouncementListScreen(),
        ),
      ),
      GoRoute(
        path: '/announcements/:id/bids',
        builder: (ctx, _) => const Scaffold(body: Text('Bids')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
    ),
  );
  // pump once to settle the initial frame, ignore pending animations
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAnnouncementBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(_FakeAnnouncementEvent());
  });

  setUp(() {
    bloc = MockAnnouncementBloc();
  });

  group('AnnouncementListScreen — états BLoC', () {
    testWidgets('AnnouncementInitial → affiche CircularProgressIndicator',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AnnouncementLoading → affiche CircularProgressIndicator',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementLoading());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'AnnouncementError sans liste — affiche vue erreur avec icône',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementError(
        const NetworkException('Pas de connexion'),
      ));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      // _ErrorView shows wifi_off icon
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('AnnouncementListLoaded liste vide — affiche vue vide onglet À venir',
        (tester) async {
      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Aucun trajet à venir'), findsOneWidget);
    });

    testWidgets(
        'AnnouncementListLoaded avec annonce ACTIVE — affiche les villes',
        (tester) async {
      final announcement = _makeAnnouncement(bidsCount: 2);
      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([announcement]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('Paris'), findsWidgets);
      expect(find.textContaining('Dakar'), findsWidgets);
    });

    testWidgets(
        'AnnouncementListLoaded avec annonce IN_PROGRESS — section "En cours" visible',
        (tester) async {
      final inProgress = _makeAnnouncement(id: 'ann-004', status: 'IN_PROGRESS');
      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([inProgress]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('En cours'), findsWidgets);
    });

    testWidgets('FAB présent sur l\'écran', (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('AppBar affiche "Mes trajets"', (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.text('Mes trajets'), findsOneWidget);
    });
  });

  group('AnnouncementListScreen — navigation onglets', () {
    testWidgets('onglet Historique visible', (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      // Tab bar should have Historique tab
      expect(find.text('Historique'), findsWidgets);
    });

    testWidgets('onglet Annulés visible', (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Annulés'), findsWidgets);
    });

    testWidgets('tap sur onglet Historique — affiche vue vide historique',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded(
        [_makeAnnouncement(status: 'ACTIVE')],
      ));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      final historyTab = find.text('Historique');
      if (historyTab.evaluate().isNotEmpty) {
        await tester.tap(historyTab.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Aucun historique'), findsOneWidget);
      }
    });

    testWidgets('tap sur onglet Annulés — affiche vue vide annulés',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded(
        [_makeAnnouncement(status: 'ACTIVE')],
      ));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 350));

      final cancelledTab = find.text('Annulés');
      if (cancelledTab.evaluate().isNotEmpty) {
        await tester.tap(cancelledTab.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Aucune annulation'), findsOneWidget);
      }
    });
  });

  group('AnnouncementListScreen — stream états', () {
    testWidgets('AnnouncementDeleted déclenche AnnouncementListRequested',
        (tester) async {
      // Use a broadcast stream so BlocConsumer (listener+builder) can both subscribe.
      final controller = StreamController<AnnouncementState>.broadcast();
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => controller.stream);
      when(() => bloc.add(any(that: isA<AnnouncementListRequested>()))).thenReturn(null);

      await _pump(tester, bloc);
      // Settle flutter_animate timers from initial render.
      await tester.pump(const Duration(milliseconds: 350));

      controller.add(AnnouncementDeleted());
      await tester.pump();
      // Settle any new animations triggered by state change.
      await tester.pump(const Duration(milliseconds: 350));

      verify(() => bloc.add(any(that: isA<AnnouncementListRequested>()))).called(greaterThanOrEqualTo(1));
      await controller.close();
    });
  });
}
