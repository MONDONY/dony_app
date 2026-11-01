// Étapes du voyage (`TripLegsCard`), carte reprise par le sheet « Itinéraire
// et lieux » de l'écran du trajet : villes longues, FR / EN, 360 dp × 1,3.
// L'audience a sa ligne et ses tests (`trip_audience_line_test.dart`).
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/presentation/widgets/trip_legs_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'trip_card_harness.dart';

class _MockTripGroupCubit extends MockCubit<TripGroupState>
    implements TripGroupCubit {}

final _legs = TripLegsInfo.fromJson(const {
  'tripGroupId': 'g',
  'legCount': 2,
  'legs': [
    {
      'id': 'trip-1',
      'legIndex': 1,
      'departureCity': 'Saint-Rémy-lès-Chevreuse',
      'arrivalCity': 'Yamoussoukro',
      'departureDate': '2026-11-10',
    },
    {
      'id': 'trip-2',
      'legIndex': 2,
      'departureCity': 'Yamoussoukro',
      'arrivalCity': 'Douala',
      'departureDate': '2026-11-14',
    },
  ],
});

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  Widget legs() {
    final cubit = _MockTripGroupCubit();
    whenListen(
      cubit,
      const Stream<TripGroupState>.empty(),
      initialState: TripGroupState(status: TripGroupStatus.loaded, info: _legs),
    );
    return BlocProvider<TripGroupCubit>.value(
      value: cubit,
      child: TripLegsCard(announcementId: 'trip-1', onOpenLeg: (_) {}),
    );
  }

  group('360 dp, texte × 1,3', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} étapes du voyage (villes longues) : '
          'aucun débordement', (tester) async {
        await pumpTripCard(
          tester,
          legs(),
          locale: locale,
          textScale: 1.3,
          size: kTripCardSmallPhone,
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('trip-legs-card')), findsOneWidget);
        expect(find.byKey(const Key('trip-leg-open-trip-2')), findsOneWidget);
      });
    }
  });
}
