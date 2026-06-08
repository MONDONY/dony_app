import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockScanHubCubit extends MockCubit<ScanHubState>
    implements ScanHubCubit {}

AnnouncementModel _trip() => AnnouncementModel(
      id: 'trip-1',
      travelerId: 'traveler-1',
      status: 'IN_PROGRESS',
      departureDate: DateTime(2026, 6, 22),
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

GoRouter _router(ScanHubCubit cubit) => GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<ScanHubCubit>.value(
          value: cubit,
          child: const ScanHubView(),
        ),
      ),
      GoRoute(
        path: '/tracking/scan/identify',
        builder: (_, __) => const Scaffold(body: Text('identify')),
      ),
      GoRoute(
        path: '/tracking/scan',
        builder: (_, __) => const Scaffold(body: Text('qr-scan')),
      ),
      GoRoute(
        path: '/announcements/trips',
        builder: (_, __) => const Scaffold(body: Text('mes-trajets')),
      ),
    ]);

Widget _wrap(ScanHubCubit cubit) =>
    MaterialApp.router(routerConfig: _router(cubit));

void main() {
  late _MockScanHubCubit cubit;

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    cubit = _MockScanHubCubit();
  });

  testWidgets('affiche titre et 3 étapes quand ScanHubLoaded',
      (tester) async {
    when(() => cubit.state).thenReturn(
      ScanHubLoaded(
        trip: _trip(),
        progress: const ScanHubProgress(confirmedColis: 3, scannedDepart: 1),
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    expect(find.text('Scan & Suivi'), findsOneWidget);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Arrivée'), findsOneWidget);
  });

  testWidgets('affiche corridor du trajet réel quand ScanHubLoaded',
      (tester) async {
    when(() => cubit.state).thenReturn(
      ScanHubLoaded(
        trip: _trip(),
        progress: const ScanHubProgress(confirmedColis: 3, scannedDepart: 1),
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    expect(find.textContaining('Paris'), findsOneWidget);
    expect(find.textContaining('Dakar'), findsOneWidget);
  });

  testWidgets('affiche état vide quand ScanHubEmpty', (tester) async {
    when(() => cubit.state).thenReturn(const ScanHubEmpty());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Aucun trajet à scanner'), findsOneWidget);
  });

  testWidgets('affiche loading quand ScanHubLoading', (tester) async {
    when(() => cubit.state).thenReturn(const ScanHubLoading());
    await tester.pumpWidget(_wrap(cubit));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tap Départ navigue vers identify', (tester) async {
    when(() => cubit.state).thenReturn(
      ScanHubLoaded(
        trip: _trip(),
        progress: const ScanHubProgress(confirmedColis: 3, scannedDepart: 1),
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.tap(find.text('Départ'));
    await tester.pumpAndSettle();
    expect(find.text('identify'), findsOneWidget);
  });

  testWidgets('tap Scanner QR navigue vers /tracking/scan', (tester) async {
    when(() => cubit.state).thenReturn(
      ScanHubLoaded(
        trip: _trip(),
        progress: const ScanHubProgress(confirmedColis: 3, scannedDepart: 1),
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.tap(find.text('Scanner QR'));
    await tester.pumpAndSettle();
    expect(find.text('qr-scan'), findsOneWidget);
  });

  testWidgets('affiche obligatoire pour Départ et Arrivée', (tester) async {
    when(() => cubit.state).thenReturn(
      ScanHubLoaded(
        trip: _trip(),
        progress: const ScanHubProgress(confirmedColis: 3, scannedDepart: 1),
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    expect(find.text('obligatoire'), findsNWidgets(2));
    expect(find.text('optionnelle'), findsOneWidget);
  });

  testWidgets('état vide — tap Voir mes trajets navigue vers /announcements/trips',
      (tester) async {
    when(() => cubit.state).thenReturn(const ScanHubEmpty());
    await tester.pumpWidget(_wrap(cubit));
    await tester.tap(find.text('Voir mes trajets'));
    await tester.pumpAndSettle();
    expect(find.text('mes-trajets'), findsOneWidget);
  });
}
