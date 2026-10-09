import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_leg_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_legs_section.dart';
import 'package:dony/features/matching/presentation/widgets/owner_action_grid.dart';
import 'package:dony/features/matching/presentation/widgets/trip_group_header.dart';
import 'package:dony/features/matching/presentation/widgets/trip_legs_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';
import '../../../helpers/mock_recent_city_store.dart';
import 'trip_fixtures.dart';

class _MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class _MockTripGroupCubit extends MockCubit<TripGroupState>
    implements TripGroupCubit {}

const _douala = CityModel(
  name: 'Douala',
  countryCode: 'CM',
  countryName: 'Cameroun',
  lat: 4.05,
  lng: 9.7,
);

TripLegsCubit _legsCubit() {
  final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
  analytics.onConfigured();
  return TripLegsCubit(analytics);
}

final _origin = TripLegOrigin(
  city: 'Abidjan',
  countryCode: 'CI',
  arrivalDay: DateTime.now().add(const Duration(days: 10)),
  address: kAbidjan,
);

void main() {
  setUpAll(registerCityFallbackValues);

  setUp(() {
    registerFakeRecentCityStore();
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    getIt.registerFactory<CitySearchBloc>(() {
      final b = _MockCitySearchBloc();
      whenListen(
        b,
        const Stream<CitySearchState>.empty(),
        initialState: const CitySearchLoaded([_douala]),
      );
      return b;
    });
  });

  tearDown(() {
    unregisterFakeRecentCityStore();
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
  });

  Widget section(
    TripLegsCubit cubit, {
    TripLegOrigin? origin,
    bool showStops = false,
    TripStops? defaultStops,
    SupportedCurrency currency = SupportedCurrency.eur,
    bool showPrice = true,
  }) => localizedApp(
    Scaffold(
      body: SingleChildScrollView(
        child: BlocProvider.value(
          value: cubit,
          child: TripLegsSection(
            origin: origin,
            showPrice: showPrice,
            tripCurrency: currency,
            defaultKg: 15,
            defaultPrice: 7,
            showStops: showStops,
            defaultStops: defaultStops,
          ),
        ),
      ),
    ),
  );

  group('TripLegsSection', () {
    testWidgets('sans premier trajet complet : ajout désactivé', (t) async {
      await t.pumpWidget(section(_legsCubit()));
      expect(find.byKey(const Key('trip-legs-need-first')), findsOneWidget);
      final button = t.widget<DonyButton>(
        find.byKey(const Key('trip-legs-add')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('ajoute une étape via la feuille', (t) async {
      final cubit = _legsCubit();
      await t.pumpWidget(section(cubit, origin: _origin));
      expect(find.text('Voyage à plusieurs étapes'), findsOneWidget);

      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();
      expect(find.text('Étape 2'), findsOneWidget);
      expect(find.text('Départ de Abidjan'), findsOneWidget);
      // Bouton désactivé tant que l'étape est incomplète.
      expect(
        t
            .widget<DonyButton>(find.byKey(const Key('trip-leg-submit')))
            .onPressed,
        isNull,
      );

      await t.enterText(find.byKey(const Key('trip-leg-arrival-city')), 'Dou');
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Douala').last);
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('trip-leg-date')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('trip-leg-time')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();

      // FLUTTER-HP : l'étape part d'Abidjan, donc en F CFA par défaut ; les
      // 7 €/kg du premier trajet ne sont pas recopiés en 7 F CFA/kg.
      expect(find.text('Franc CFA Ouest (F CFA)'), findsOneWidget);
      final submit = find.byKey(const Key('trip-leg-submit'));
      expect(t.widget<DonyButton>(submit).onPressed, isNull);
      await t.enterText(find.byKey(const Key('trip-leg-price')), '3000');
      await t.pump();
      expect(t.widget<DonyButton>(submit).onPressed, isNotNull);
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();

      expect(cubit.state.legs, hasLength(1));
      final leg = cubit.state.legs.single;
      expect(leg.arrivalCity, 'Douala');
      expect(leg.arrivalCountryCode, 'CM');
      expect(leg.availableKg, 15);
      expect(leg.pricePerKg, 3000);
      expect(leg.currency, 'XOF');
      expect(leg.departureTime, '10:00');
      expect(leg.deliveryAddress.city, 'Douala');
      expect(find.text('Abidjan → Douala'), findsOneWidget);
    });

    // FLUTTER-HN : bascule segmentée dans la feuille d'étape.
    TripStops? selectedStops(WidgetTester t) => t
        .widget<DonySegmentedControl<TripStops?>>(
          find.byKey(const Key('stops-segmented')),
        )
        .selected;

    Future<void> fillLeg(WidgetTester t) async {
      await t.enterText(find.byKey(const Key('trip-leg-arrival-city')), 'Dou');
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Douala').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-date')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-time')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      // Départ d'Abidjan : étape en F CFA, prix à saisir dans cette devise.
      await t.enterText(find.byKey(const Key('trip-leg-price')), '3000');
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('trip-leg-submit')));
    }

    // FLUTTER-GE : l'étape avait les escales de la première, sans choix.
    testWidgets('avion : escales de l\'étape préremplies puis modifiables', (
      t,
    ) async {
      final cubit = _legsCubit();
      await t.pumpWidget(
        section(
          cubit,
          origin: _origin,
          showStops: true,
          defaultStops: TripStops.one,
        ),
      );
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();

      expect(selectedStops(t), TripStops.one);
      await t.tap(find.byKey(const Key('stops-direct')));
      await t.pump();
      expect(selectedStops(t), TripStops.direct);

      await fillLeg(t);
      await t.tap(find.byKey(const Key('trip-leg-submit')));
      await t.pumpAndSettle();

      expect(cubit.state.legs.single.stops, TripStops.direct);
      expect(find.textContaining('· Direct'), findsOneWidget);
    });

    testWidgets('étape suivante : escales reprises de l\'étape précédente', (
      t,
    ) async {
      final cubit = _legsCubit()
        ..add(
          doualaLeg(
            date: _origin.arrivalDay.add(const Duration(days: 4)),
            stops: TripStops.twoOrMore,
          ),
        );
      await t.pumpWidget(
        section(
          cubit,
          origin: _origin,
          showStops: true,
          defaultStops: TripStops.direct,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();

      expect(find.text('Étape 3'), findsOneWidget);
      expect(selectedStops(t), TripStops.twoOrMore);
    });

    testWidgets('modifier une étape garde ses escales, même non renseignées', (
      t,
    ) async {
      final cubit = _legsCubit()
        ..add(doualaLeg(date: _origin.arrivalDay.add(const Duration(days: 4))));
      await t.pumpWidget(
        section(
          cubit,
          origin: _origin,
          showStops: true,
          defaultStops: TripStops.one,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();

      expect(selectedStops(t), isNull);
      await t.tap(find.byKey(const Key('stops-one')));
      await t.pump();
      await t.tap(find.byKey(const Key('trip-leg-submit')));
      await t.pumpAndSettle();
      expect(cubit.state.legs.single.stops, TripStops.one);
    });

    testWidgets('hors avion : pas d\'escales sur l\'étape', (t) async {
      final cubit = _legsCubit();
      await t.pumpWidget(
        section(cubit, origin: _origin, defaultStops: TripStops.one),
      );
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('stops-chips')), findsNothing);

      await fillLeg(t);
      await t.tap(find.byKey(const Key('trip-leg-submit')));
      await t.pumpAndSettle();
      expect(cubit.state.legs.single.stops, isNull);
    });

    testWidgets('modifie puis retire une étape', (t) async {
      final cubit = _legsCubit()
        ..add(doualaLeg(date: _origin.arrivalDay.add(const Duration(days: 4))));
      await t.pumpWidget(section(cubit, origin: _origin));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();
      expect(find.text('Enregistrer l\'étape'), findsOneWidget);
      await t.enterText(find.byKey(const Key('trip-leg-kg')), '30');
      await t.pump();
      await t.tap(find.byKey(const Key('trip-leg-submit')));
      await t.pumpAndSettle();
      expect(cubit.state.legs.single.availableKg, 30);

      await t.tap(find.byKey(const Key('trip-leg-remove-0')));
      await t.pumpAndSettle();
      expect(cubit.state.legs, isEmpty);
    });

    testWidgets('étape devenue trop tôt : signalée', (t) async {
      final cubit = _legsCubit()
        ..add(
          doualaLeg(date: _origin.arrivalDay.subtract(const Duration(days: 1))),
        );
      await t.pumpWidget(section(cubit, origin: _origin));
      await t.pumpAndSettle();
      expect(
        find.text(
          "Cette étape part avant l'arrivée de la précédente : modifiez sa date.",
        ),
        findsOneWidget,
      );
    });

    // FLUTTER-GK : une étape à 8 XOF/kg, saisie sans voir la devise.
    testWidgets('devise de l\'étape rappelée dans la feuille et la liste', (
      t,
    ) async {
      final cubit = _legsCubit()
        ..add(doualaLeg(date: _origin.arrivalDay.add(const Duration(days: 4))));
      await t.pumpWidget(
        section(cubit, origin: _origin, currency: SupportedCurrency.xof),
      );
      await t.pumpAndSettle();

      expect(find.textContaining('F CFA par kg'), findsOneWidget);
      expect(find.byKey(const Key('trip-legs-currency-note')), findsOneWidget);

      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-leg-price-currency')),
          matching: find.text('F CFA/kg'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('prix au-dessus du plafond de la devise : refusé', (t) async {
      final cubit = _legsCubit()
        ..add(doualaLeg(date: _origin.arrivalDay.add(const Duration(days: 4))));
      await t.pumpWidget(section(cubit, origin: _origin));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('trip-leg-price')), '501');
      await t.pump();
      expect(find.textContaining('Maximum 500'), findsOneWidget);
      expect(
        t
            .widget<DonyButton>(find.byKey(const Key('trip-leg-submit')))
            .onPressed,
        isNull,
      );

      await t.enterText(find.byKey(const Key('trip-leg-price')), '500');
      await t.pump();
      expect(find.textContaining('Maximum 500'), findsNothing);
      expect(
        t
            .widget<DonyButton>(find.byKey(const Key('trip-leg-submit')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('même prix admis en XOF (plafond de la devise)', (t) async {
      final cubit = _legsCubit()
        ..add(doualaLeg(date: _origin.arrivalDay.add(const Duration(days: 4))));
      await t.pumpWidget(
        section(cubit, origin: _origin, currency: SupportedCurrency.xof),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('trip-leg-price')), '3000');
      await t.pump();
      expect(find.textContaining('Maximum'), findsNothing);
      await t.tap(find.byKey(const Key('trip-leg-submit')));
      await t.pumpAndSettle();
      expect(cubit.state.legs.single.pricePerKg, 3000);
    });

    testWidgets('étape au-dessus du plafond après changement de devise', (
      t,
    ) async {
      final cubit = _legsCubit()
        ..add(
          doualaLeg(
            date: _origin.arrivalDay.add(const Duration(days: 4)),
            price: 3000,
          ),
        );
      await t.pumpWidget(section(cubit, origin: _origin));
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('trip-leg-price-above-max-0')),
        findsOneWidget,
      );
      expect(
        TripLegsSection.priceAboveMaxIndexes(
          cubit.state.legs,
          SupportedCurrency.eur,
        ),
        {0},
      );
      expect(
        TripLegsSection.priceAboveMaxIndexes(
          cubit.state.legs,
          SupportedCurrency.xof,
        ),
        isEmpty,
      );
    });

    // FLUTTER-GK : 8 F CFA/kg saisis en croyant taper des euros.
    testWidgets('prix sous le plancher XOF : refusé jusqu\'à 656', (t) async {
      final cubit = _legsCubit()
        ..add(
          doualaLeg(
            date: _origin.arrivalDay.add(const Duration(days: 4)),
            price: 3000,
          ),
        );
      await t.pumpWidget(
        section(cubit, origin: _origin, currency: SupportedCurrency.xof),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();

      DonyButton submit() =>
          t.widget<DonyButton>(find.byKey(const Key('trip-leg-submit')));

      for (final tooLow in ['8', '655']) {
        await t.enterText(find.byKey(const Key('trip-leg-price')), tooLow);
        await t.pump();
        expect(
          find.textContaining('Prix trop bas : minimum 656'),
          findsOneWidget,
        );
        expect(submit().onPressed, isNull);
      }

      await t.enterText(find.byKey(const Key('trip-leg-price')), '656');
      await t.pump();
      expect(find.textContaining('Prix trop bas'), findsNothing);
      expect(submit().onPressed, isNotNull);
      await t.tap(find.byKey(const Key('trip-leg-submit')));
      await t.pumpAndSettle();
      expect(cubit.state.legs.single.pricePerKg, 656);
    });

    testWidgets('prix sous le plancher EUR : 0,99 refusé, 1 admis', (t) async {
      final cubit = _legsCubit()
        ..add(doualaLeg(date: _origin.arrivalDay.add(const Duration(days: 4))));
      await t.pumpWidget(section(cubit, origin: _origin));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('trip-leg-price')), '0,99');
      await t.pump();
      expect(find.textContaining('Prix trop bas : minimum'), findsOneWidget);
      expect(
        t
            .widget<DonyButton>(find.byKey(const Key('trip-leg-submit')))
            .onPressed,
        isNull,
      );

      await t.enterText(find.byKey(const Key('trip-leg-price')), '1');
      await t.pump();
      expect(find.textContaining('Prix trop bas'), findsNothing);
      expect(
        t
            .widget<DonyButton>(find.byKey(const Key('trip-leg-submit')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('étape sous le plancher après changement de devise', (t) async {
      // 8 €/kg valides deviennent 8 F CFA/kg si le voyage passe en XOF.
      final cubit = _legsCubit()
        ..add(
          doualaLeg(
            date: _origin.arrivalDay.add(const Duration(days: 4)),
            price: 8,
          ),
        );
      await t.pumpWidget(
        section(cubit, origin: _origin, currency: SupportedCurrency.xof),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('trip-leg-price-below-min-0')),
        findsOneWidget,
      );
      expect(
        TripLegsSection.priceBelowMinIndexes(
          cubit.state.legs,
          SupportedCurrency.xof,
        ),
        {0},
      );
      expect(
        TripLegsSection.priceBelowMinIndexes(
          cubit.state.legs,
          SupportedCurrency.eur,
        ),
        isEmpty,
      );
    });

    testWidgets('plafond atteint : plus de bouton d\'ajout', (t) async {
      final cubit = _legsCubit();
      for (var i = 0; i < 4; i++) {
        cubit.add(doualaLeg(date: _origin.arrivalDay));
      }
      await t.pumpWidget(section(cubit, origin: _origin));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('trip-legs-max')), findsOneWidget);
      expect(find.byKey(const Key('trip-legs-add')), findsNothing);
    });
  });

  group('TripLegSheet', () {
    testWidgets('ville identique au départ refusée', (t) async {
      await t.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => TripLegSheet.show(
                  context,
                  legNumber: 2,
                  origin: TripLegOrigin(
                    city: 'Douala',
                    arrivalDay: DateTime.now(),
                  ),
                  showPrice: false,
                  defaultCurrency: SupportedCurrency.eur,
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('trip-leg-price')), findsNothing);
      await t.enterText(find.byKey(const Key('trip-leg-arrival-city')), 'Dou');
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Douala').last);
      await t.pumpAndSettle();
      expect(
        find.text('Choisissez une autre ville que celle du départ.'),
        findsOneWidget,
      );
    });
  });

  group('TripLegsCard', () {
    final info = TripLegsInfo.fromJson(const {
      'tripGroupId': 'g',
      'legCount': 2,
      'legs': [
        {
          'id': 'a',
          'legIndex': 1,
          'departureCity': 'Paris',
          'arrivalCity': 'Abidjan',
          'departureDate': '2026-11-10',
        },
        {
          'id': 'b',
          'legIndex': 2,
          'departureCity': 'Abidjan',
          'arrivalCity': 'Douala',
          'departureDate': '2026-11-14',
        },
      ],
    });

    Widget card(TripGroupState state, ValueChanged<TripLegSummary> onOpen) {
      final cubit = _MockTripGroupCubit();
      whenListen(
        cubit,
        const Stream<TripGroupState>.empty(),
        initialState: state,
      );
      return localizedApp(
        Scaffold(
          body: BlocProvider<TripGroupCubit>.value(
            value: cubit,
            child: TripLegsCard(announcementId: 'b', onOpenLeg: onOpen),
          ),
        ),
      );
    }

    testWidgets('« Étape 2/2 du voyage » et ouverture des autres étapes', (
      t,
    ) async {
      TripLegSummary? opened;
      await t.pumpWidget(
        card(
          TripGroupState(status: TripGroupStatus.loaded, info: info),
          (l) => opened = l,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Étape 2/2 du voyage'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsOneWidget);
      await t.tap(find.byKey(const Key('trip-leg-open-a')));
      expect(opened?.id, 'a');
      // L'étape affichée n'est pas un lien.
      expect(find.byKey(const Key('trip-leg-open-b')), findsNothing);
    });

    testWidgets('trajet isolé ou échec : rien', (t) async {
      await t.pumpWidget(
        card(const TripGroupState(status: TripGroupStatus.hidden), (_) {}),
      );
      expect(find.byKey(const Key('trip-legs-card')), findsNothing);
    });

    testWidgets('sans cubit dans l\'arbre : rien', (t) async {
      await t.pumpWidget(
        localizedApp(
          Scaffold(
            body: TripLegsCard(announcementId: 'b', onOpenLeg: (_) {}),
          ),
        ),
      );
      expect(find.byKey(const Key('trip-legs-card')), findsNothing);
    });
  });

  group('TripGroupHeader / TripLegBadge', () {
    testWidgets('affiche l\'itinéraire et le rang', (t) async {
      await t.pumpWidget(
        localizedApp(
          const Scaffold(
            body: Column(
              children: [
                TripGroupHeader(route: 'Paris → Abidjan → Douala'),
                TripLegBadge(index: 1, count: 2),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Voyage · Paris → Abidjan → Douala'), findsOneWidget);
      expect(find.text('Étape 1/2'), findsOneWidget);
    });
  });

  group('askCancelFollowingLegs', () {
    final info = TripLegsInfo.fromJson(const {
      'tripGroupId': 'g',
      'legCount': 3,
      'legs': [
        {'id': 'a', 'legIndex': 1, 'departureDate': '2026-11-10'},
        {'id': 'b', 'legIndex': 2, 'departureDate': '2026-11-14'},
        {
          'id': 'c',
          'legIndex': 3,
          'departureDate': '2026-11-20',
          'status': 'CANCELLED',
        },
      ],
    });

    Future<List<String>?> ask(
      WidgetTester t, {
      TripGroupState? state,
      String? tapLabel,
    }) async {
      List<String>? result = ['non-appelé'];
      Widget body = Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await askCancelFollowingLegs(context, 'a'),
          child: const Text('annuler'),
        ),
      );
      if (state != null) {
        final cubit = _MockTripGroupCubit();
        whenListen(
          cubit,
          const Stream<TripGroupState>.empty(),
          initialState: state,
        );
        body = BlocProvider<TripGroupCubit>.value(value: cubit, child: body);
      }
      await t.pumpWidget(localizedApp(Scaffold(body: body)));
      await t.tap(find.text('annuler'));
      await t.pumpAndSettle();
      if (tapLabel != null) {
        expect(
          find.text('Annuler aussi les étapes suivantes ?'),
          findsOneWidget,
        );
        await t.tap(find.text(tapLabel));
        await t.pumpAndSettle();
      }
      return result;
    }

    testWidgets('propose les suivantes ouvertes et les rend', (t) async {
      final r = await ask(
        t,
        state: TripGroupState(status: TripGroupStatus.loaded, info: info),
        tapLabel: 'Annuler les suivantes',
      );
      expect(r, ['b']);
    });

    testWidgets('« Les garder » : aucune en plus', (t) async {
      final r = await ask(
        t,
        state: TripGroupState(status: TripGroupStatus.loaded, info: info),
        tapLabel: 'Les garder',
      );
      expect(r, isEmpty);
    });

    testWidgets('trajet isolé ou sans cubit : rien demandé', (t) async {
      expect(await ask(t), isEmpty);
      expect(
        await ask(
          t,
          state: const TripGroupState(status: TripGroupStatus.hidden),
        ),
        isEmpty,
      );
    });
  });
}
