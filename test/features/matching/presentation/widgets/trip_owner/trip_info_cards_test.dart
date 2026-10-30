// Cartes d'information sans titre de l'écran du trajet : audience
// (`TripAudienceSection`) et étapes du voyage (`TripLegsCard`). Contenu et
// logique inchangés : statuts où l'audience s'affiche, marge réglable pour
// le corps en sections, FR / EN, 360 dp × 1,3.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/presentation/widgets/trip_audience_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_legs_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_card_harness.dart';

class _MockTripAudienceCubit extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

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

  group('audience : statuts', () {
    const expected = {
      'DRAFT': false,
      'ACTIVE': true,
      'FULL': true,
      'IN_PROGRESS': true,
      'COMPLETED': true,
      'CANCELLED': false,
      'REMOVED_BY_ADMIN': false,
      'SOMETHING_NEW': true,
    };
    for (final MapEntry(key: status, value: shown) in expected.entries) {
      test('$status : ${shown ? 'affichée' : 'masquée'}', () {
        expect(TripAudienceSection.shownFor(status), shown);
      });
    }
  });

  Widget audience(TripAudienceState state, {EdgeInsetsGeometry? padding}) {
    final cubit = _MockTripAudienceCubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
    whenListen(
      cubit,
      const Stream<TripAudienceState>.empty(),
      initialState: state,
    );
    return BlocProvider<TripAudienceCubit>.value(
      value: cubit,
      child: padding == null
          ? const TripAudienceSection(announcementId: 'trip-1')
          : TripAudienceSection(announcementId: 'trip-1', padding: padding),
    );
  }

  const loaded = TripAudienceState.loaded(
    TripAudienceModel(uniqueViewerCount: 12, shareViewCount: 7),
  );

  testWidgets('audience : marge basse par défaut, réglable', (tester) async {
    await pumpTripCard(tester, audience(loaded));
    final card = find.byKey(const Key('trip-audience-card'));
    final defaultPadding = tester.widget<Padding>(
      find.ancestor(of: card, matching: find.byType(Padding)).first,
    );
    expect(defaultPadding.padding, const EdgeInsets.only(bottom: 20));

    await pumpTripCard(tester, audience(loaded, padding: EdgeInsets.zero));
    final zero = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byKey(const Key('trip-audience-card')),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(zero.padding, EdgeInsets.zero);
  });

  testWidgets('audience : contenu inchangé, carte sans titre', (tester) async {
    await pumpTripCard(tester, audience(loaded));

    expect(find.text('12 personnes ont vu votre trajet'), findsOneWidget);
    expect(find.text('7 vues de votre affiche partagée'), findsOneWidget);
  });

  testWidgets('audience non chargée : rien, pas même la marge', (tester) async {
    await pumpTripCard(tester, audience(const TripAudienceState.initial()));

    expect(find.byKey(const Key('trip-audience-card')), findsNothing);
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
      testWidgets('${locale.languageCode} audience : aucun débordement', (
        tester,
      ) async {
        await pumpTripCard(
          tester,
          audience(
            const TripAudienceState.loaded(
              TripAudienceModel(uniqueViewerCount: 1234, shareViewCount: 987),
            ),
          ),
          locale: locale,
          textScale: 1.3,
          size: kTripCardSmallPhone,
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('trip-audience-card')), findsOneWidget);
      });

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
