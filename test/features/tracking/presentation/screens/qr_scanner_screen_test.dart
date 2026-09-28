import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
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

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

Widget _wrap(TrackingBloc bloc, RatingBloc ratingBloc) => MaterialApp(
  home: MultiBlocProvider(
    providers: [
      BlocProvider<TrackingBloc>.value(value: bloc),
      BlocProvider<RatingBloc>.value(value: ratingBloc),
    ],
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
      final ratingBloc = _MockRatingBloc();
      when(() => ratingBloc.state).thenReturn(const RatingInitial());
      whenListen(ratingBloc, const Stream<RatingState>.empty());

      await tester.pumpWidget(_wrap(bloc, ratingBloc));
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
    final ratingBloc = _MockRatingBloc();
    when(() => ratingBloc.state).thenReturn(const RatingInitial());
    whenListen(ratingBloc, const Stream<RatingState>.empty());

    // Les boîtes de dialogue se ferment par GoRouter (`ctx.pop()`).
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<TrackingBloc>.value(value: bloc),
              BlocProvider<RatingBloc>.value(value: ratingBloc),
            ],
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
    await tester.pump(const Duration(seconds: 2));
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
