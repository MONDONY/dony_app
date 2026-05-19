import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

Widget _wrap(String etape, MockTrackingBloc bloc) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => MultiBlocProvider(
        providers: [
          BlocProvider<TrackingBloc>.value(value: bloc),
          BlocProvider<RatingBloc>(create: (_) => MockRatingBloc()),
        ],
        child: ScanConfirmScreen(
          bidId: 'bid-123',
          etape: etape,
          packageLabel: 'DON-TEST01',
          photoPath: null,
          gpsLat: null,
          gpsLon: null,
        ),
      ),
    ),
    GoRoute(
        path: '/tracking',
        builder: (_, __) => const Scaffold(body: Text('hub'))),
  ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() {
    registerFallbackValue(
        QrScanSubmitRequested(bidId: '', eventType: ''));
    registerFallbackValue(
        ConfirmDeliveryRequested(bidId: '', code: ''));
  });

  testWidgets('DEPART — pas de champ code, bouton Valider', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    expect(find.text('Valider le scan'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('ARRIVEE — champ code visible + bouton Confirmer', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    expect(find.text('Confirmer la livraison'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('DEPART — tap Valider dispatch QrScanSubmitRequested',
      (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    await tester.tap(find.text('Valider le scan'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<QrScanSubmitRequested>()))).called(1);
  });

  testWidgets('affiche recap avec packageLabel', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    expect(find.text('DON-TEST01'), findsOneWidget);
  });
}
