import 'package:dony/features/ai_form_draft/data/ai_city_resolver.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/trip_ai_draft_resolver.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCityRepository extends Mock implements CityRepository {}

class _MockPriceGridRepository extends Mock implements PriceGridRepository {}

const _cities = {
  'Paris': [
    CityModel(
      name: 'Paris',
      countryCode: 'FR',
      countryName: 'France',
      lat: 48.85,
      lng: 2.35,
    ),
  ],
  'Abidjan': [
    CityModel(
      name: 'Abidjan',
      countryCode: 'CI',
      countryName: 'Côte d’Ivoire',
      lat: 5.36,
      lng: -4.01,
    ),
  ],
};

const _item = PriceGridItemModel(
  id: 'g1',
  label: 'Téléphone',
  unitPriceNet: 15,
  unitPriceDisplay: 17,
  position: 0,
);

void main() {
  late _MockCityRepository cities;
  late _MockPriceGridRepository grid;
  var cardReady = true;

  setUp(() {
    cities = _MockCityRepository();
    grid = _MockPriceGridRepository();
    cardReady = true;
    when(() => cities.searchCities(any())).thenAnswer(
      (inv) async => _cities[inv.positionalArguments.first as String] ?? [],
    );
    when(() => grid.getItems()).thenAnswer((_) async => const [_item]);
  });

  TripAiDraftResolver resolver({String? fallbackCurrency = 'EUR'}) =>
      TripAiDraftResolver(
        cities: AiCityResolver(cities),
        priceGrid: grid,
        isCardReady: () => cardReady,
        fallbackCurrency: fallbackCurrency,
      );

  test('villes du catalogue, codes pays posés, aucun avertissement', () async {
    final resolved = await resolver().resolve(const {
      'departureCity': 'Paris',
      'arrivalCity': 'Abidjan',
      'transportMode': 'PLANE',
      'pricingMode': 'KG',
    });
    expect(resolved.draft['departureCountryCode'], 'FR');
    expect(resolved.draft['arrivalCountryCode'], 'CI');
    expect(resolved.warnings, isEmpty);
  });

  test('ville inconnue : champ vidé, avertissement', () async {
    final resolved = await resolver().resolve(const {
      'departureCity': 'Atlantis',
      'arrivalCity': 'Babylone',
    });
    expect(resolved.draft['departureCity'], isNull);
    expect(resolved.draft['arrivalCity'], isNull);
    expect(resolved.warnings, [
      AiDraftWarning.departureCityUnknown,
      AiDraftWarning.arrivalCityUnknown,
    ]);
  });

  test('un mode autre que l’avion devient PLANE, avec avertissement', () async {
    final resolved = await resolver().resolve(const {'transportMode': 'CAR'});
    expect(resolved.draft['transportMode'], 'PLANE');
    expect(resolved.warnings, [AiDraftWarning.planeOnly]);
  });

  test('grille demandée mais vide : prix au kilo, avertissement', () async {
    when(() => grid.getItems()).thenAnswer((_) async => const []);
    final resolved = await resolver().resolve(const {'pricingMode': 'MIXED'});
    expect(resolved.draft['pricingMode'], 'KG');
    expect(resolved.warnings, [AiDraftWarning.noPriceGrid]);
  });

  test('grille remplie, ou illisible (hors ligne) : MIXED gardé', () async {
    expect(
      (await resolver().resolve(const {
        'pricingMode': 'MIXED',
      })).draft['pricingMode'],
      'MIXED',
    );
    when(() => grid.getItems()).thenThrow(Exception('réseau'));
    final offline = await resolver().resolve(const {'pricingMode': 'MIXED'});
    expect(offline.draft['pricingMode'], 'MIXED');
    expect(offline.warnings, isEmpty);
  });

  test('carte demandée, paiements par carte non configurés', () async {
    cardReady = false;
    final resolved = await resolver().resolve(const {'cardEnabled': true});
    expect(resolved.draft['cardEnabled'], isTrue);
    expect(resolved.warnings, [AiDraftWarning.cardNotConfigured]);
  });

  test('carte demandée en franc CFA : devise sans carte', () async {
    final resolved = await resolver().resolve(const {
      'cardEnabled': true,
      'currency': 'XOF',
    });
    expect(resolved.warnings, [AiDraftWarning.cardUnavailableInCurrency]);
  });

  test('mobile money hors zone CFA : décoché, avertissement', () async {
    final resolved = await resolver().resolve(const {
      'mobileMoneyEnabled': true,
    });
    expect(resolved.draft['mobileMoneyEnabled'], isFalse);
    expect(resolved.warnings, [AiDraftWarning.mobileMoneyUnavailable]);
  });

  test(
    'mobile money en XOF (devise par défaut du formulaire) : gardé',
    () async {
      final resolved = await resolver(
        fallbackCurrency: 'XOF',
      ).resolve(const {'mobileMoneyEnabled': true});
      expect(resolved.draft['mobileMoneyEnabled'], isTrue);
      expect(resolved.warnings, isEmpty);
    },
  );
}
