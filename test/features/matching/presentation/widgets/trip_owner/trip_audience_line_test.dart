// Audience du trajet vue par son voyageur : statuts où elle a un sens,
// chargement par TripAudienceLoader (montage, brouillon publié, autre
// trajet), sous-titre de la tuile « Affiche » (TripAudience.tileSubtitle),
// ligne du sheet « Affiche » (textes : personnes, vues de l'affiche,
// « personne », texte discret, clé `trip-audience-card`), FR / EN,
// 360 dp × 1,3.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_audience_line.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
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
          ? const TripAudienceLine()
          : TripAudienceLine(padding: padding),
    );
  }

  TripAudienceState loaded(int viewers, int shares) => TripAudienceState.loaded(
    TripAudienceModel(uniqueViewerCount: viewers, shareViewCount: shares),
  );

  group('statuts : masquée si les expéditeurs ne voient pas le trajet', () {
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
        expect(TripAudience.shownFor(status), expected[status]);
      });
    }
  });

  group('TripAudienceLoader', () {
    final status = ValueNotifier('ACTIVE');
    final id = ValueNotifier('trip-1');

    setUp(() {
      status.value = 'ACTIVE';
      id.value = 'trip-1';
    });

    Widget loader() {
      whenListen(
        cubit,
        const Stream<TripAudienceState>.empty(),
        initialState: const TripAudienceState.initial(),
      );
      return BlocProvider<TripAudienceCubit>.value(
        value: cubit,
        child: ValueListenableBuilder<String>(
          valueListenable: id,
          builder: (context, trip, _) => ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, s, _) => TripAudienceLoader(
              announcementId: trip,
              status: s,
              child: const Text('contenu'),
            ),
          ),
        ),
      );
    }

    testWidgets('charge l\'audience au montage et rend son enfant', (
      tester,
    ) async {
      await pumpTripCard(tester, loader());
      verify(() => cubit.load('trip-1')).called(1);
      expect(find.text('contenu'), findsOneWidget);
    });

    for (final hidden in const ['DRAFT', 'CANCELLED', 'REMOVED_BY_ADMIN']) {
      testWidgets('$hidden : rien n\'est chargé', (tester) async {
        status.value = hidden;
        await pumpTripCard(tester, loader());
        verifyNever(() => cubit.load(any()));
        expect(find.text('contenu'), findsOneWidget);
      });
    }

    testWidgets('brouillon publié : chargé une fois à la publication', (
      tester,
    ) async {
      status.value = 'DRAFT';
      await pumpTripCard(tester, loader());
      verifyNever(() => cubit.load(any()));
      status.value = 'ACTIVE';
      await tester.pump();
      verify(() => cubit.load('trip-1')).called(1);
      // Passer complet ne recharge pas.
      status.value = 'FULL';
      await tester.pump();
      verifyNever(() => cubit.load(any()));
    });

    testWidgets('autre trajet : rechargé pour lui', (tester) async {
      await pumpTripCard(tester, loader());
      verify(() => cubit.load('trip-1')).called(1);
      id.value = 'trip-2';
      await tester.pump();
      verify(() => cubit.load('trip-2')).called(1);
    });

    testWidgets('sans cubit : rien ne casse', (tester) async {
      await pumpTripCard(
        tester,
        const TripAudienceLoader(
          announcementId: 'trip-1',
          status: 'ACTIVE',
          child: Text('contenu'),
        ),
      );
      expect(find.text('contenu'), findsOneWidget);
    });
  });

  group('TripAudience.tileSubtitle (tuile « Affiche »)', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('chargée : le nombre de personnes', () {
      expect(
        TripAudience.tileSubtitle(fr, loaded(12, 7)),
        '12 personnes ont vu votre trajet',
      );
      expect(
        TripAudience.tileSubtitle(en, loaded(12, 7)),
        '12 people have seen your trip',
      );
      expect(
        TripAudience.tileSubtitle(fr, loaded(1, 0)),
        '1 personne a vu votre trajet',
      );
      expect(
        TripAudience.tileSubtitle(fr, loaded(0, 0)),
        'Personne n\'a encore vu votre trajet',
      );
    });

    test('personne dans l\'app, affiche vue : les vues de l\'affiche', () {
      expect(
        TripAudience.tileSubtitle(fr, loaded(0, 3)),
        '3 vues de votre affiche partagée',
      );
    });

    test('pas chargée, en échec, cubit absent : null', () {
      expect(
        TripAudience.tileSubtitle(fr, const TripAudienceState.initial()),
        isNull,
      );
      expect(
        TripAudience.tileSubtitle(fr, const TripAudienceState.loading()),
        isNull,
      );
      expect(
        TripAudience.tileSubtitle(fr, const TripAudienceState.hidden()),
        isNull,
      );
      expect(TripAudience.tileSubtitle(fr, null), isNull);
    });
  });

  testWidgets('la ligne ne charge rien elle-même', (tester) async {
    await pumpTripCard(tester, line(const TripAudienceState.initial()));
    verifyNever(() => cubit.load(any()));
  });

  testWidgets('sans cubit : rien', (tester) async {
    await pumpTripCard(tester, const TripAudienceLine());
    expect(find.byKey(const Key('trip-audience-card')), findsNothing);
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
