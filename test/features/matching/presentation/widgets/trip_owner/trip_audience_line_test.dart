// Ligne d'audience de l'écran du trajet, sous les compteurs « Activité du
// trajet » : mêmes conditions et mêmes textes que la carte d'audience
// d'avant, en texte discret, clé `trip-audience-card` gardée, FR / EN,
// 360 dp × 1,3.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_audience_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_audience_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_card_harness.dart';
import 'trip_owner_harness.dart' show kTripStatuses;

class _MockTripAudienceCubit extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

void main() {
  late _MockTripAudienceCubit cubit;

  setUpAll(loadAppFonts);

  setUp(() {
    cubit = _MockTripAudienceCubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
  });

  Widget line(TripAudienceState state, {EdgeInsetsGeometry? padding}) {
    whenListen(
      cubit,
      const Stream<TripAudienceState>.empty(),
      initialState: state,
    );
    return BlocProvider<TripAudienceCubit>.value(
      value: cubit,
      child: padding == null
          ? const TripAudienceLine(announcementId: 'trip-1')
          : TripAudienceLine(announcementId: 'trip-1', padding: padding),
    );
  }

  TripAudienceState loaded(int viewers, int shares) => TripAudienceState.loaded(
    TripAudienceModel(uniqueViewerCount: viewers, shareViewCount: shares),
  );

  group('statuts : même règle que la carte d\'avant', () {
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
    for (final status in kTripStatuses) {
      test(status, () {
        expect(TripAudienceLine.shownFor(status), expected[status]);
        expect(
          TripAudienceSection.shownFor(status),
          TripAudienceLine.shownFor(status),
        );
      });
    }
  });

  testWidgets('charge l\'audience du trajet au montage', (tester) async {
    await pumpTripCard(tester, line(const TripAudienceState.initial()));
    verify(() => cubit.load('trip-1')).called(1);
  });

  testWidgets('vues et affiche sur une ligne discrète, sans carte', (
    tester,
  ) async {
    await pumpTripCard(tester, line(loaded(12, 7)));
    final row = find.byKey(const Key('trip-audience-card'));
    expect(row, findsOneWidget);
    expect(
      find.text(
        '12 personnes ont vu votre trajet · 7 vues de votre affiche partagée',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byType(DonyCard)),
      findsNothing,
    );
    final text = tester.widget<Text>(
      find.descendant(of: row, matching: find.byType(Text)),
    );
    final cs = Theme.of(tester.element(row)).colorScheme;
    expect(text.style?.color, cs.onSurfaceVariant);
  });

  testWidgets('personne dans l\'app, affiche vue : seulement l\'affiche', (
    tester,
  ) async {
    await pumpTripCard(tester, line(loaded(0, 3)));
    expect(find.text('3 vues de votre affiche partagée'), findsOneWidget);
    expect(find.textContaining('Personne'), findsNothing);
  });

  testWidgets('aucune vue : « Personne n\'a encore vu votre trajet »', (
    tester,
  ) async {
    await pumpTripCard(tester, line(loaded(0, 0)));
    expect(find.text('Personne n\'a encore vu votre trajet'), findsOneWidget);
  });

  testWidgets('une personne : singulier', (tester) async {
    await pumpTripCard(tester, line(loaded(1, 0)));
    expect(find.text('1 personne a vu votre trajet'), findsOneWidget);
  });

  testWidgets('pas chargée, en échec : rien, pas même la marge', (
    tester,
  ) async {
    await pumpTripCard(
      tester,
      line(
        const TripAudienceState.initial(),
        padding: const EdgeInsets.all(30),
      ),
    );
    expect(find.byKey(const Key('trip-audience-card')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Padding && w.padding == const EdgeInsets.all(30),
      ),
      findsNothing,
    );
  });

  testWidgets('marge réglable, appliquée seulement à l\'affichage', (
    tester,
  ) async {
    await pumpTripCard(
      tester,
      line(loaded(2, 0), padding: const EdgeInsets.only(top: 8)),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Padding && w.padding == const EdgeInsets.only(top: 8),
      ),
      findsOneWidget,
    );
  });

  testWidgets('anglais', (tester) async {
    await pumpTripCard(tester, line(loaded(12, 1)), locale: const Locale('en'));
    expect(
      find.text('12 people have seen your trip · 1 view of your shared poster'),
      findsOneWidget,
    );
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    testWidgets('${locale.languageCode} à 360 dp × 1,3 : aucune exception', (
      tester,
    ) async {
      await pumpTripCard(
        tester,
        line(loaded(1234, 567)),
        locale: locale,
        textScale: 1.3,
        size: kTripCardSmallPhone,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
