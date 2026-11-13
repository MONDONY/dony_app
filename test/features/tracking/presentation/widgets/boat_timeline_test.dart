import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/tracking/data/models/trip_milestones.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/plane_icon_expectations.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

class _FakeTrackingEvent extends Fake implements TrackingEvent {}

TrackingEventModel _event(String type, DateTime at) => TrackingEventModel(
  id: 'evt-$type',
  bidId: 'bid-1',
  eventType: type,
  scannedAt: at,
  createdAt: at,
  scanMethod: ScanMethod.qr,
  gpsLabel: 'Le Havre',
);

/// La frise lit l'horloge du téléphone : le départ prévu et la remise sont
/// placés autour d'aujourd'hui.
final _today = DateTime.now();
final _depositAt = _today.subtract(const Duration(days: 20));

Future<void> _openSheet(
  WidgetTester tester,
  TrackingBloc bloc, {
  required TransportMode? mode,
  String? status,
  TripMilestones? milestones,
  String? from = 'Le Havre',
  String? to = 'Abidjan',
  TravelerTrackingModel? travelerTracking,
}) async {
  if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
  getIt.registerFactory<TrackingBloc>(() => bloc);
  addTearDown(() {
    if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => showTrackingTimelineSheet(
              ctx,
              bidId: 'bid-1',
              departureCity: from,
              arrivalCity: to,
              transportMode: mode,
              trackingNumber: 'DON-7KQ2',
              bidStatus: status,
              milestones: milestones,
              travelerTracking: travelerTracking,
              onShareTracking: () {},
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    registerFallbackValue(_FakeTrackingEvent());
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bloc.add(any())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
  });

  final delay = TripDelayInfo(
    reason: 'PORT_CONGESTION',
    arrivalDate: _today.add(const Duration(days: 30)),
    arrivalDateMax: _today.add(const Duration(days: 37)),
    message: 'Attente au port de Tanger Med',
    announcedAt: _today.subtract(const Duration(days: 2)),
  );
  final atSea = TripMilestones(
    departureDate: _today.subtract(const Duration(days: 10)),
    arrivalDate: _today.add(const Duration(days: 25)),
    arrivalDateMax: _today.add(const Duration(days: 32)),
    latestDelay: delay,
  );

  double y(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text, skipOffstage: false)).dy;

  group('frise bateau (maquette FriseMer)', () {
    testWidgets('boatTimeline_labels : étapes du colis et jalons du trajet', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART', _depositAt)]));
      await _openSheet(
        tester,
        bloc,
        mode: TransportMode.boat,
        status: 'HANDED_OVER',
        milestones: atSea,
        // Positions du téléphone : jamais dans la frise d'un bateau.
        travelerTracking: TravelerTrackingModel(
          status: TravelerTrackingStatus.enRoute,
          history: [
            TravelerTrackingPoint(
              city: 'Lyon',
              at: _depositAt.add(const Duration(hours: 2)),
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('En mer vers Abidjan'), findsOneWidget);
      expect(find.text("Déposé à l'entrepôt"), findsOneWidget);
      expect(find.text('Le Havre · Validé par scan du QR'), findsOneWidget);
      expect(find.text('Bateau parti'), findsOneWidget);
      expect(find.text('En mer'), findsOneWidget);
      expect(
        find.text('Retard annoncé : Attente au port de Tanger Med'),
        findsOneWidget,
      );
      expect(find.text("Arrivé au port d'Abidjan"), findsOneWidget);
      expect(find.textContaining('Estimé du '), findsOneWidget);
      expect(find.text('Remise au destinataire'), findsOneWidget);
      // Dans l'ordre du voyage.
      final order = [
        "Déposé à l'entrepôt",
        'Bateau parti',
        'En mer',
        "Arrivé au port d'Abidjan",
        'Remise au destinataire',
      ].map((t) => y(tester, t)).toList();
      expect(order, [...order]..sort());
      // Ni libellé de voyageur, ni ville du téléphone.
      expect(find.text('Remis au voyageur'), findsNothing);
      expect(find.textContaining('Près de'), findsNothing);
      expect(find.text('En route'), findsNothing);
    });

    testWidgets('boatTimeline_noPlaneIcon : icône bateau, aucun avion', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART', _depositAt)]));
      await _openSheet(
        tester,
        bloc,
        mode: TransportMode.boat,
        status: 'HANDED_OVER',
        milestones: atSea,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tracking-route')),
          matching: findDonyIcon('ship'),
        ),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('pas encore déposé : en attente du dépôt à l\'entrepôt', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(TrackingEventsLoaded(const []));
      await _openSheet(
        tester,
        bloc,
        mode: TransportMode.boat,
        status: 'ACCEPTED',
        milestones: TripMilestones(
          departureDate: _today.add(const Duration(days: 12)),
          arrivalDate: _today.add(const Duration(days: 40)),
          arrivalDateMax: _today.add(const Duration(days: 47)),
        ),
      );
      expect(find.text("En attente du dépôt à l'entrepôt"), findsOneWidget);
      expect(find.text("Dépôt à l'entrepôt"), findsOneWidget);
      expect(find.text('Départ du bateau'), findsOneWidget);
      expect(find.textContaining('Prévu le '), findsOneWidget);
      expect(find.text('Bateau parti'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('trajet arrivé au port : remise en cours', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART', _depositAt)]));
      await _openSheet(
        tester,
        bloc,
        mode: TransportMode.boat,
        status: 'ARRIVED',
        to: 'Dakar',
      );
      expect(find.text('Arrivé au port de Dakar'), findsNWidgets(2));
      expect(find.text('En mer'), findsNothing);
      expect(find.byKey(const Key('tracking-step-current')), findsOneWidget);
    });

    testWidgets('en anglais', (tester) async {
      useEnglish();
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART', _depositAt)]));
      await _openSheet(
        tester,
        bloc,
        mode: TransportMode.boat,
        status: 'HANDED_OVER',
        milestones: atSea,
      );
      expect(find.text('At sea, bound for Abidjan'), findsOneWidget);
      expect(find.text('Dropped off at the warehouse'), findsOneWidget);
      expect(find.text('Ship departed'), findsOneWidget);
      expect(find.text('At sea'), findsOneWidget);
      expect(find.text('Arrived at the port of Abidjan'), findsOneWidget);
      expect(
        find.text('Delay announced: Attente au port de Tanger Med'),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });
  });

  group('frise route et mode inconnu : neutre', () {
    testWidgets('route : icône voiture, étapes neutres, jamais d\'avion', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART', _depositAt)]));
      await _openSheet(
        tester,
        bloc,
        mode: TransportMode.car,
        status: 'HANDED_OVER',
        from: 'Paris',
        to: 'Dakar',
        milestones: TripMilestones(
          departureDate: _today.subtract(const Duration(days: 3)),
          arrivalDate: _today.add(const Duration(days: 4)),
        ),
      );
      expect(find.text('En route vers Dakar'), findsOneWidget);
      expect(find.text('Remis au voyageur'), findsOneWidget);
      expect(find.text('En route'), findsOneWidget);
      expect(find.text('Remise au destinataire'), findsOneWidget);
      // Rien du bateau sur la route.
      expect(find.text('Bateau parti'), findsNothing);
      expect(find.text('En mer'), findsNothing);
      expect(find.textContaining('entrepôt'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('tracking-route')),
          matching: findDonyIcon('car'),
        ),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('mode inconnu (colis d\'un tiers) : icône neutre', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART', _depositAt)]));
      await _openSheet(
        tester,
        bloc,
        mode: TransportMode.other,
        from: 'Paris',
        to: 'Dakar',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tracking-route')),
          matching: findDonyIcon('route'),
        ),
        findsOneWidget,
      );
      expect(find.text('Remis au voyageur'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });
  });
}
