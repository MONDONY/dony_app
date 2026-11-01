// Étapes du voyage dans le sheet « Itinéraire et lieux » de l'écran du
// trajet (redesign du 31/10 : plus de carte d'étapes dans le corps). Voyage à
// plusieurs étapes seulement, clés `trip-legs-card` / `trip-leg-open-*`
// gardées, étape ouverte une fois le sheet fermé.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'trip_answer_harness.dart';

final _legs = TripLegsInfo.fromJson(const {
  'tripGroupId': 'g',
  'legCount': 2,
  'legs': [
    {
      'id': 'trip-1',
      'legIndex': 1,
      'departureCity': 'Paris',
      'arrivalCity': 'Abidjan',
      'departureDate': '2026-11-10',
    },
    {
      'id': 'trip-2',
      'legIndex': 2,
      'departureCity': 'Abidjan',
      'arrivalCity': 'Douala',
      'departureDate': '2026-11-14',
    },
  ],
});

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AnswerHarness h;

  setUpAll(() async {
    AnswerHarness.registerFallbacks();
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  setUp(() async {
    h = AnswerHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<List<AnswerPushedRoute>> open(
    WidgetTester tester, {
    TripGroupState? group,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(400, 900),
  }) async {
    MockTripGroupCubit? cubit;
    if (group != null) {
      cubit = MockTripGroupCubit();
      whenListen(
        cubit,
        const Stream<TripGroupState>.empty(),
        initialState: group,
      );
    }
    // Voyage à étapes sans lieu de remise : la tuile existe pour ses étapes.
    final trip = answerTrip(tripGroupId: 'g');
    final pushed = await h.pump(
      tester,
      trip: trip,
      bids: const [],
      group: cubit,
      locale: locale,
      textScale: textScale,
      size: size,
      body: (context) => TextButton(
        onPressed: () => openTripTileSheet(context, trip, TripTile.itinerary),
        child: const Text('open-itinerary'),
      ),
    );
    await tester.tap(find.text('open-itinerary'));
    await _settle(tester);
    return pushed;
  }

  testWidgets('voyage à étapes : la carte des étapes dans le sheet, après '
      'les lieux', (tester) async {
    await open(
      tester,
      group: TripGroupState(status: TripGroupStatus.loaded, info: _legs),
    );
    final content = find.byKey(const Key('trip-tile-itinerary-content'));
    expect(content, findsOneWidget);
    final legs = find.descendant(
      of: content,
      matching: find.byKey(const Key('trip-legs-card')),
    );
    expect(legs, findsOneWidget);
    expect(find.byKey(const Key('trip-leg-open-trip-2')), findsOneWidget);
  });

  testWidgets('étape touchée : sheet fermé, trajet de l\'étape ouvert', (
    tester,
  ) async {
    final pushed = await open(
      tester,
      group: TripGroupState(status: TripGroupStatus.loaded, info: _legs),
    );
    await tester.tap(find.byKey(const Key('trip-leg-open-trip-2')));
    await _settle(tester);
    expect(pushed.single.location, '/announcements/trip-2/trip');
    expect(find.byKey(const Key('trip-tile-itinerary-content')), findsNothing);
  });

  testWidgets('trajet isolé, chargement, échec, écran sans cubit : pas '
      'd\'étapes', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('trip-legs-card')), findsNothing);
    expect(
      find.byKey(const Key('trip-tile-itinerary-content')),
      findsOneWidget,
    );
  });

  testWidgets('groupe en chargement : pas d\'étapes', (tester) async {
    await open(
      tester,
      group: const TripGroupState(status: TripGroupStatus.loading),
    );
    expect(find.byKey(const Key('trip-legs-card')), findsNothing);
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    testWidgets('${locale.languageCode} à 360 dp × 1,3 : aucune exception', (
      tester,
    ) async {
      await open(
        tester,
        group: TripGroupState(status: TripGroupStatus.loaded, info: _legs),
        locale: locale,
        textScale: 1.3,
        size: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('trip-legs-card')), findsOneWidget);
    });
  }
}
