import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/tracking/presentation/screens/qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockTrackingRepository extends Mock implements TrackingRepository {}

Widget _wrap(TrackingBloc bloc) => MaterialApp(
  home: BlocProvider<TrackingBloc>.value(
    value: bloc,
    child: const QrScannerScreen(),
  ),
);

void main() {
  setUpAll(
    () =>
        registerFallbackValue(QrScanSubmitRequested(bidId: '', eventType: '')),
  );

  group('QrScannerScreen — anglais', () {
    testWidgets('titre, étape et bouton traduits', (tester) async {
      useEnglish();
      final bloc = _MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(bloc, const Stream<TrackingState>.empty());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('Departure scan'), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('Confirm & continue'), findsOneWidget);

      // Laisse le temps aux timers internes (animations) de se terminer
      // avant la fin du test, sinon flutter_test signale un timer pendant.
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('numéro saisi à la main : l\'étape part en MANUAL', (
    tester,
  ) async {
    useEnglish();
    final repo = _MockTrackingRepository();
    when(() => repo.searchByTrackingNumber(any())).thenAnswer(
      (_) async => const TrackingSearchModel(
        trackingNumber: 'DON-ABC123',
        bidId: 'bid-9',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currentStep: 'DEPART',
        stepLabel: 'Départ',
        paymentStatus: 'CAPTURED',
      ),
    );
    getIt.registerSingleton<TrackingRepository>(repo);
    addTearDown(() => getIt.unregister<TrackingRepository>());
    final bloc = _MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());

    // Les boîtes de dialogue se ferment par GoRouter (`ctx.pop()`).
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<TrackingBloc>.value(
            value: bloc,
            child: const QrScannerScreen(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.tap(find.text('Confirm & continue'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'don-abc123');
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Confirm scan'));
    await tester.tap(find.text('Confirm scan'));
    await tester.pump();

    final event =
        verify(() => bloc.add(captureAny())).captured.single
            as QrScanSubmitRequested;
    expect(event.bidId, 'bid-9');
    expect(event.scanMethod, ScanMethod.manual);
    // Le numéro saisi pour identifier le colis part avec la remise (DEPART).
    expect(event.trackingNumber, 'DON-ABC123');
    await tester.pump(const Duration(seconds: 2));
  });

  group('photo refusée par le serveur', () {
    late StreamController<TrackingState> states;
    late _MockTrackingBloc bloc;
    late List<Map<String, dynamic>> photoExtras;

    TrackingEventModel event(String type) => TrackingEventModel(
      id: 'ev-1',
      bidId: 'bid-9',
      eventType: type,
      scannedAt: DateTime(2026, 10, 11),
      createdAt: DateTime(2026, 10, 11),
    );

    /// Ouvre la feuille de confirmation par la saisie manuelle du numéro.
    Future<void> openSheet(WidgetTester tester) async {
      useEnglish();
      DonySnackbar.clearDedup();
      photoExtras = [];
      final repo = _MockTrackingRepository();
      when(() => repo.searchByTrackingNumber(any())).thenAnswer(
        (_) async => const TrackingSearchModel(
          trackingNumber: 'DON-ABC123',
          bidId: 'bid-9',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          currentStep: 'DEPART',
          stepLabel: 'Départ',
          paymentStatus: 'CAPTURED',
        ),
      );
      getIt.registerSingleton<TrackingRepository>(repo);
      addTearDown(() => getIt.unregister<TrackingRepository>());
      states = StreamController<TrackingState>.broadcast();
      addTearDown(states.close);
      bloc = _MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(bloc, states.stream);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<TrackingBloc>.value(
              value: bloc,
              child: const QrScannerScreen(),
            ),
          ),
          GoRoute(
            path: '/tracking/scan/photo',
            builder: (_, state) {
              photoExtras.add(state.extra! as Map<String, dynamic>);
              return const Scaffold(body: Text('écran photo'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.tap(find.text('Confirm & continue'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'don-abc123');
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Confirm scan'), findsOneWidget);
    }

    final warning = find.text(
      'Step saved without a photo: the server rejected the photo.',
    );

    testWidgets('QrScanSuccess : l\'écran avertit', (tester) async {
      await openSheet(tester);
      states.add(QrScanSuccess(event('DEPART'), photoDropped: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(warning, findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('photo acceptée : aucun avertissement', (tester) async {
      await openSheet(tester);
      states.add(QrScanSuccess(event('DEPART')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(warning, findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    // La remise d'un colis identifié par son numéro passe par l'écran photo,
    // libellé par ce numéro, avec la méthode MANUAL.
    testWidgets('numéro saisi, arrivée : écran photo avec le numéro', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.ensureVisible(find.text('Arrival'));
      await tester.tap(find.text('Arrival'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Take the parcel photo'));
      await tester.tap(find.text('Take the parcel photo'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('écran photo'), findsOneWidget);
      expect(photoExtras.single, {
        'bidId': 'bid-9',
        'etape': 'ARRIVEE',
        'packageLabel': 'DON-ABC123',
        'scanMethod': ScanMethod.manual,
      });
      verifyNever(() => bloc.add(any()));
      await tester.pump(const Duration(seconds: 10));
    });

    // Régression : l'écran et la feuille faisaient chacun `context.pop()` sur
    // QrScanSuccess / QrScanQueued. Le second pop retirait le dialogue que
    // l'écran venait d'ouvrir : il n'était jamais visible après un envoi
    // depuis la feuille.
    testWidgets('QrScanSuccess : la feuille se ferme, le dialogue reste', (
      tester,
    ) async {
      await openSheet(tester);
      states.add(QrScanSuccess(event('DEPART')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Confirm scan'), findsNothing);
      expect(find.text('Scan recorded!'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('QrScanSuccess photo refusée : avertissement et dialogue', (
      tester,
    ) async {
      await openSheet(tester);
      states.add(QrScanSuccess(event('DEPART'), photoDropped: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(warning, findsOneWidget);
      expect(find.text('Scan recorded!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('QrScanQueued : la feuille se ferme, le dialogue reste', (
      tester,
    ) async {
      await openSheet(tester);
      states.add(QrScanQueued());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Confirm scan'), findsNothing);
      expect(find.text('Scan pending'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('QrScanError : la feuille reste ouverte, sans dialogue', (
      tester,
    ) async {
      await openSheet(tester);
      states.add(QrScanError(const NetworkException('boom')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Confirm scan'), findsOneWidget);
      expect(find.text('Scan recorded!'), findsNothing);
      expect(find.text('Scan pending'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('scannedParcelLabel', () {
    test('identifiant long : ses 8 premiers caractères', () {
      expect(scannedParcelLabel('3f2b6c1e-8a4d-4f6b'), '3f2b6c1e');
    });

    test('identifiant court : rendu tel quel', () {
      expect(scannedParcelLabel('bid-9'), 'bid-9');
    });
  });

  // Régression finale F (Important 6 de la relecture) : la fonction comparait
  // le libellé traduit (`event.stepLabel(l)`), donc ne reconnaissait jamais
  // l'étape finale en anglais. Elle compare maintenant `eventType`, le code
  // d'étape serveur — indépendant de la langue affichée.
  group('isFinalDeliveryStep', () {
    test('reconnaît le code ARRIVEE', () {
      expect(isFinalDeliveryStep('ARRIVEE'), isTrue);
    });

    test('renvoie false pour les codes intermédiaires', () {
      expect(isFinalDeliveryStep('DEPART'), isFalse);
      expect(isFinalDeliveryStep('TRANSIT'), isFalse);
      expect(isFinalDeliveryStep(''), isFalse);
    });

    test('indépendant de la langue affichée (anglais)', () {
      useEnglish();
      expect(isFinalDeliveryStep('ARRIVEE'), isTrue);
      expect(isFinalDeliveryStep('DEPART'), isFalse);
    });
  });
}
