import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/currency_switch_confirm_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_currencies_confirm_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_leg_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_legs_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../../../helpers/mock_recent_city_store.dart';
import 'trip_fixtures.dart';

class _MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

const _bamako = CityModel(
  name: 'Bamako',
  countryCode: 'ML',
  countryName: 'Mali',
  lat: 12.64,
  lng: -8.0,
);

/// Voyage du ticket : Marano di Napoli → Bouaké, puis Bouaké → Bamako.
final _bouake = TripLegOrigin(
  city: 'Bouaké',
  countryCode: 'CI',
  arrivalDay: DateTime.now().add(const Duration(days: 10)),
  address: kAbidjan,
);

TripLegsCubit _legsCubit() {
  final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
  analytics.onConfigured();
  return TripLegsCubit(analytics);
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: AppL10n.fr,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Écran réduit à [width] dp, texte agrandi et « Texte en gras » activés
/// (réglages du Redmi de FLUTTER-HN).
void _phone(WidgetTester t, double width, {double textScale = 1.3}) {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  t.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(boldText: true);
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
}

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
        initialState: const CitySearchLoaded([_bamako]),
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
    SupportedCurrency tripCurrency = SupportedCurrency.eur,
    bool showPrice = true,
    bool showStops = false,
  }) => _app(
    Scaffold(
      body: SingleChildScrollView(
        child: BlocProvider.value(
          value: cubit,
          child: TripLegsSection(
            origin: origin ?? _bouake,
            showPrice: showPrice,
            tripCurrency: tripCurrency,
            defaultKg: 15,
            defaultPrice: 7,
            showStops: showStops,
            defaultStops: TripStops.one,
          ),
        ),
      ),
    ),
  );

  group('TripLegCurrency', () {
    test('devise par défaut : celle du pays de départ', () {
      const eur = SupportedCurrency.eur;
      expect(TripLegCurrency.defaultFor('CI', fallback: eur).code, 'XOF');
      expect(TripLegCurrency.defaultFor('ML', fallback: eur).code, 'XOF');
      expect(TripLegCurrency.defaultFor('CM', fallback: eur).code, 'XAF');
      expect(
        TripLegCurrency.defaultFor('FR', fallback: SupportedCurrency.xof).code,
        'EUR',
      );
      expect(TripLegCurrency.defaultFor('GB', fallback: eur).code, 'GBP');
      // Pays inconnu ou absent : la devise de repli.
      expect(TripLegCurrency.defaultFor('ZZ', fallback: eur).code, 'EUR');
      expect(
        TripLegCurrency.defaultFor(null, fallback: SupportedCurrency.xaf).code,
        'XAF',
      );
    });

    test('devise portée par l\'étape, celle du voyage à défaut', () {
      final leg = doualaLeg();
      expect(TripLegCurrency.of(leg, SupportedCurrency.eur).code, 'EUR');
      final xaf = TripLegDraft(
        arrivalCity: leg.arrivalCity,
        departureDate: leg.departureDate,
        departureTime: leg.departureTime,
        deliveryAddress: leg.deliveryAddress,
        availableKg: leg.availableKg,
        currency: 'XAF',
      );
      expect(TripLegCurrency.of(xaf, SupportedCurrency.eur).code, 'XAF');
    });

    test('withPaymentMethods garde l\'étape et pose ses moyens', () {
      final leg = doualaLeg(stops: TripStops.one);
      final copy = leg.withPaymentMethods(const ['CASH']);
      expect(copy.acceptedPaymentMethods, ['CASH']);
      expect(copy.arrivalCity, leg.arrivalCity);
      expect(copy.stops, TripStops.one);
      expect(copy.pricePerKg, leg.pricePerKg);
      expect(copy, isNot(leg));
    });

    test('moyens filtrés par devise, jamais vides', () {
      expect(
        TripLegCurrency.restrictPaymentMethods([
          'STRIPE',
          'CASH',
        ], SupportedCurrency.xof),
        ['CASH'],
      );
      expect(
        TripLegCurrency.restrictPaymentMethods([
          'STRIPE',
        ], SupportedCurrency.xof),
        ['CASH'],
      );
      expect(
        TripLegCurrency.restrictPaymentMethods([
          'CASH',
          'MOBILE_MONEY',
        ], SupportedCurrency.eur),
        ['CASH'],
      );
      expect(
        TripLegCurrency.restrictPaymentMethods([
          'STRIPE',
          'MOBILE_MONEY',
        ], SupportedCurrency.xaf),
        ['MOBILE_MONEY'],
      );
    });

    List<String> methods(
      SupportedCurrency leg, {
      SupportedCurrency first = SupportedCurrency.eur,
      bool stripe = true,
      bool card = true,
      bool cash = false,
      bool mobileMoney = false,
      bool accountActive = false,
      SupportedCurrency? accountCurrency,
    }) => TripLegCurrency.paymentMethodsFor(
      leg,
      firstCurrency: first,
      stripeConfigured: stripe,
      cardEnabled: card,
      cashEnabled: cash,
      mobileMoneyEnabled: mobileMoney,
      mobileMoneyAccountActive: accountActive,
      mobileMoneyAccountCurrency: accountCurrency,
    );

    test('étape en euros : carte gardée', () {
      expect(methods(SupportedCurrency.eur), ['STRIPE']);
      expect(methods(SupportedCurrency.eur, cash: true), ['STRIPE', 'CASH']);
      expect(methods(SupportedCurrency.eur, stripe: false), ['CASH']);
    });

    test('étape en F CFA après un trajet en euros : pas de carte', () {
      expect(methods(SupportedCurrency.xof), ['CASH']);
      // Bascule grisée sur le trajet en euros : le compte actif en XOF suffit.
      expect(
        methods(
          SupportedCurrency.xof,
          accountActive: true,
          accountCurrency: SupportedCurrency.xof,
        ),
        ['CASH', 'MOBILE_MONEY'],
      );
      // Compte dans l'autre franc CFA : pas de mobile money.
      expect(
        methods(
          SupportedCurrency.xaf,
          accountActive: true,
          accountCurrency: SupportedCurrency.xof,
        ),
        ['CASH'],
      );
    });

    test('trajet en F CFA : le choix du voyageur fait foi', () {
      expect(
        methods(
          SupportedCurrency.xof,
          first: SupportedCurrency.xof,
          accountActive: true,
          accountCurrency: SupportedCurrency.xof,
        ),
        ['CASH'],
      );
      expect(
        methods(
          SupportedCurrency.xof,
          first: SupportedCurrency.xof,
          mobileMoney: true,
        ),
        ['CASH', 'MOBILE_MONEY'],
      );
      // Étape en euros : jamais de mobile money.
      expect(
        methods(
          SupportedCurrency.eur,
          first: SupportedCurrency.xof,
          mobileMoney: true,
        ),
        ['STRIPE'],
      );
    });
  });

  group('buildTripPayloads (FLUTTER-HP)', () {
    TripLegDraft leg({
      String city = 'Bamako',
      String code = 'ML',
      double? price = 3000,
      String? currency = 'XOF',
      List<String>? methods,
    }) => TripLegDraft(
      arrivalCity: city,
      arrivalCountryCode: code,
      departureDate: DateTime(2026, 11, 14),
      departureTime: '09:30',
      deliveryAddress: kDouala,
      availableKg: 12,
      pricePerKg: price,
      currency: currency,
      acceptedPaymentMethods: methods,
    );

    test('chaque étape envoie sa devise et ses moyens de paiement', () {
      final payloads = buildTripPayloads(firstLeg(), [
        leg(methods: const ['CASH', 'MOBILE_MONEY']),
      ]);
      expect(payloads.map((p) => p.currency), ['EUR', 'XOF']);
      expect(payloads[1].pricePerKg, 3000);
      expect(payloads[1].acceptedPaymentMethods, ['CASH', 'MOBILE_MONEY']);
      expect(payloads[1].toJson()['currency'], 'XOF');
    });

    test('moyens non résolus : ceux du premier trajet, filtrés par devise', () {
      final first = firstLeg();
      final payloads = buildTripPayloads(first, [leg()]);
      // Premier trajet en espèces : gardées.
      expect(payloads[1].acceptedPaymentMethods, ['CASH']);
    });

    test('grille seule : pas de prix recopié dans une autre devise', () {
      final payloads = buildTripPayloads(firstLeg(pricingMode: 'MIXED'), [
        leg(price: null),
        leg(city: 'Lomé', code: 'TG', price: null, currency: 'EUR'),
      ]);
      // 8 €/kg ne deviennent pas 8 F CFA/kg.
      expect(payloads[1].pricePerKg, 0);
      expect(payloads[1].currency, 'XOF');
      // Même devise que le premier trajet : prix repris.
      expect(payloads[2].pricePerKg, 8);
    });
  });

  group('TripLegsSection (FLUTTER-HP)', () {
    testWidgets('étape au départ de Bouaké : F CFA par défaut', (t) async {
      final cubit = _legsCubit();
      await t.pumpWidget(section(cubit));
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();

      expect(find.text('Franc CFA Ouest (F CFA)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-leg-price-currency')),
          matching: find.text('F CFA/kg'),
        ),
        findsOneWidget,
      );
      // Les 7 €/kg du premier trajet ne sont pas repris en F CFA.
      final price = t.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('trip-leg-price')),
          matching: find.byType(TextField),
        ),
      );
      expect(price.controller!.text, isEmpty);
    });

    testWidgets('étape au départ de Douala : F CFA Centre (XAF)', (t) async {
      final cubit = _legsCubit();
      await t.pumpWidget(
        section(
          cubit,
          origin: TripLegOrigin(
            city: 'Douala',
            countryCode: 'CM',
            arrivalDay: _bouake.arrivalDay,
          ),
        ),
      );
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();
      expect(find.text('Franc CFA Centre (FCFA)'), findsOneWidget);
    });

    testWidgets('même devise que le premier trajet : prix prérempli', (
      t,
    ) async {
      final cubit = _legsCubit();
      await t.pumpWidget(
        section(
          cubit,
          origin: TripLegOrigin(
            city: 'Lyon',
            countryCode: 'FR',
            arrivalDay: _bouake.arrivalDay,
          ),
        ),
      );
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();
      expect(find.text('Euro (€)'), findsOneWidget);
      final price = t.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('trip-leg-price')),
          matching: find.byType(TextField),
        ),
      );
      expect(price.controller!.text, '7');
    });

    testWidgets('changer de devise : suffixe et bornes suivent', (t) async {
      final cubit = _legsCubit();
      await t.pumpWidget(section(cubit));
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('trip-leg-price')), '3000');
      await t.pump();
      expect(find.textContaining('Maximum'), findsNothing);

      // XOF → EUR : 3 000 €/kg dépassent le plafond de l'euro.
      await t.ensureVisible(find.byKey(const Key('trip-leg-currency')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-currency')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-currency-EUR')));
      await t.pumpAndSettle();
      expect(find.text('Euro (€)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-leg-price-currency')),
          matching: find.text('€/kg'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Maximum 500'), findsOneWidget);

      // EUR → XAF : 8 F CFA/kg sous le plancher.
      await t.enterText(find.byKey(const Key('trip-leg-price')), '8');
      await t.pump();
      expect(find.textContaining('Maximum'), findsNothing);
      await t.ensureVisible(find.byKey(const Key('trip-leg-currency')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-currency')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-currency-XAF')));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Prix trop bas : minimum 656'),
        findsOneWidget,
      );
      expect(
        t
            .widget<DonyButton>(find.byKey(const Key('trip-leg-submit')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('étape gardée avec sa devise, affichée dans la liste', (
      t,
    ) async {
      final cubit = _legsCubit();
      await t.pumpWidget(section(cubit));
      await t.tap(find.byKey(const Key('trip-legs-add')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('trip-leg-arrival-city')), 'Bam');
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Bamako').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-date')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trip-leg-time')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('trip-leg-price')), '2500');
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('trip-leg-submit')));
      await t.tap(find.byKey(const Key('trip-leg-submit')));
      await t.pumpAndSettle();

      final leg = cubit.state.legs.single;
      expect(leg.currency, 'XOF');
      expect(leg.pricePerKg, 2500);
      expect(find.textContaining('F CFA par kg'), findsOneWidget);
      expect(find.byKey(const Key('trip-legs-currency-note')), findsOneWidget);

      // Modifier l'étape la rouvre dans sa devise, pas celle du voyage.
      await t.tap(find.byKey(const Key('trip-leg-edit-0')));
      await t.pumpAndSettle();
      expect(find.text('Franc CFA Ouest (F CFA)'), findsOneWidget);
    });

    testWidgets('grille seule : devise de l\'étape dans la liste', (t) async {
      final cubit = _legsCubit()
        ..add(
          TripLegDraft(
            arrivalCity: 'Bamako',
            arrivalCountryCode: 'ML',
            departureDate: _bouake.arrivalDay,
            departureTime: '09:30',
            deliveryAddress: kDouala,
            availableKg: 12,
            currency: 'XOF',
          ),
        );
      await t.pumpWidget(section(cubit, showPrice: false));
      await t.pumpAndSettle();
      expect(find.textContaining('en F CFA'), findsOneWidget);
      expect(
        TripLegsSection.priceMissingIndexes(
          cubit.state.legs,
          SupportedCurrency.eur,
        ),
        {0},
      );
      expect(
        TripLegsSection.priceMissingIndexes(
          cubit.state.legs,
          SupportedCurrency.xof,
        ),
        isEmpty,
      );
    });

    test('bornes jugées dans la devise de chaque étape', () {
      final legs = [
        TripLegDraft(
          arrivalCity: 'Bamako',
          departureDate: DateTime(2026, 11, 14),
          departureTime: '09:30',
          deliveryAddress: kDouala,
          availableKg: 12,
          pricePerKg: 3000,
          currency: 'XOF',
        ),
        TripLegDraft(
          arrivalCity: 'Paris',
          departureDate: DateTime(2026, 11, 20),
          departureTime: '09:30',
          deliveryAddress: kParis,
          availableKg: 12,
          pricePerKg: 3000,
          currency: 'EUR',
        ),
      ];
      expect(
        TripLegsSection.priceAboveMaxIndexes(legs, SupportedCurrency.xof),
        {1},
      );
      expect(
        TripLegsSection.priceBelowMinIndexes(legs, SupportedCurrency.eur),
        isEmpty,
      );
    });
  });

  group('TripLegSheet : mise en page (FLUTTER-HN)', () {
    final filled = TripLegDraft(
      arrivalCity: 'Bamako',
      arrivalCountryCode: 'ML',
      departureDate: _bouake.arrivalDay,
      departureTime: '09:30',
      deliveryAddress: const AddressData(
        label: 'Gare routière de Sogoniko, Bamako, Mali',
        lat: 12.6,
        lng: -8.0,
        city: 'Bamako',
      ),
      availableKg: 23,
      pricePerKg: 2500,
      stops: TripStops.twoOrMore,
      currency: 'XOF',
    );

    Future<void> open(WidgetTester t, {TripLegDraft? initial}) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => TripLegSheet.show(
                  context,
                  legNumber: 2,
                  origin: _bouake,
                  initial: initial,
                  showPrice: true,
                  defaultCurrency: SupportedCurrency.xof,
                  showStops: true,
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
    }

    for (final width in [360.0, 320.0]) {
      testWidgets('$width dp, texte 1,3 en gras : aucun débordement', (
        t,
      ) async {
        _phone(t, width);
        await open(t, initial: filled);
        expect(t.takeException(), isNull);

        // Champs empilés sur toute la largeur, sans icône de préfixe.
        final kg = t.getRect(find.byKey(const Key('trip-leg-kg')));
        final price = t.getRect(find.byKey(const Key('trip-leg-price')));
        final currency = t.getRect(find.byKey(const Key('trip-leg-currency')));
        expect(kg.width, price.width);
        expect(currency.width, price.width);
        expect(price.top, greaterThan(kg.bottom));
        expect(
          find.descendant(
            of: find.byKey(const Key('trip-leg-price')),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
        // Libellés et unités sur une ligne : hauteur d'un champ simple.
        final date = t.getRect(find.byKey(const Key('trip-leg-date')));
        expect(kg.height, lessThanOrEqualTo(date.height + 1));
        expect(price.height, lessThanOrEqualTo(date.height + 1));
        // Escales : une seule bascule, sans retour à la ligne.
        expect(find.byKey(const Key('stops-segmented')), findsOneWidget);
        final segments = [
          for (final s in TripStops.values)
            t.getRect(find.byKey(Key('stops-${s.name}'))),
        ];
        expect(segments.map((r) => r.top).toSet(), hasLength(1));

        // Ouvrir le menu des devises ne déborde pas non plus.
        await t.ensureVisible(find.byKey(const Key('trip-leg-currency')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('trip-leg-currency')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('320 dp, nouvelle étape vide : aucun débordement', (t) async {
      _phone(t, 320);
      await open(t);
      expect(t.takeException(), isNull);
      expect(find.text('Prix par kilo'), findsNothing);
    });
  });

  group('Confirmations multi-devises (FLUTTER-HP)', () {
    const lines = [
      TripCurrencyLine(
        route: 'Marano di Napoli → Bouaké',
        currency: SupportedCurrency.eur,
      ),
      TripCurrencyLine(
        route: 'Bouaké → Bamako',
        currency: SupportedCurrency.xof,
      ),
    ];

    test('confirmation seulement si les devises diffèrent', () {
      expect(TripCurrenciesConfirmSheet.needed(lines), isTrue);
      expect(
        TripCurrenciesConfirmSheet.needed(const [
          TripCurrencyLine(route: 'a', currency: SupportedCurrency.xof),
          TripCurrencyLine(route: 'b', currency: SupportedCurrency.xof),
        ]),
        isFalse,
      );
    });

    Future<bool?> Function(String tap) publishSheet(WidgetTester t) =>
        (tap) async {
          bool? result;
          await t.pumpWidget(
            _app(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async =>
                        result = await TripCurrenciesConfirmSheet.show(
                          context,
                          lines: lines,
                        ),
                    child: const Text('publier'),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('publier'));
          await t.pumpAndSettle();
          expect(find.text('Publier en plusieurs devises ?'), findsOneWidget);
          expect(
            find.text('Étape 1 · Marano di Napoli → Bouaké'),
            findsOneWidget,
          );
          expect(find.text('Étape 2 · Bouaké → Bamako'), findsOneWidget);
          expect(find.text('€'), findsOneWidget);
          expect(find.text('F CFA'), findsOneWidget);
          await t.tap(find.byKey(Key(tap)));
          await t.pumpAndSettle();
          return result;
        };

    testWidgets('publier le voyage → true', (t) async {
      expect(await publishSheet(t)('trip-currencies-confirm'), isTrue);
    });

    testWidgets('revoir les étapes → false', (t) async {
      expect(await publishSheet(t)('trip-currencies-edit'), isFalse);
    });

    testWidgets('« Publier en XOF » : les étapes gardent leur devise', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => CurrencySwitchConfirmSheet.show(
                  context,
                  target: SupportedCurrency.xof,
                  legCurrencies: const [
                    SupportedCurrency.xof,
                    SupportedCurrency.xaf,
                    SupportedCurrency.xof,
                  ],
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Le premier trajet passe en F CFA et le paiement par carte n\'y sera '
          'plus proposé. Les étapes suivantes gardent leur devise (F CFA, '
          'FCFA).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('« Publier en EUR » avec étapes : carte gardée', (t) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => CurrencySwitchConfirmSheet.show(
                  context,
                  target: SupportedCurrency.eur,
                  legCurrencies: const [SupportedCurrency.xof],
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Le premier trajet passe en €. Les étapes suivantes gardent leur '
          'devise (F CFA).',
        ),
        findsOneWidget,
      );
    });
  });
}
