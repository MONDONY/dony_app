import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

class _FakeTrackingEvent extends Fake implements TrackingEvent {}

TrackingSearchModel _result({String? arrivalInstructions}) =>
    TrackingSearchModel(
      trackingNumber: 'DON-123456',
      bidId: 'b1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      currentStep: 'ARRIVED',
      stepLabel: 'Arrivé',
      paymentStatus: 'PAID',
      arrivalInstructions: arrivalInstructions,
    );

Future<void> _pump(WidgetTester tester, TrackingBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<TrackingBloc>.value(
              value: bloc,
              child: const TrackingSearchScreen(),
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeTrackingEvent());
  });

  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('TrackingSearchScreen — arrival instructions', () {
    testWidgets('shows arrival instructions section when present', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        TrackingSearchLoaded(
          _result(arrivalInstructions: 'Métro Châtelet, sortie 3'),
        ),
      );

      await _pump(tester, bloc);

      expect(find.text('Instructions de retrait'), findsOneWidget);
      expect(find.textContaining('Métro Châtelet'), findsOneWidget);
    });

    testWidgets('hides arrival instructions section when null', (tester) async {
      when(() => bloc.state).thenReturn(TrackingSearchLoaded(_result()));

      await _pump(tester, bloc);

      expect(find.text('Instructions de retrait'), findsNothing);
    });

    testWidgets('hides arrival instructions section when blank', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingSearchLoaded(_result(arrivalInstructions: '   ')));

      await _pump(tester, bloc);

      expect(find.text('Instructions de retrait'), findsNothing);
    });
  });
}
