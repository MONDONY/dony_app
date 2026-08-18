import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

class _FakeTrackingEvent extends Fake implements TrackingEvent {}

TrackingEventModel _event(String type) => TrackingEventModel(
  id: 'evt-$type',
  bidId: 'bid-1',
  eventType: type,
  scannedAt: DateTime(2026, 6, 20, 10),
  createdAt: DateTime(2026, 6, 20, 10),
);

/// Ouvre la sheet de suivi avec un TrackingBloc mocké injecté via GetIt
/// (c'est `showTrackingTimelineSheet` qui l'instancie lui-même).
Future<void> _openSheet(
  WidgetTester tester,
  TrackingBloc bloc, {
  String? arrivalInstructions,
  bool settle = true,
}) async {
  if (getIt.isRegistered<TrackingBloc>()) {
    getIt.unregister<TrackingBloc>();
  }
  getIt.registerFactory<TrackingBloc>(() => bloc);
  addTearDown(() {
    if (getIt.isRegistered<TrackingBloc>()) {
      getIt.unregister<TrackingBloc>();
    }
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => showTrackingTimelineSheet(
              ctx,
              bidId: 'bid-1',
              corridor: 'Paris → Dakar',
              arrivalInstructions: arrivalInstructions,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Ouvrir'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // L'indicateur de chargement tourne en boucle : pumpAndSettle n'aboutirait pas.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeTrackingEvent());
  });

  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bloc.add(any())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
  });

  testWidgets('affiche le chargement', (tester) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoading());

    await _openSheet(tester, bloc, settle: false);

    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });

  testWidgets('affiche la carte corridor quand les étapes sont chargées', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));

    await _openSheet(tester, bloc);

    expect(find.byType(RouteMapCard), findsOneWidget);
    expect(find.text('ÉTAPES'), findsOneWidget);
  });

  group('instructions de retrait', () {
    testWidgets('bandeau affiché quand arrivé et instructions présentes', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART'), _event('ARRIVEE')]));

      await _openSheet(
        tester,
        bloc,
        arrivalInstructions: 'Métro Châtelet, sortie 3',
      );

      expect(find.text('Instructions de retrait'), findsOneWidget);
      expect(find.textContaining('Métro Châtelet'), findsOneWidget);
    });

    testWidgets('bandeau absent quand les instructions sont nulles', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('ARRIVEE')]));

      await _openSheet(tester, bloc);

      expect(find.text('Instructions de retrait'), findsNothing);
    });

    testWidgets('bandeau absent quand les instructions sont vides', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('ARRIVEE')]));

      await _openSheet(tester, bloc, arrivalInstructions: '   ');

      expect(find.text('Instructions de retrait'), findsNothing);
    });

    testWidgets('bandeau absent tant que le colis n\'est pas arrivé', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART')]));

      await _openSheet(
        tester,
        bloc,
        arrivalInstructions: 'Métro Châtelet, sortie 3',
      );

      expect(find.text('Instructions de retrait'), findsNothing);
      expect(find.text('En attente de confirmation'), findsOneWidget);
    });
  });
}
