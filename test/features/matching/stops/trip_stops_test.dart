// FLUTTER-GE / FLUTTER-GD : escales d'un trajet en avion.
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/stops_chips.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/matching/presentation/widgets/trip_stops_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/l10n_test_helpers.dart';

Map<String, dynamic> _json({Object? stopsCount}) => {
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime(2026, 11, 12).toIso8601String(),
  'availableKg': 20.0,
  'totalKg': 20.0,
  'pricePerKg': 5.0,
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 10).toIso8601String(),
  'updatedAt': DateTime(2026, 10).toIso8601String(),
  'stopsCount': ?stopsCount,
};

AnnouncementPayload _payload(TransportMode mode, TripStops? stops) =>
    AnnouncementPayload(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 11, 12),
      pickupAddress: const AddressData(label: 'CDG', lat: 49, lng: 2.5),
      deliveryAddress: const AddressData(label: 'DSS', lat: 14.7, lng: -17.4),
      availableKg: 10,
      pricePerKg: 5,
      transportMode: mode,
      stops: stops,
      handoverDeadline: DateTime(2026, 11, 11, 18),
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('TripStops — fil', () {
    test('lecture tolérante', () {
      expect(tripStopsFromWire(0), TripStops.direct);
      expect(tripStopsFromWire(1), TripStops.one);
      expect(tripStopsFromWire(2), TripStops.twoOrMore);
      expect(tripStopsFromWire(5), TripStops.twoOrMore);
      expect(tripStopsFromWire(null), isNull);
      expect(tripStopsFromWire(-1), isNull);
      expect(tripStopsFromWire('1'), isNull);
      expect(tripStopsToWire(TripStops.one), 1);
      expect(tripStopsToWire(null), isNull);
    });

    test('seul l\'avion porte des escales', () {
      expect(supportsStops(TransportMode.plane), isTrue);
      expect(supportsStops(TransportMode.car), isFalse);
      expect(supportsStops(null), isFalse);
    });

    test('AnnouncementModel lit stopsCount, absent = non renseigné', () {
      expect(
        AnnouncementModel.fromJson(_json(stopsCount: 1)).stops,
        TripStops.one,
      );
      expect(AnnouncementModel.fromJson(_json()).stops, isNull);
      expect(
        AnnouncementModel.fromJson(_json(stopsCount: 0)).toJson()['stopsCount'],
        0,
      );
    });

    test('le payload n\'envoie les escales que pour l\'avion', () {
      expect(
        _payload(TransportMode.plane, TripStops.direct).toJson()['stopsCount'],
        0,
      );
      expect(
        _payload(
          TransportMode.car,
          TripStops.one,
        ).toJson().containsKey('stopsCount'),
        isFalse,
      );
      expect(
        _payload(TransportMode.plane, null).toJson().containsKey('stopsCount'),
        isFalse,
      );
    });

    test('StopsFilter porte la borne maxStops', () {
      expect(StopsFilter.directOnly.maxStops, 0);
      expect(StopsFilter.maxOne.maxStops, 1);
    });
  });

  group('TripStopsBadge', () {
    testWidgets('rien quand les escales ne sont pas renseignées', (
      tester,
    ) async {
      await tester.pumpWidget(localizedApp(const TripStopsBadge(stops: null)));
      expect(find.byKey(const Key('trip-stops-badge')), findsNothing);
    });

    testWidgets('libellé selon la valeur', (tester) async {
      for (final (stops, label) in [
        (TripStops.direct, 'Vol direct'),
        (TripStops.one, '1 escale'),
        (TripStops.twoOrMore, '2 escales et +'),
      ]) {
        await tester.pumpWidget(localizedApp(TripStopsBadge(stops: stops)));
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('anglais', (tester) async {
      enableEnglish();
      await tester.pumpWidget(
        localizedApp(
          const TripStopsBadge(stops: TripStops.direct),
          locale: const Locale('en'),
        ),
      );
      expect(find.text('Direct flight'), findsOneWidget);
    });
  });

  group('StopsChips', () {
    testWidgets('choisir puis retoucher l\'option la retire', (tester) async {
      final notifier = ValueNotifier<TripStops?>(null);
      await tester.pumpWidget(
        localizedApp(Scaffold(body: StopsChips(notifier: notifier))),
      );
      expect(find.text('Escales (facultatif)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stops-one')));
      await tester.pump();
      expect(notifier.value, TripStops.one);

      await tester.tap(find.byKey(const Key('stops-direct')));
      await tester.pump();
      expect(notifier.value, TripStops.direct);

      await tester.tap(find.byKey(const Key('stops-direct')));
      await tester.pump();
      expect(notifier.value, isNull);
    });
  });

  group('TrajetStep — champ escales', () {
    Widget host(
      ValueNotifier<TransportMode?> mode,
      ValueNotifier<TripStops?> stops,
    ) => localizedApp(
      Scaffold(
        body: SingleChildScrollView(
          child: TrajetStep(
            departureCityNotifier: ValueNotifier<String?>('Paris'),
            arrivalCityNotifier: ValueNotifier<String?>('Dakar'),
            departureDateNotifier: ValueNotifier<DateTime?>(null),
            departureTimeNotifier: ValueNotifier<TimeOfDay?>(null),
            arrivalTimeNotifier: ValueNotifier<TimeOfDay?>(null),
            stopsNotifier: stops,
            transportModeNotifier: mode,
            lockCorridor: true,
            onSelectDepartureTime: () async {},
            onSelectArrivalTime: () async {},
            onSelectDate: () async {},
          ),
        ),
      ),
    );

    testWidgets('proposé en avion, masqué pour un autre mode', (tester) async {
      final mode = ValueNotifier<TransportMode?>(TransportMode.plane);
      final stops = ValueNotifier<TripStops?>(null);
      await tester.pumpWidget(host(mode, stops));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('stops-chips')), findsOneWidget);

      mode.value = TransportMode.car;
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('stops-chips')), findsNothing);
    });
  });
}
